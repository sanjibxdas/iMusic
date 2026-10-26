import AVFoundation
import Foundation
import UIKit

enum RepeatMode: Int {
    case off = 0
    case all = 1
    case one = 2
}

final class AudioPlayer: NSObject {
    static let shared = AudioPlayer()
    static let trackDidChange = Notification.Name("AudioPlayerTrackDidChange")
    static let playbackStateDidChange = Notification.Name("AudioPlayerPlaybackStateDidChange")
    static let playbackProgressDidChange = Notification.Name("AudioPlayerPlaybackProgressDidChange")
    static let queueDidChange = Notification.Name("AudioPlayerQueueDidChange")
    static let volumeDidChange = Notification.Name("AudioPlayerVolumeDidChange")
    static let playbackDidFail = Notification.Name("AudioPlayerPlaybackDidFail")

    private struct Entry {
        let id = UUID()
        let track: Track
    }

    private var entries: [Entry] = []
    private var originalEntries: [Entry] = []
    var queue: [Track] { return entries.map { $0.track } }
    private(set) var currentIndex = -1
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var playbackError: String?
    private(set) var repeatMode: RepeatMode = .off
    private(set) var isShuffled = false
    private var wantsPlayback = false
    var isPlaybackRequested: Bool { return wantsPlayback }
    private var resumeAfterInterruption = false
    private var generation = UUID()
    private var recordedGeneration: UUID?
    private var retriedGeneration: UUID?
    private let player = AVPlayer()
    private var itemObservation: NSKeyValueObservation?
    private var playbackObservation: NSKeyValueObservation?
    private var timeObserver: Any?
    private var currentArtworkImage: UIImage?

    var volume: Float {
        get { return player.volume }
        set {
            guard newValue.isFinite else { return }
            player.volume = max(0, min(1, newValue))
            SettingsManager.shared.softwareVolume = player.volume
            NotificationCenter.default.post(name: AudioPlayer.volumeDidChange, object: nil)
        }
    }

    var currentTrack: Track? {
        guard entries.indices.contains(currentIndex) else { return nil }
        return entries[currentIndex].track
    }

    var currentTime: TimeInterval {
        let seconds = CMTimeGetSeconds(player.currentTime())
        return seconds.isFinite && seconds >= 0 ? seconds : 0
    }

    /// Highlighted queue row, including while a stream is still resolving.
    var highlightedIndex: Int {
        return entries.indices.contains(currentIndex) ? currentIndex : -1
    }

    var duration: TimeInterval {
        let seconds = player.currentItem.map { CMTimeGetSeconds($0.duration) } ?? 0
        if seconds.isFinite && seconds > 0 { return seconds }
        let fallback = currentTrack?.duration ?? 0
        return fallback.isFinite && fallback > 0 ? fallback : 0
    }

    private override init() {
        super.init()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch {
            playbackError = error.localizedDescription
        }
        player.volume = SettingsManager.shared.softwareVolume
        player.automaticallyWaitsToMinimizeStalling = true
        player.actionAtItemEnd = .pause
        playbackObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.refreshPlaybackState() }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { _ in
            NotificationCenter.default.post(name: AudioPlayer.playbackProgressDidChange, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NowPlayingCenter.shared.setupRemoteCommands(player: self)
    }

    func play(_ tracks: [Track], startingAt index: Int = 0) {
        guard tracks.indices.contains(index) else { return }
        entries = tracks.map { Entry(track: $0) }
        originalEntries = entries
        currentIndex = index
        isShuffled = false
        notifyQueue()
        loadCurrentTrackAndPlay()
    }

    func playNext(_ track: Track) {
        let entry = Entry(track: track)
        let insertion = max(0, min(currentIndex + 1, entries.count))
        if entries.indices.contains(currentIndex), let originalIndex = originalEntries.firstIndex(where: { $0.id == entries[currentIndex].id }) {
            originalEntries.insert(entry, at: originalIndex + 1)
        } else {
            originalEntries.append(entry)
        }
        entries.insert(entry, at: insertion)
        notifyQueue()
    }

    func addToQueue(_ track: Track) {
        let entry = Entry(track: track)
        entries.append(entry)
        originalEntries.append(entry)
        notifyQueue()
    }

    func removeTrack(at index: Int) {
        guard entries.indices.contains(index) else { return }
        let removingCurrent = index == currentIndex
        let removed = entries.remove(at: index)
        originalEntries.removeAll { $0.id == removed.id }
        if entries.isEmpty {
            currentIndex = -1
            resetPlayback()
            notifyQueue()
            NotificationCenter.default.post(name: AudioPlayer.trackDidChange, object: nil)
            return
        }
        if index < currentIndex { currentIndex -= 1 }
        if removingCurrent { currentIndex = min(index, entries.count - 1) }
        notifyQueue()
        if removingCurrent { loadCurrentTrackAndPlay() }
    }

    func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard entries.indices.contains(sourceIndex), entries.indices.contains(destinationIndex) else { return }
        let currentID = entries.indices.contains(currentIndex) ? entries[currentIndex].id : nil
        let entry = entries.remove(at: sourceIndex)
        entries.insert(entry, at: destinationIndex)
        currentIndex = currentID.flatMap { id in entries.firstIndex { $0.id == id } } ?? -1
        if !isShuffled { originalEntries = entries }
        notifyQueue()
    }

