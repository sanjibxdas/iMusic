import UIKit

final class MarqueeLabel: UIView {

    private let primaryLabel = UILabel()
    private let trailingLabel = UILabel()
    private let scrollContainer = UIView()
    private var isScrolling = false

    private static let gap: CGFloat = 40
    private static let pointsPerSecond: CGFloat = 30

    var text: String? {
        didSet {
            guard text != oldValue else { return }
            primaryLabel.text = text
            trailingLabel.text = text
            accessibilityLabel = text
            invalidateIntrinsicContentSize()
            setNeedsLayout()
            restartIfNeeded()
        }
    }

    var font: UIFont {
        get { primaryLabel.font }
        set {
            primaryLabel.font = newValue
            trailingLabel.font = newValue
            invalidateIntrinsicContentSize()
            setNeedsLayout()
            restartIfNeeded()
        }
    }

    var textColor: UIColor {
        get { primaryLabel.textColor }
        set {
            primaryLabel.textColor = newValue
            trailingLabel.textColor = newValue
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .staticText

        scrollContainer.addSubview(primaryLabel)
        scrollContainer.addSubview(trailingLabel)
        addSubview(scrollContainer)

        NotificationCenter.default.addObserver(
            self, selector: #selector(restartIfNeeded),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        return primaryLabel.intrinsicContentSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let intrinsicWidth = primaryLabel.intrinsicContentSize.width
        let availableWidth = bounds.width

        if intrinsicWidth <= availableWidth {
            // Fits within view, no marquee scroll needed
            scrollContainer.frame = bounds
            primaryLabel.frame = bounds
            trailingLabel.isHidden = true
            stopScrolling()
        } else {
            // Overflows view, enable dual-label marquee scroll
            trailingLabel.isHidden = false
            primaryLabel.frame = CGRect(x: 0, y: 0, width: intrinsicWidth, height: bounds.height)
            trailingLabel.frame = CGRect(x: intrinsicWidth + Self.gap, y: 0, width: intrinsicWidth, height: bounds.height)
            scrollContainer.frame = CGRect(x: 0, y: 0, width: (intrinsicWidth * 2) + Self.gap, height: bounds.height)
            startScrollingIfNeeded(contentWidth: intrinsicWidth + Self.gap)
        }
    }

    private func startScrollingIfNeeded(contentWidth: CGFloat) {
        guard !isScrolling else { return }
        isScrolling = true

        let duration = Double(contentWidth / Self.pointsPerSecond)

        UIView.animate(withDuration: duration, delay: 1.5, options: [.curveLinear, .repeat], animations: {
            self.scrollContainer.transform = CGAffineTransform(translationX: -contentWidth, y: 0)
        }, completion: nil)
    }

    private func stopScrolling() {
        guard isScrolling else { return }
        isScrolling = false
        scrollContainer.layer.removeAllAnimations()
        scrollContainer.transform = .identity
    }

    @objc func restartIfNeeded() {
        stopScrolling()
        setNeedsLayout()
        layoutIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
