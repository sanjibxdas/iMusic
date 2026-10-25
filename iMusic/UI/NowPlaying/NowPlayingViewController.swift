import MediaPlayer
import UIKit

enum NowPlayingCenterState {
    case artwork
    case lyrics
    case queue
}

final class NowPlayingViewController: UIViewController {

    // Header
    private let dismissButton = UIButton(type: .custom)
    private let grabberView = UIView()

    // Center state container
    private let centerContainer = UIView()

    // Artwork view state
    private let artworkContainer = UIView()
    private let artworkView = UIImageView()
    private let shadowView = UIView()

    // Compact header (shown during lyrics & queue)
    private let compactHeader = UIView()
    private let compactArtworkView = UIImageView()
    private let compactTitleLabel = UILabel()
    private let compactArtistLabel = UILabel()

    // Embedded state controllers
    private let lyricsVC = LyricsViewController()
    private let queueVC = QueueViewController()
    private var centerState: NowPlayingCenterState = .artwork

    // Track info
    private let titleLabel = MarqueeLabel()
    private let artistLabel = UILabel()
    private let favoriteButton = UIButton(type: .custom)

    // Scrubber
    private let scrubberSlider = UISlider()
    private let elapsedLabel = UILabel()
    private let remainingLabel = UILabel()
    private var isScrubbing = false

    // Transport controls
    private let playPauseButton = UIButton(type: .custom)
    private let nextButton = UIButton(type: .custom)
    private let previousButton = UIButton(type: .custom)

    // Volume
    private let volumeSliderContainer = UIView()
    private let volumeMinIcon = UIImageView()
    private let volumeMaxIcon = UIImageView()
    private let volumeSlider = UISlider()

