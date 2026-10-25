import UIKit

final class MediaCardCell: UICollectionViewCell {

    static let reuseIdentifier = "MediaCardCell"

    private let artworkView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let shadowContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        shadowContainer.layer.shadowColor = UIColor.black.cgColor
        shadowContainer.layer.shadowOpacity = 0.25
        shadowContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        shadowContainer.layer.shadowRadius = 8
        shadowContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(shadowContainer)

        artworkView.contentMode = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = AppTheme.cornerRadiusArtwork
        artworkView.backgroundColor = AppTheme.surfaceElevated
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.addSubview(artworkView)

        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        subtitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = AppTheme.textSecondary
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            shadowContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            shadowContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shadowContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            shadowContainer.heightAnchor.constraint(equalTo: shadowContainer.widthAnchor),

            artworkView.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            artworkView.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            artworkView.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            artworkView.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: shadowContainer.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])
    }

    func configure(title: String, subtitle: String, artworkUrl: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        artworkView.image = nil

        if let url = artworkUrl, !url.isEmpty {
            ImageLoader.shared.loadImage(from: url) { [weak self] image in
                self?.artworkView.image = image
            }
        }
    }
}
