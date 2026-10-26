import UIKit

final class TrackCell: UITableViewCell {

    static let reuseIdentifier = "TrackCell"

    var onMoreTapped: (() -> Void)?

    private let artworkView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let durationLabel = UILabel()
    private let downloadedIcon = UIImageView()
    private let playingBars = NowPlayingBarsView(frame: CGRect(x: 0, y: 0, width: 14, height: 14))
    private let moreButton = UIButton(type: .custom)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 6
        artworkView.backgroundColor = AppTheme.surfaceElevated
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artworkView)

        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        artistLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        artistLabel.textColor = AppTheme.textSecondary
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artistLabel)

        downloadedIcon.image = IconFactory.downloaded(size: 11)
        downloadedIcon.tintColor = AppTheme.textTertiary
        downloadedIcon.isHidden = true
        downloadedIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(downloadedIcon)

        durationLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        durationLabel.textColor = AppTheme.textTertiary
        durationLabel.textAlignment = .right
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(durationLabel)

        playingBars.translatesAutoresizingMaskIntoConstraints = false
        playingBars.isHidden = true
        contentView.addSubview(playingBars)

        moreButton.setImage(IconFactory.more(size: 18), for: .normal)
        moreButton.tintColor = AppTheme.textTertiary
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
        contentView.addSubview(moreButton)

        NSLayoutConstraint.activate([
            artworkView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            artworkView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 48),
            artworkView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),

            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),
            artistLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            downloadedIcon.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 4),
            downloadedIcon.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            downloadedIcon.widthAnchor.constraint(equalToConstant: 12),
            downloadedIcon.heightAnchor.constraint(equalToConstant: 12),

            durationLabel.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -8),
            durationLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),

            playingBars.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -12),
            playingBars.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playingBars.widthAnchor.constraint(equalToConstant: 14),
            playingBars.heightAnchor.constraint(equalToConstant: 14),

            moreButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            moreButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            moreButton.widthAnchor.constraint(equalToConstant: 30),
            moreButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    func configure(with track: Track, isCurrentlyPlaying: Bool = false) {
        titleLabel.text = track.title
        artistLabel.text = track.artist.isEmpty ? "Unknown Artist" : track.artist
        durationLabel.text = track.formattedDuration
        downloadedIcon.isHidden = !DownloadManager.shared.isDownloaded(trackId: track.id)

        if isCurrentlyPlaying {
            titleLabel.textColor = AppTheme.accent
            durationLabel.isHidden = true
            playingBars.isHidden = false
            playingBars.setPlaying(AudioPlayer.shared.isPlaying)
        } else {
            titleLabel.textColor = AppTheme.textPrimary
            durationLabel.isHidden = false
            playingBars.isHidden = true
            playingBars.setPlaying(false)
        }

        artworkView.image = nil
        if !track.artworkUrl.isEmpty {
            ImageLoader.shared.loadImage(from: track.artworkUrl) { [weak self] image in
                self?.artworkView.image = image
            }
        }
    }

    @objc private func moreTapped() {
        onMoreTapped?()
    }
}
