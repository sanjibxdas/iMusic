import UIKit

final class SectionHeaderView: UIView {

    var onSeeAllTapped: (() -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let seeAllButton = UIButton(type: .system)

    init(title: String, subtitle: String? = nil, showSeeAll: Bool = false) {
        super.init(frame: .zero)
        setup(title: title, subtitle: subtitle, showSeeAll: showSeeAll)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(title: String, subtitle: String?, showSeeAll: Bool) {
        titleLabel.text = title
        titleLabel.font = AppTheme.sectionHeaderFont()
        titleLabel.textColor = AppTheme.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        seeAllButton.setTitle("See All", for: .normal)
        seeAllButton.setTitleColor(AppTheme.accent, for: .normal)
        seeAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        seeAllButton.translatesAutoresizingMaskIntoConstraints = false
        seeAllButton.isHidden = !showSeeAll
        seeAllButton.addTarget(self, action: #selector(seeAllAction), for: .touchUpInside)
        addSubview(seeAllButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            seeAllButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            seeAllButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])
    }

    @objc private func seeAllAction() {
        onSeeAllTapped?()
    }
}
