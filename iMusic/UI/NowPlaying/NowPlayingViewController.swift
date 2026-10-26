import MediaPlayer
import UIKit

enum NowPlayingCenterState {
    case artwork
    case lyrics
    case queue
}

final class NowPlayingViewController: UIViewController {

    // Scroll container to prevent any clipping on small screens
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Header
    private let dismissButton = UIButton(type: .custom)
    private let grabberView = UIView()

    // Center state container
    private let centerContainer = UIView()

    // Artwork view state
    private let shadowView = UIView()
    private let artworkView = UIImageView()

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
    private let downloadButton = UIButton(type: .custom)

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
        setupScrollView()
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
        updateDownloadState()
        updateVolumeUI()
    }

    // MARK: - Scroll Container

    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: - Header

    private func setupHeader() {
        grabberView.backgroundColor = UIColor(white: 0.4, alpha: 0.5)
        grabberView.layer.cornerRadius = 2.5
        grabberView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(grabberView)

        dismissButton.setImage(IconFactory.chevronDown(size: 20), for: .normal)
        dismissButton.tintColor = AppTheme.textSecondary
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
        contentView.addSubview(dismissButton)

        NSLayoutConstraint.activate([
            grabberView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            grabberView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 36),
            grabberView.heightAnchor.constraint(equalToConstant: 5),

            dismissButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            dismissButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dismissButton.widthAnchor.constraint(equalToConstant: 36),
            dismissButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    // MARK: - Center Container (Artwork, Lyrics, Queue)

    private func setupCenterContainer() {
        centerContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(centerContainer)

        // Artwork & Shadow
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.4
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 10)
        shadowView.layer.shadowRadius = 16
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        centerContainer.addSubview(shadowView)

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 10
        artworkView.backgroundColor = AppTheme.surfaceElevated
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        shadowView.addSubview(artworkView)

        // Compact Header for Lyrics/Queue mode
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

        compactTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        compactTitleLabel.textColor = AppTheme.textPrimary
        compactTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        compactHeader.addSubview(compactTitleLabel)

        compactArtistLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        compactArtistLabel.textColor = AppTheme.textSecondary
        compactArtistLabel.translatesAutoresizingMaskIntoConstraints = false
        compactHeader.addSubview(compactArtistLabel)

        // Child view controllers
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
            centerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            centerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            centerContainer.heightAnchor.constraint(equalToConstant: 250),

            // Artwork
            shadowView.centerXAnchor.constraint(equalTo: centerContainer.centerXAnchor),
            shadowView.centerYAnchor.constraint(equalTo: centerContainer.centerYAnchor),
            shadowView.widthAnchor.constraint(equalToConstant: 210),
            shadowView.heightAnchor.constraint(equalToConstant: 210),

            artworkView.topAnchor.constraint(equalTo: shadowView.topAnchor),
            artworkView.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),
            artworkView.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            artworkView.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),

            // Compact Header
            compactHeader.topAnchor.constraint(equalTo: centerContainer.topAnchor),
            compactHeader.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor),
            compactHeader.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor),
            compactHeader.heightAnchor.constraint(equalToConstant: 38),

            compactArtworkView.leadingAnchor.constraint(equalTo: compactHeader.leadingAnchor),
            compactArtworkView.centerYAnchor.constraint(equalTo: compactHeader.centerYAnchor),
            compactArtworkView.widthAnchor.constraint(equalToConstant: 34),
            compactArtworkView.heightAnchor.constraint(equalToConstant: 34),

            compactTitleLabel.topAnchor.constraint(equalTo: compactArtworkView.topAnchor),
            compactTitleLabel.leadingAnchor.constraint(equalTo: compactArtworkView.trailingAnchor, constant: 10),
            compactTitleLabel.trailingAnchor.constraint(equalTo: compactHeader.trailingAnchor),

            compactArtistLabel.bottomAnchor.constraint(equalTo: compactArtworkView.bottomAnchor),
            compactArtistLabel.leadingAnchor.constraint(equalTo: compactTitleLabel.leadingAnchor),
            compactArtistLabel.trailingAnchor.constraint(equalTo: compactHeader.trailingAnchor),

            // Lyrics child
            lyricsVC.view.topAnchor.constraint(equalTo: compactHeader.bottomAnchor, constant: 4),
            lyricsVC.view.bottomAnchor.constraint(equalTo: centerContainer.bottomAnchor),
            lyricsVC.view.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor),
            lyricsVC.view.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor),

            // Queue child
            queueVC.view.topAnchor.constraint(equalTo: compactHeader.bottomAnchor, constant: 4),
            queueVC.view.bottomAnchor.constraint(equalTo: centerContainer.bottomAnchor),
            queueVC.view.leadingAnchor.constraint(equalTo: centerContainer.leadingAnchor),
            queueVC.view.trailingAnchor.constraint(equalTo: centerContainer.trailingAnchor)
        ])
    }

    // MARK: - Track Info

    private func setupTrackInfo() {
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        artistLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        artistLabel.textColor = AppTheme.accent
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artistLabel)

        favoriteButton.setImage(IconFactory.heart(filled: false, size: 22), for: .normal)
        favoriteButton.tintColor = AppTheme.textSecondary
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.addTarget(self, action: #selector(toggleFavoriteAction), for: .touchUpInside)
        contentView.addSubview(favoriteButton)

        downloadButton.setImage(IconFactory.download(size: 20), for: .normal)
        downloadButton.tintColor = AppTheme.textSecondary
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.addTarget(self, action: #selector(downloadAction), for: .touchUpInside)
        contentView.addSubview(downloadButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: centerContainer.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: downloadButton.leadingAnchor, constant: -8),
            titleLabel.heightAnchor.constraint(equalToConstant: 24),

            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            downloadButton.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -4),
            downloadButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor, constant: 6),
            downloadButton.widthAnchor.constraint(equalToConstant: 34),
            downloadButton.heightAnchor.constraint(equalToConstant: 34),

            favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            favoriteButton.centerYAnchor.constraint(equalTo: downloadButton.centerYAnchor),
            favoriteButton.widthAnchor.constraint(equalToConstant: 34),
            favoriteButton.heightAnchor.constraint(equalToConstant: 34)
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
        contentView.addSubview(scrubberSlider)

        elapsedLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        elapsedLabel.textColor = AppTheme.textTertiary
        elapsedLabel.text = "0:00"
        elapsedLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(elapsedLabel)

        remainingLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        remainingLabel.textColor = AppTheme.textTertiary
        remainingLabel.text = "-0:00"
        remainingLabel.textAlignment = .right
        remainingLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(remainingLabel)

        NSLayoutConstraint.activate([
            scrubberSlider.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 10),
            scrubberSlider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            scrubberSlider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            scrubberSlider.heightAnchor.constraint(equalToConstant: 20),

            elapsedLabel.topAnchor.constraint(equalTo: scrubberSlider.bottomAnchor, constant: 2),
            elapsedLabel.leadingAnchor.constraint(equalTo: scrubberSlider.leadingAnchor),

            remainingLabel.topAnchor.constraint(equalTo: scrubberSlider.bottomAnchor, constant: 2),
            remainingLabel.trailingAnchor.constraint(equalTo: scrubberSlider.trailingAnchor)
        ])
    }

    // MARK: - Transport

    private func setupTransport() {
        playPauseButton.setImage(IconFactory.play(size: 34), for: .normal)
        playPauseButton.tintColor = AppTheme.textPrimary
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(togglePlayPauseAction), for: .touchUpInside)
        contentView.addSubview(playPauseButton)

        nextButton.setImage(IconFactory.next(size: 24), for: .normal)
        nextButton.tintColor = AppTheme.textPrimary
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextAction), for: .touchUpInside)
        contentView.addSubview(nextButton)

        previousButton.setImage(IconFactory.previous(size: 24), for: .normal)
        previousButton.tintColor = AppTheme.textPrimary
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        previousButton.addTarget(self, action: #selector(previousAction), for: .touchUpInside)
        contentView.addSubview(previousButton)

        NSLayoutConstraint.activate([
            playPauseButton.topAnchor.constraint(equalTo: elapsedLabel.bottomAnchor, constant: 8),
            playPauseButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 58),
            playPauseButton.heightAnchor.constraint(equalToConstant: 58),

            previousButton.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -32),
            previousButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 40),
            previousButton.heightAnchor.constraint(equalToConstant: 40),

            nextButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 32),
            nextButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 40),
            nextButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    // MARK: - Volume Slider

    private func setupVolume() {
        volumeMinIcon.image = IconFactory.volumeMin(size: 13)
        volumeMinIcon.tintColor = AppTheme.textTertiary
        volumeMinIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(volumeMinIcon)

        volumeMaxIcon.image = IconFactory.volumeMax(size: 13)
        volumeMaxIcon.tintColor = AppTheme.textTertiary
        volumeMaxIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(volumeMaxIcon)

        volumeSlider.minimumTrackTintColor = AppTheme.textSecondary
        volumeSlider.maximumTrackTintColor = AppTheme.surfaceElevated
        volumeSlider.value = AudioPlayer.shared.volume
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.addTarget(self, action: #selector(volumeSliderChanged(_:)), for: .valueChanged)
        contentView.addSubview(volumeSlider)

        NSLayoutConstraint.activate([
            volumeSlider.topAnchor.constraint(equalTo: playPauseButton.bottomAnchor, constant: 10),
            volumeSlider.leadingAnchor.constraint(equalTo: volumeMinIcon.trailingAnchor, constant: 8),
            volumeSlider.trailingAnchor.constraint(equalTo: volumeMaxIcon.leadingAnchor, constant: -8),
            volumeSlider.heightAnchor.constraint(equalToConstant: 20),

            volumeMinIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            volumeMinIcon.centerYAnchor.constraint(equalTo: volumeSlider.centerYAnchor),
            volumeMinIcon.widthAnchor.constraint(equalToConstant: 14),
            volumeMinIcon.heightAnchor.constraint(equalToConstant: 14),

            volumeMaxIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            volumeMaxIcon.centerYAnchor.constraint(equalTo: volumeSlider.centerYAnchor),
            volumeMaxIcon.widthAnchor.constraint(equalToConstant: 14),
            volumeMaxIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    // MARK: - Bottom Utility Toolbar

    private func setupBottomToolbar() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        shuffleButton.setImage(IconFactory.shuffle(size: 19), for: .normal)
        shuffleButton.tintColor = AppTheme.textSecondary
        shuffleButton.addTarget(self, action: #selector(toggleShuffleAction), for: .touchUpInside)
        stack.addArrangedSubview(shuffleButton)

        lyricsButton.setImage(IconFactory.lyrics(size: 19), for: .normal)
        lyricsButton.tintColor = AppTheme.textSecondary
        lyricsButton.addTarget(self, action: #selector(toggleLyricsAction), for: .touchUpInside)
        stack.addArrangedSubview(lyricsButton)

        airPlayButton.showsVolumeSlider = false
        airPlayButton.tintColor = AppTheme.textSecondary
        airPlayButton.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(airPlayButton)

        repeatButton.setImage(IconFactory.repeatMode(size: 19), for: .normal)
        repeatButton.tintColor = AppTheme.textSecondary
        repeatButton.addTarget(self, action: #selector(cycleRepeatAction), for: .touchUpInside)
        stack.addArrangedSubview(repeatButton)

        queueButton.setImage(IconFactory.queue(size: 19), for: .normal)
        queueButton.tintColor = AppTheme.textSecondary
        queueButton.addTarget(self, action: #selector(toggleQueueAction), for: .touchUpInside)
        stack.addArrangedSubview(queueButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: volumeSlider.bottomAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -36),
            stack.heightAnchor.constraint(equalToConstant: 28),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            airPlayButton.widthAnchor.constraint(equalToConstant: 22),
            airPlayButton.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    // MARK: - Observers & State Updates

    private func registerObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateTrackInfo), name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updatePlaybackState), name: AudioPlayer.playbackStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgress), name: AudioPlayer.playbackProgressDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateFavoriteState), name: StorageManager.favoritesDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateVolumeUI), name: AudioPlayer.volumeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateDownloadState), name: DownloadManager.statusDidChangeNotification, object: nil)
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
        updateDownloadState()
        updateProgress()
    }

    @objc private func updatePlaybackState() {
        let isPlaying = AudioPlayer.shared.isPlaying
        let icon = isPlaying ? IconFactory.pause(size: 34) : IconFactory.play(size: 34)
        playPauseButton.setImage(icon, for: .normal)

        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut], animations: {
            if isPlaying {
                self.shadowView.transform = .identity
                self.shadowView.layer.shadowOpacity = 0.45
            } else {
                self.shadowView.transform = CGAffineTransform(scaleX: 0.84, y: 0.84)
                self.shadowView.layer.shadowOpacity = 0.20
            }
        }, completion: nil)

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

    @objc private func updateDownloadState() {
        guard let track = AudioPlayer.shared.currentTrack else { return }
        let status = DownloadManager.shared.status(for: track.id)
        switch status {
        case .downloaded:
            downloadButton.setImage(IconFactory.downloaded(size: 20), for: .normal)
            downloadButton.tintColor = AppTheme.accent
        case .downloading:
            downloadButton.setImage(IconFactory.download(size: 20), for: .normal)
            downloadButton.tintColor = AppTheme.accent
        case .notDownloaded, .failed:
            downloadButton.setImage(IconFactory.download(size: 20), for: .normal)
            downloadButton.tintColor = AppTheme.textSecondary
        }
    }

    @objc private func updateVolumeUI() {
        volumeSlider.value = AudioPlayer.shared.volume
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        guard sec > 0 && !sec.isNaN else { return "0:00" }
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Volume Slider Action

    @objc private func volumeSliderChanged(_ sender: UISlider) {
        AudioPlayer.shared.volume = sender.value
    }

    // MARK: - Center State Switching

    private func setCenterState(_ state: NowPlayingCenterState) {
        self.centerState = state

        UIView.animate(withDuration: 0.28, animations: {
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

    @objc private func downloadAction() {
        guard let track = AudioPlayer.shared.currentTrack else { return }
        if DownloadManager.shared.isDownloaded(trackId: track.id) {
            let alert = UIAlertController(title: "Downloaded", message: "This song is saved offline.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Remove Download", style: .destructive, handler: { _ in
                DownloadManager.shared.deleteDownload(trackId: track.id)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            DownloadManager.shared.download(track: track)
        }
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