    func togglePlayPause() {
        if wantsPlayback { pause() } else { resume() }
    }

    func pause() {
        wantsPlayback = false
        resumeAfterInterruption = false
        player.pause()
        refreshPlaybackState()
    }

    func resume() {
        guard currentTrack != nil else { return }
        wantsPlayback = true
        if playbackError != nil || (player.currentItem == nil && !isLoading) {
            loadCurrentTrackAndPlay()
            return
        }
        if let item = player.currentItem, item.status == .readyToPlay {
            activateAndPlay()
        } else {
            refreshPlaybackState()
        }
    }

    func next() {
        guard !entries.isEmpty else { return }
        if currentIndex + 1 < entries.count {
            currentIndex += 1
            loadCurrentTrackAndPlay()
        } else if repeatMode == .all {
            currentIndex = 0
            loadCurrentTrackAndPlay()
        } else {
            pause()
        }
    }

    func previous() {
        guard currentTrack != nil else { return }
        if currentTime > 3 { seek(to: 0); return }
        if currentIndex > 0 {
            currentIndex -= 1
            loadCurrentTrackAndPlay()
        } else {
            seek(to: 0)
        }
    }

    func seek(to time: TimeInterval) {
        guard time.isFinite, player.currentItem != nil else { return }
        let token = generation
        let target = max(0, duration > 0 ? min(time, duration) : time)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, self.generation == token else { return }
                self.updateNowPlaying()
                NotificationCenter.default.post(name: AudioPlayer.playbackProgressDidChange, object: nil)
            }
        }
    }

    func toggleShuffle() {
        guard entries.indices.contains(currentIndex) else { return }
        let current = entries[currentIndex]
        isShuffled.toggle()
        if isShuffled {
            originalEntries = entries
            var remaining = entries
            remaining.remove(at: currentIndex)
            remaining.shuffle()
            entries = [current] + remaining
        } else {
            entries = originalEntries
        }
        currentIndex = entries.firstIndex { $0.id == current.id } ?? -1
        notifyQueue()
        NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    func cycleRepeatMode() {
        repeatMode = RepeatMode(rawValue: (repeatMode.rawValue + 1) % 3) ?? .off
        NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    /// Resolves the stream for an upcoming queue entry so playback can start immediately.
    func prewarm(at index: Int) {
        guard entries.indices.contains(index) else { return }
        StreamResolver.shared.resolveStreamURL(for: entries[index].track) { _ in }
    }

    private func resetPlayback() {
        generation = UUID()
        itemObservation = nil
        retriedGeneration = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
        wantsPlayback = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        isLoading = false
        isPlaying = false
        playbackError = nil
        currentArtworkImage = nil
        refreshPlaybackState()
    }

    private func loadCurrentTrackAndPlay() {
        guard let track = currentTrack else { return }
        resetPlayback()
        let token = generation
        wantsPlayback = true
        isLoading = true
        updateNowPlaying()
        NotificationCenter.default.post(name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
        if !track.artworkUrl.isEmpty {
            ImageLoader.shared.loadImage(from: track.artworkUrl) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self, self.generation == token else { return }
                    self.currentArtworkImage = image
                    self.updateNowPlaying()
                }
            }
        }
        StreamResolver.shared.resolveStreamURL(for: track) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.generation == token else { return }
                switch result {
                case .success(let url): self.installItem(url: url, token: token)
                case .failure(let error): self.fail(error.localizedDescription)
                }
            }
        }
    }

    private func installItem(url: URL, token: UUID) {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 2
        player.replaceCurrentItem(with: item)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: item)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidFail(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: item)
        itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observedItem, _ in
            DispatchQueue.main.async {
                guard let self = self, self.generation == token, self.player.currentItem === observedItem else { return }
                switch observedItem.status {
                case .readyToPlay:
                    self.isLoading = false
                    if self.wantsPlayback { self.activateAndPlay() }
                    self.refreshPlaybackState()
                case .failed:
                    if self.retryAfterItemFailure(token: token, message: observedItem.error?.localizedDescription) {
                        return
                    }
                    self.fail(observedItem.error?.localizedDescription ?? "This audio stream could not be played. Please retry.")
                case .unknown: break
                @unknown default: break
                }
            }
        }
    }

    private func activateAndPlay() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player.play()
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func refreshPlaybackState() {
        isPlaying = wantsPlayback && player.timeControlStatus == .playing
        if player.currentItem?.status == .readyToPlay {
            isLoading = wantsPlayback && player.timeControlStatus == .waitingToPlayAtSpecifiedRate
        }
        if isPlaying, recordedGeneration != generation, let track = currentTrack {
            recordedGeneration = generation
            StorageManager.shared.recordHistory(track: track)
            let nextIndex = currentIndex + 1 < entries.count ? currentIndex + 1 : (repeatMode == .all ? 0 : -1)
            prewarm(at: nextIndex)
        }
        updateNowPlaying()
        NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    private func fail(_ message: String) {
        wantsPlayback = false
        player.pause()
        isLoading = false
        isPlaying = false
        playbackError = message
        updateNowPlaying()
        NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
        NotificationCenter.default.post(name: AudioPlayer.playbackDidFail, object: nil, userInfo: ["message": message])
    }

    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem, player.currentItem === item else { return }
        if repeatMode == .one { seek(to: 0); resume() } else { next() }
    }

    @objc private func playerItemDidFail(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem, player.currentItem === item else { return }
        let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
        if retryAfterItemFailure(token: generation, message: error?.localizedDescription) { return }
        fail(error?.localizedDescription ?? "Playback stopped because the audio stream failed.")
    }

    /// Retries a track once with a freshly resolved stream (stale/403 CDN URLs are common).
    private func retryAfterItemFailure(token: UUID, message: String?) -> Bool {
        guard generation == token, retriedGeneration != token, let track = currentTrack, wantsPlayback else { return false }
        retriedGeneration = token
        StreamResolver.shared.invalidate(trackId: track.id)
        let retryToken = UUID()
        generation = retryToken
        itemObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        isLoading = true
        playbackError = nil
        NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
        StreamResolver.shared.resolveStreamURL(for: track) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.generation == retryToken, self.wantsPlayback else { return }
                switch result {
                case .success(let url): self.installItem(url: url, token: retryToken)
                case .failure(let error): self.fail(error.localizedDescription)
                }
            }
        }
        return true
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: value) else { return }
            if type == .began {
                let shouldResume = self.wantsPlayback
                self.pause()
                self.resumeAfterInterruption = shouldResume
            } else {
                let value = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let shouldResume = self.resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: value).contains(.shouldResume)
                self.resumeAfterInterruption = false
                if shouldResume { self.resume() }
            }
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: value) == .oldDeviceUnavailable else { return }
        DispatchQueue.main.async { [weak self] in self?.pause() }
    }

    private func notifyQueue() {
        NotificationCenter.default.post(name: AudioPlayer.queueDidChange, object: nil)
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else { NowPlayingCenter.shared.clear(); return }
        NowPlayingCenter.shared.update(track: track, currentTime: currentTime, duration: duration, isPlaying: isPlaying, artworkImage: currentArtworkImage)
    }

    deinit {
        if let observer = timeObserver { player.removeTimeObserver(observer) }
        NotificationCenter.default.removeObserver(self)
    }
}