    // Bottom utility toolbar
    private let shuffleButton = UIButton(type: .custom)
    private let lyricsButton = UIButton(type: .custom)
    private let airPlayButton = MPVolumeView()
    private let repeatButton = UIButton(type: .custom)
    private let queueButton = UIButton(type: .custom)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        setupHeader()
        setupCenterContainer()
        setupTrackInfo()
        setupScrubber()
        setupTransport()
        setupVolume()
        setupBottomToolbar()
        registerObservers()
        updateTrackInfo()
        updatePlaybackState()
    }

    // MARK: - Header

    private func setupHeader() {
        grabberView.backgroundColor = UIColor(white: 0.4, alpha: 0.5)
        grabberView.layer.cornerRadius = 2.5
        grabberView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grabberView)

        dismissButton.setImage(IconFactory.chevronDown(size: 20), for: .normal)
        dismissButton.tintColor = AppTheme.textSecondary
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
        view.addSubview(dismissButton)

        NSLayoutConstraint.activate([
            grabberView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            grabberView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 36),
            grabberView.heightAnchor.constraint(equalToConstant: 5),

            dismissButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            dismissButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            dismissButton.widthAnchor.constraint(equalToConstant: 36),
            dismissButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    // MARK: - Center Container

    private func setupCenterContainer() {
        centerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(centerContainer)

        // Artwork
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.4
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 12)
        shadowView.layer.shadowRadius = 18
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        centerContainer.addSubview(shadowView)

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 12
        artworkView.backgroundColor = AppTheme.surfaceElevated
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        shadowView.addSubview(artworkView)

        // Compact header
        compactHeader.isHidden = true
        compactHeader.translatesAutoresizingMaskIntoConstraints = false
        let compactTap = UITapGestureRecognizer(target: self, action: #selector(toggleArtworkState))
        compactHeader.addGestureRecognizer(compactTap)
        centerContainer.addSubview(compactHeader)

        compactArtworkView.contentMode = .scaleAspectFill
        compactArtworkView.clipsToBounds = true
        compactArtworkView.layer.cornerRadius = 6
        compactArtworkView.backgroundColor = AppTheme.surfaceElevated
        compactArtworkView.translatesAutoresizingMaskIntoConstraints = false
        compactHeader.addSubview(compactArtworkView)

        compactTitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        compactTitleLabel.textColor = AppTheme.textPrimary
        compactTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        compactHeader.addSubview(compactTitleLabel)

        compactArtistLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        compactArtistLabel.textColor = AppTheme.textSecondary
        compactArtistLabel.translatesAutoresizingMaskIntoConstraints = false
        compactHeader.addSubview(compactArtistLabel)

        // Child view controllers (lyrics & queue)
        addChild(lyricsVC)
        lyricsVC.view.translatesAutoresizingMaskIntoConstraints = false
        lyricsVC.view.isHidden = true
        centerContainer.addSubview(lyricsVC.view)
        lyricsVC.didMove(toParent: self)

        addChild(queueVC)
        queueVC.view.translatesAutoresizingMaskIntoConstraints = false
        queueVC.view.isHidden = true
        centerContainer.addSubview(queueVC.view)
        queueVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
            centerContainer.topAnchor.constraint(equalTo: dismissButton.bottomAnchor, constant: 4),
            centerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            centerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // Large Artwork Shadow & View
            shadowView.topAnchor.constraint(equalTo: centerContainer.topAnchor, constant: 12),
            shadowView.centerXAnchor.constraint(equalTo: centerContainer.centerXAnchor),
            shadowView.widthAnchor.constraint(equalTo: centerContainer.widthAnchor, multiplier: 0.88),
            shadowView.heightAnchor.constraint(equalTo: shadowView.widthAnchor),

            artworkView.topAnchor.constraint(equalTo: shadowView.topAnchor),
            artworkView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),
            artworkView.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            artworkView.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),

            // Compact Header
            compactHeader.topAnchor.constraint(equalTo: centerContainer.topAnchor),
            compactHeader.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor),
            compactHeader.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor),
            compactHeader.heightAnchor.constraint(equalToConstant: 44),

            compactArtworkView.leadingAnchor.constraint(equalTo: compactHeader.leadingAnchor),
            compactArtworkView.centerYAnchor.constraint(equalTo: compactHeader.centerYAnchor),
            compactArtworkView.widthAnchor.constraint(equalToConstant: 40),
            compactArtworkView.heightAnchor.constraint(equalToConstant: 40),

            compactTitleLabel.topAnchor.constraint(equalTo: compactArtworkView.topAnchor, constant: 2),
            compactTitleLabel.leadingAnchor.constraint(equalTo: compactArtworkView.trailingAnchor, constant: 10),
            compactTitleLabel.trailingAnchor.constraint(equalTo: compactHeader.trailingAnchor),

            compactArtistLabel.bottomAnchor.constraint(equalTo: compactArtworkView.bottomAnchor, constant: -2),
            compactArtistLabel.leadingAnchor.constraint(equalTo: compactTitleLabel.leadingAnchor),
            compactArtistLabel.trailingAnchor.constraint(equalTo: compactHeader.trailingAnchor),

            // Lyrics child
            lyricsVC.view.topAnchor.constraint(equalTo: compactHeader.bottomAnchor, constant: 8),
            lyricsVC.view.bottomAnchor.constraint(equalTo: centerContainer.bottomAnchor),
            lyricsVC.view.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor),
            lyricsVC.view.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor),

            // Queue child
            queueVC.view.topAnchor.constraint(equalTo: compactHeader.bottomAnchor, constant: 8),
            queueVC.view.bottomAnchor.constraint(equalTo: centerContainer.bottomAnchor),
            queueVC.view.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor),
            queueVC.view.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor)
        ])
    }

    // MARK: - Track Info

    private func setupTrackInfo() {
        titleLabel.font = UIFont.systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        artistLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        artistLabel.textColor = AppTheme.accent
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(artistLabel)

        favoriteButton.setImage(IconFactory.heart(filled: false, size: 22), for: .normal)
        favoriteButton.tintColor = AppTheme.textSecondary
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.addTarget(self, action: #selector(toggleFavoriteAction), for: .touchUpInside)
        view.addSubview(favoriteButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: centerContainer.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -12),
            titleLabel.heightAnchor.constraint(equalToConstant: 28),

            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            favoriteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            favoriteButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor, constant: 8),
            favoriteButton.widthAnchor.constraint(equalToConstant: 36),
            favoriteButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    // MARK: - Scrubber

    private func setupScrubber() {
        scrubberSlider.minimumTrackTintColor = AppTheme.textPrimary
        scrubberSlider.maximumTrackTintColor = AppTheme.surfaceElevated
        scrubberSlider.setThumbImage(IconFactory.play(size: 8), for: .normal)
        scrubberSlider.translatesAutoresizingMaskIntoConstraints = false
        scrubberSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        scrubberSlider.addTarget(self, action: #selector(sliderTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside])
        view.addSubview(scrubberSlider)

        elapsedLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        elapsedLabel.textColor = AppTheme.textTertiary
        elapsedLabel.text = "0:00"
        elapsedLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(elapsedLabel)

        remainingLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        remainingLabel.textColor = AppTheme.textTertiary
        remainingLabel.text = "-0:00"
        remainingLabel.textAlignment = .right
        remainingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(remainingLabel)

        NSLayoutConstraint.activate([
            scrubberSlider.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 16),
            scrubberSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            scrubberSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            scrubberSlider.heightAnchor.constraint(equalToConstant: 24),

            elapsedLabel.topAnchor.constraint(equalTo: scrubberSlider.bottomAnchor, constant: 2),
            elapsedLabel.leadingAnchor.constraint(equalTo: scrubberSlider.leadingAnchor),

            remainingLabel.topAnchor.constraint(equalTo: scrubberSlider.bottomAnchor, constant: 2),
            remainingLabel.trailingAnchor.constraint(equalTo: scrubberSlider.trailingAnchor)
        ])
    }

    // MARK: - Transport

    private func setupTransport() {
        playPauseButton.setImage(IconFactory.play(size: 38), for: .normal)
        playPauseButton.tintColor = AppTheme.textPrimary
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(togglePlayPauseAction), for: .touchUpInside)
        view.addSubview(playPauseButton)

        nextButton.setImage(IconFactory.next(size: 26), for: .normal)
        nextButton.tintColor = AppTheme.textPrimary
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextAction), for: .touchUpInside)
        view.addSubview(nextButton)

        previousButton.setImage(IconFactory.previous(size: 26), for: .normal)
        previousButton.tintColor = AppTheme.textPrimary
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        previousButton.addTarget(self, action: #selector(previousAction), for: .touchUpInside)
        view.addSubview(previousButton)

        NSLayoutConstraint.activate([
            playPauseButton.topAnchor.constraint(equalTo: elapsedLabel.bottomAnchor, constant: 14),
            playPauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 68),
            playPauseButton.heightAnchor.constraint(equalToConstant: 68),

            previousButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -36),
            previousButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 44),
            previousButton.heightAnchor.constraint(equalToConstant: 44),

            nextButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 36),
            nextButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 44),
            nextButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Volume

    private func setupVolume() {
        volumeMinIcon.image = IconFactory.volumeMin(size: 14)
        volumeMinIcon.tintColor = AppTheme.textTertiary
        volumeMinIcon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(volumeMinIcon)

        volumeMaxIcon.image = IconFactory.volumeMax(size: 14)
        volumeMaxIcon.tintColor = AppTheme.textTertiary
        volumeMaxIcon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(volumeMaxIcon)

        volumeSlider.minimumTrackTintColor = AppTheme.textSecondary
        volumeSlider.maximumTrackTintColor = AppTheme.surfaceElevated
        volumeSlider.value = AVAudioSession.sharedInstance().outputVolume
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(volumeSlider)

        NSLayoutConstraint.activate([
            volumeSlider.topAnchor.constraint(equalTo: playPauseButton.bottomAnchor, constant: 16),
            volumeSlider.leadingAnchor.constraint(equalTo: volumeMinIcon.trailingAnchor, constant: 10),
            volumeSlider.trailingAnchor.constraint(equalTo: volumeMaxIcon.leadingAnchor, constant: -10),
            volumeSlider.heightAnchor.constraint(equalToConstant: 24),

            volumeMinIcon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            volumeMinIcon.centerYAnchor.constraint(equalTo: volumeSlider.centerYAnchor),
            volumeMinIcon.widthAnchor.constraint(equalToConstant: 16),
            volumeMinIcon.heightAnchor.constraint(equalToConstant: 16),

            volumeMaxIcon.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            volumeMaxIcon.centerYAnchor.constraint(equalTo: volumeSlider.centerYAnchor),
            volumeMaxIcon.widthAnchor.constraint(equalToConstant: 16),
            volumeMaxIcon.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    // MARK: - Bottom Utility Toolbar

    private func setupBottomToolbar() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        shuffleButton.setImage(IconFactory.shuffle(size: 20), for: .normal)
        shuffleButton.tintColor = AppTheme.textSecondary
        shuffleButton.addTarget(self, action: #selector(toggleShuffleAction), for: .touchUpInside)
        stack.addArrangedSubview(shuffleButton)

        lyricsButton.setImage(IconFactory.lyrics(size: 20), for: .normal)
        lyricsButton.tintColor = AppTheme.textSecondary
        lyricsButton.addTarget(self, action: #selector(toggleLyricsAction), for: .touchUpInside)
        stack.addArrangedSubview(lyricsButton)

        // AirPlay route picker button via MPVolumeView
        airPlayButton.showsVolumeSlider = false
        airPlayButton.tintColor = AppTheme.textSecondary
        airPlayButton.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(airPlayButton)

        repeatButton.setImage(IconFactory.repeatMode(size: 20), for: .normal)
        repeatButton.tintColor = AppTheme.textSecondary
        repeatButton.addTarget(self, action: #selector(cycleRepeatAction), for: .touchUpInside)
        stack.addArrangedSubview(repeatButton)

        queueButton.setImage(IconFactory.queue(size: 20), for: .normal)
        queueButton.tintColor = AppTheme.textSecondary
        queueButton.addTarget(self, action: #selector(toggleQueueAction), for: .touchUpInside)
        stack.addArrangedSubview(queueButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: volumeSlider.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),

            airPlayButton.widthAnchor.constraint(equalToConstant: 24),
            airPlayButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    // MARK: - Observers & State Updates

    private func registerObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateTrackInfo), name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updatePlaybackState), name: AudioPlayer.playbackStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgress), name: AudioPlayer.playbackProgressDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateFavoriteState), name: StorageManager.favoritesDidChange, object: nil)
    }

    @objc private func updateTrackInfo() {
        guard let track = AudioPlayer.shared.currentTrack else { return }

        titleLabel.text = track.title
        artistLabel.text = track.artist.isEmpty ? "Unknown Artist" : track.artist
        compactTitleLabel.text = track.title
        compactArtistLabel.text = track.artist

        artworkView.image = nil
        compactArtworkView.image = nil
        if !track.artworkUrl.isEmpty {
            ImageLoader.shared.loadImage(from: track.artworkUrl) { [weak self] image in
                self?.artworkView.image = image
                self?.compactArtworkView.image = image
            }
        }

        updateFavoriteState()
        updateProgress()
    }

    @objc private func updatePlaybackState() {
        let isPlaying = AudioPlayer.shared.isPlaying
        let icon = isPlaying ? IconFactory.pause(size: 38) : IconFactory.play(size: 38)
        playPauseButton.setImage(icon, for: .normal)

        // Artwork shrink/expand animation (iOS 12 Apple Music signature detail!)
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut], animations: {
            if isPlaying {
                self.shadowView.transform = .identity
                self.shadowView.layer.shadowOpacity = 0.45
            } else {
                self.shadowView.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
                self.shadowView.layer.shadowOpacity = 0.20
            }
        }, completion: nil)

        // Shuffle & Repeat tint states
        shuffleButton.tintColor = AudioPlayer.shared.isShuffled ? AppTheme.accent : AppTheme.textSecondary
        repeatButton.tintColor = (AudioPlayer.shared.repeatMode != .off) ? AppTheme.accent : AppTheme.textSecondary
    }

    @objc private func updateProgress() {
        guard !isScrubbing else { return }
        let player = AudioPlayer.shared
        let cur = player.currentTime
        let dur = player.duration

        if dur > 0 {
            scrubberSlider.value = Float(cur / dur)
            elapsedLabel.text = formatTime(cur)
            remainingLabel.text = "-\(formatTime(dur - cur))"
        } else {
            scrubberSlider.value = 0
            elapsedLabel.text = "0:00"
            remainingLabel.text = "-0:00"
        }
    }

    @objc private func updateFavoriteState() {
        guard let track = AudioPlayer.shared.currentTrack else { return }
        let isFav = StorageManager.shared.isFavorite(trackId: track.id)
        let icon = IconFactory.heart(filled: isFav, size: 22)
        favoriteButton.setImage(icon, for: .normal)
        favoriteButton.tintColor = isFav ? AppTheme.accent : AppTheme.textSecondary
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        guard sec > 0 && !sec.isNaN else { return "0:00" }
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Center State Switching

    private func setCenterState(_ state: NowPlayingCenterState) {
        self.centerState = state

        UIView.animate(withDuration: 0.3, animations: {
            switch state {
            case .artwork:
                self.shadowView.isHidden = false
                self.compactHeader.isHidden = true
                self.lyricsVC.view.isHidden = true
                self.queueVC.view.isHidden = true
                self.lyricsButton.tintColor = AppTheme.textSecondary
                self.queueButton.tintColor = AppTheme.textSecondary
            case .lyrics:
                self.shadowView.isHidden = true
                self.compactHeader.isHidden = false
                self.lyricsVC.view.isHidden = false
                self.queueVC.view.isHidden = true
                self.lyricsButton.tintColor = AppTheme.accent
                self.queueButton.tintColor = AppTheme.textSecondary
            case .queue:
                self.shadowView.isHidden = true
                self.compactHeader.isHidden = false
                self.lyricsVC.view.isHidden = true
                self.queueVC.view.isHidden = false
                self.lyricsButton.tintColor = AppTheme.textSecondary
                self.queueButton.tintColor = AppTheme.accent
            }
        })
    }

    @objc private func toggleArtworkState() {
        setCenterState(.artwork)
    }

    @objc private func toggleLyricsAction() {
        setCenterState(centerState == .lyrics ? .artwork : .lyrics)
    }

    @objc private func toggleQueueAction() {
        setCenterState(centerState == .queue ? .artwork : .queue)
    }

    // MARK: - Actions

    @objc private func dismissAction() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func togglePlayPauseAction() {
        AudioPlayer.shared.togglePlayPause()
    }

    @objc private func nextAction() {
        AudioPlayer.shared.next()
    }

    @objc private func previousAction() {
        AudioPlayer.shared.previous()
    }

    @objc private func toggleShuffleAction() {
        AudioPlayer.shared.toggleShuffle()
    }

    @objc private func cycleRepeatAction() {
        AudioPlayer.shared.cycleRepeatMode()
    }

    @objc private func toggleFavoriteAction() {
        guard let track = AudioPlayer.shared.currentTrack else { return }
        _ = StorageManager.shared.toggleFavorite(track: track)
    }

    @objc private func sliderValueChanged(_ sender: UISlider) {
        isScrubbing = true
        let dur = AudioPlayer.shared.duration
        let target = TimeInterval(sender.value) * dur
        elapsedLabel.text = formatTime(target)
        remainingLabel.text = "-\(formatTime(dur - target))"
    }

    @objc private func sliderTouchEnded(_ sender: UISlider) {
        let dur = AudioPlayer.shared.duration
        let target = TimeInterval(sender.value) * dur
        AudioPlayer.shared.seek(to: target)
        isScrubbing = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
