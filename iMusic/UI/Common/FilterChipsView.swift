import UIKit

final class FilterChipsView: UIView {

    var onSelect: ((SearchFilter) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var buttons: [UIButton] = []
    private var selectedFilter: SearchFilter = .all

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        for filter in SearchFilter.allCases {
            let button = UIButton(type: .custom)
            button.setTitle(filter.rawValue, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
            button.layer.cornerRadius = 14
            button.tag = SearchFilter.allCases.firstIndex(of: filter) ?? 0
            button.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)

            buttons.append(button)
            stackView.addArrangedSubview(button)
        }

        updateButtonStyles()
    }

    @objc private func chipTapped(_ sender: UIButton) {
        guard sender.tag < SearchFilter.allCases.count else { return }
        selectedFilter = SearchFilter.allCases[sender.tag]
        updateButtonStyles()
        onSelect?(selectedFilter)
    }

    private func updateButtonStyles() {
        for (idx, btn) in buttons.enumerated() {
            let filter = SearchFilter.allCases[idx]
            if filter == selectedFilter {
                btn.backgroundColor = AppTheme.accent
                btn.setTitleColor(.white, for: .normal)
            } else {
                btn.backgroundColor = AppTheme.surfaceElevated
                btn.setTitleColor(AppTheme.textSecondary, for: .normal)
            }
        }
    }
}
