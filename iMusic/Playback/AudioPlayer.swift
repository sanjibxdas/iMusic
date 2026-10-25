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

    // Notifications
    static let trackDidChange = Notification.Name("AudioPlayerTrackDidChange")
    static let playbackStateDidChange = Notification.Name("AudioPlayerPlaybackStateDidChange")
    static let playbackProgressDidChange = Notification.Name("AudioPlayerPlaybackProgressDidChange")
    static let queueDidChange = Notification.Name("AudioPlayerQueueDidChange")

    // State
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int = -1
    private(set) var isPlaying: Bool = false
    private(set) var repeatMode: RepeatMode = .off
    private(set) var isShuffled: Bool = false
    private var originalQueue: [Track] = []

    var currentTrack: Track? {
        guard currentIndex >= 0 && currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var currentTime: TimeInterval {
        guard let item = player?.currentItem else { return 0 }
        let sec = CMTimeGetSeconds(item.currentTime())
        return sec.isNaN ? 0 : sec
    }

    var duration: TimeInterval {
        guard let item = player?.currentItem else { return currentTrack?.duration ?? 0 }
        let sec = CMTimeGetSeconds(item.duration)
        if sec.isNaN || sec <= 0 {
            return currentTrack?.duration ?? 0
        }
        return sec
    }

    // Audio engine
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var currentArtworkImage: UIImage?

    override private init() {
        super.init()
        setupAudioSession()
        NowPlayingCenter.shared.setupRemoteCommands(player: self)
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }

    // MARK: - Queue & Playback Control

    func play(_ tracks: [Track], startingAt index: Int = 0) {
        guard !tracks.isEmpty, index >= 0 && index < tracks.count else { return }

        self.originalQueue = tracks
        self.queue = tracks
        self.currentIndex = index
        self.isShuffled = false

        NotificationCenter.default.post(name: AudioPlayer.queueDidChange, object: nil)
        loadCurrentTrackAndPlay()
    }

    func playNext(_ track: Track) {
        let insertIndex = currentIndex + 1
        if insertIndex <= queue.count {
            queue.insert(track, at: insertIndex)
        } else {
            queue.append(track)
        }
        NotificationCenter.default.post(name: AudioPlayer.queueDidChange, object: nil)
    }

    func addToQueue(_ track: Track) {
        queue.append(track)
        NotificationCenter.default.post(name: AudioPlayer.queueDidChange, object: nil)
    }

    func removeTrack(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        queue.remove(at: index)
        if index < currentIndex {
            currentIndex -= 1
        }
        NotificationCenter.default.post(name: AudioPlayer.queueDidChange, object: nil)
    }

    func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < queue.count,
              destinationIndex >= 0 && destinationIndex < queue.count else { return }
        let moved = queue.remove(at: sourceIndex)
        queue.insert(moved, at: destinationIndex)

        if sourceIndex == currentIndex {
            currentIndex = destinationIndex
        } else if sourceIndex < currentIndex && destinationIndex >= currentIndex {
            currentIndex -= 1
        } else if sourceIndex > currentIndex && destinationIndex <= currentIndex {
            currentIndex += 1
        }
        NotificationCenter.default.post(name: AudioPlayer.queueDidChange, object: nil)
    }

    // MARK: - Transport

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
        NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    func resume() {
        guard let p = player else {
            loadCurrentTrackAndPlay()
            return
        }
        p.play()
        isPlaying = true
        updateNowPlaying()
        NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    func next() {
        guard !queue.isEmpty else { return }

        if repeatMode == .one {
            seek(to: 0)
            resume()
            return
        }

        if currentIndex + 1 < queue.count {
            currentIndex += 1
            loadCurrentTrackAndPlay()
        } else if repeatMode == .all {
            currentIndex = 0
            loadCurrentTrackAndPlay()
        } else {
            pause()
            seek(to: 0)
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }

        // If song has played for more than 3 seconds, restart it
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }

        if currentIndex > 0 {
            currentIndex -= 1
            loadCurrentTrackAndPlay()
        } else {
            seek(to: 0)
        }
    }

    func seek(to time: TimeInterval) {
        guard let p = player else { return }
        let target = CMTime(seconds: time, preferredTimescale: 600)
        p.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.updateNowPlaying()
            NotificationCenter.default.post(name: AudioPlayer.playbackProgressDidChange, object: nil)
        }
    }

    func toggleShuffle() {
        guard !queue.isEmpty else { return }
        isShuffled.toggle()

        if isShuffled {
            guard let cur = currentTrack else { return }
            var remaining = queue
            remaining.remove(at: currentIndex)
            remaining.shuffle()
            queue = [cur] + remaining
            currentIndex = 0
        } else {
            guard let cur = currentTrack else { return }
            queue = originalQueue
            if let idx = queue.firstIndex(where: { $0.id == cur.id }) {
                currentIndex = idx
            }
        }
        NotificationCenter.default.post(name: AudioPlayer.queueDidChange, object: nil)
    }

    func cycleRepeatMode() {
        let nextRaw = (repeatMode.rawValue + 1) % 3
        repeatMode = RepeatMode(rawValue: nextRaw) ?? .off
        NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    // MARK: - Internal Stream Loading & Playback

    private func loadCurrentTrackAndPlay() {
        guard let track = currentTrack else { return }

        // Record in history & notify UI
        StorageManager.shared.recordHistory(track: track)
        NotificationCenter.default.post(name: AudioPlayer.trackDidChange, object: nil)

        // Load artwork for Lock Screen
        currentArtworkImage = nil
        if !track.artworkUrl.isEmpty {
            ImageLoader.shared.loadImage(from: track.artworkUrl) { [weak self] image in
                self?.currentArtworkImage = image
                self?.updateNowPlaying()
            }
        }

        // If stream URL is already known
        if let streamUrlStr = track.streamUrl, let streamUrl = URL(string: streamUrlStr) {
            startPlayback(url: streamUrl)
            return
        }

        // Resolve stream URL dynamically
        StreamResolver.shared.resolveStreamURL(for: track) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.currentTrack?.id == track.id else { return }
                switch result {
                case .success(let streamURL):
                    self.startPlayback(url: streamURL)
                case .failure(let error):
                    print("Stream resolve failed for \(track.title): \(error)")
                    self.isPlaying = false
                    NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
                }
            }
        }
    }

    private func startPlayback(url: URL) {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        // Register end-of-track notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        // Add periodic time observer (every 250ms)
        let interval = CMTime(value: 1, timescale: 4)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            self?.updateNowPlaying()
            NotificationCenter.default.post(name: AudioPlayer.playbackProgressDidChange, object: nil)
        }

        player?.play()
        isPlaying = true
        updateNowPlaying()
        NotificationCenter.default.post(name: AudioPlayer.playbackStateDidChange, object: nil)
    }

    @objc private func playerItemDidReachEnd() {
        next()
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else {
            NowPlayingCenter.shared.clear()
            return
        }
        NowPlayingCenter.shared.update(
            track: track,
            currentTime: currentTime,
            duration: duration,
            isPlaying: isPlaying,
            artworkImage: currentArtworkImage
        )
    }

    deinit {
        removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }
}
