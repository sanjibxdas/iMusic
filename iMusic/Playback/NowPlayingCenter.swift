import Foundation
import MediaPlayer
import UIKit

final class NowPlayingCenter {
    static let shared = NowPlayingCenter()
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var commandsInstalled = false
    private var artworkImage: UIImage?
    private var artwork: MPMediaItemArtwork?

    private init() {}

    func setupRemoteCommands(player: AudioPlayer) {
        guard !commandsInstalled else { return }
        commandsInstalled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak player] _ in
            DispatchQueue.main.async { player?.resume() }
            return .success
        }
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak player] _ in
            DispatchQueue.main.async { player?.pause() }
            return .success
        }
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak player] _ in
            DispatchQueue.main.async { player?.togglePlayPause() }
            return .success
        }
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak player] _ in
            DispatchQueue.main.async { player?.next() }
            return .success
        }
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak player] _ in
            DispatchQueue.main.async { player?.previous() }
            return .success
        }
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak player] event in
            guard let position = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime, position.isFinite else { return .commandFailed }
            DispatchQueue.main.async { player?.seek(to: position) }
            return .success
        }
    }

    func update(track: Track, currentTime: TimeInterval, duration: TimeInterval, isPlaying: Bool, artworkImage: UIImage? = nil) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime.isFinite ? max(0, currentTime) : 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if duration.isFinite && duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if self.artworkImage !== artworkImage {
            self.artworkImage = artworkImage
            artwork = artworkImage.map { image in MPMediaItemArtwork(boundsSize: image.size) { _ in image } }
        }
        if let artwork = artwork { info[MPMediaItemPropertyArtwork] = artwork }
        infoCenter.nowPlayingInfo = info
    }

    func clear() {
        infoCenter.nowPlayingInfo = nil
        artworkImage = nil
        artwork = nil
    }
}
