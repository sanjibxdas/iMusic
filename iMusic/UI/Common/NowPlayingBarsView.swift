import UIKit

final class NowPlayingBarsView: UIView {

    private let barLayers: [CALayer] = (0..<3).map { _ in CALayer() }
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        tintColor = AppTheme.accent
        for bar in barLayers {
            bar.cornerRadius = 1.0
            layer.addSublayer(bar)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartIfNeeded),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let barWidth: CGFloat = 2.5
        let spacing = (bounds.width - barWidth * 3) / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in barLayers.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing)
            bar.frame = CGRect(x: x, y: 0, width: barWidth, height: bounds.height)
            bar.anchorPoint = CGPoint(x: 0.5, y: 1)
            bar.position = CGPoint(x: x + barWidth / 2, y: bounds.height)
            bar.backgroundColor = tintColor.cgColor
        }
        CATransaction.commit()
    }

    func setPlaying(_ playing: Bool) {
        if playing {
            startAnimation()
        } else {
            stopAnimation()
        }
    }

    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        let durations: [Double] = [0.45, 0.35, 0.55]
        let heights: [CGFloat] = [0.3, 0.5, 0.2]

        for (i, bar) in barLayers.enumerated() {
            let anim = CABasicAnimation(keyPath: "transform.scale.y")
            anim.fromValue = heights[i]
            anim.toValue = 1.0
            anim.duration = durations[i]
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(anim, forKey: "bounce")
        }
    }

    private func stopAnimation() {
        guard isAnimating else { return }
        isAnimating = false
        for bar in barLayers {
            bar.removeAnimation(forKey: "bounce")
        }
    }

    @objc private func restartIfNeeded() {
        if isAnimating {
            stopAnimation()
            startAnimation()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
