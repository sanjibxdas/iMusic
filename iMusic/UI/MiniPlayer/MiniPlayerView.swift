import UIKit

final class MiniPlayerView: UIView {

    var onTap: (() -> Void)?

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let artworkView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let playPauseButton = UIButton(type: .custom)
    private let nextButton = UIButton(type: .custom)
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let separatorView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        registerObservers()
        updateState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        clipsToBounds = true
        backgroundColor = AppTheme.miniPlayerBackground

        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)

        separatorView.backgroundColor = AppTheme.separator
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorView)

        progressView.progressTintColor = AppTheme.accent
        progressView.trackTintColor = .clear
        progressView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressView)

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 4
        artworkView.backgroundColor = AppTheme.surfaceElevated
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(artworkView)

        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        artistLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        artistLabel.textColor = AppTheme.textSecondary
        artistLabel.lineBreakMode = .byTruncatingTail
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(artistLabel)

        playPauseButton.setImage(IconFactory.play(size: 20), for: .normal)
        playPauseButton.tintColor = AppTheme.textPrimary
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        addSubview(playPauseButton)

        nextButton.setImage(IconFactory.next(size: 18), for: .normal)
        nextButton.tintColor = AppTheme.textPrimary
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        addSubview(nextButton)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),

            separatorView.topAnchor.constraint(equalTo: topAnchor),
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5),

            progressView.topAnchor.constraint(equalTo: topAnchor),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 1.5),

            artworkView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            artworkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 38),
            artworkView.heightAnchor.constraint(equalToConstant: 38),

            titleLabel.topAnchor.constraint(equalTo: artworkView.topAnchor, constant: 1),
            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -12),

            artistLabel.bottomAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: -1),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            nextButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            nextButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 36),
            nextButton.heightAnchor.constraint(equalToConstant: 36),

            playPauseButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -8),
            playPauseButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 36),
            playPauseButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateState), name: AudioPlayer.trackDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateState), name: AudioPlayer.playbackStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateProgress), name: AudioPlayer.playbackProgressDidChange, object: nil)
    }

    @objc private func updateState() {
        let player = AudioPlayer.shared
        guard let track = player.currentTrack else {
            isHidden = true
            return
        }

        isHidden = false
        titleLabel.text = track.title
        artistLabel.text = track.artist.isEmpty ? "Unknown Artist" : track.artist

        let icon = player.isPlaying ? IconFactory.pause(size: 20) : IconFactory.play(size: 20)
        playPauseButton.setImage(icon, for: .normal)

        artworkView.image = nil
        if !track.artworkUrl.isEmpty {
            ImageLoader.shared.loadImage(from: track.artworkUrl) { [weak self] image in
                self?.artworkView.image = image
            }
        }

        updateProgress()
    }

    @objc private func updateProgress() {
        let player = AudioPlayer.shared
        guard player.duration > 0 else {
            progressView.progress = 0
            return
        }
        progressView.progress = Float(player.currentTime / player.duration)
    }

    @objc private func playPauseTapped() {
        AudioPlayer.shared.togglePlayPause()
    }

    @objc private func nextTapped() {
        AudioPlayer.shared.next()
    }

    @objc private func handleTap() {
        onTap?()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
