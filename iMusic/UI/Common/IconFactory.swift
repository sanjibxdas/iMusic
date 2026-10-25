import UIKit

final class IconFactory {

    private static var iconCache: [String: UIImage] = [:]

    private static func cached(key: String, size: CGSize, drawing: (CGContext, CGRect) -> Void) -> UIImage {
        let cacheKey = "\(key)_\(size.width)x\(size.height)"
        if let existing = iconCache[cacheKey] {
            return existing
        }

        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return UIImage()
        }

        let rect = CGRect(origin: .zero, size: size)
        drawing(ctx, rect)

        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()

        let template = image.withRenderingMode(.alwaysTemplate)
        iconCache[cacheKey] = template
        return template
    }

    // MARK: - Transport Icons

    static func play(size: CGFloat = 24) -> UIImage {
        return cached(key: "play", size: CGSize(width: size, height: size)) { ctx, rect in
            let path = UIBezierPath()
            let inset: CGFloat = size * 0.15
            let left = inset * 1.3
            let right = size - inset
            let top = inset
            let bottom = size - inset
            let midY = size / 2.0

            path.move(to: CGPoint(x: left, y: top))
            path.addLine(to: CGPoint(x: right, y: midY))
            path.addLine(to: CGPoint(x: left, y: bottom))
            path.close()

            UIColor.white.setFill()
            path.fill()
        }
    }

    static func pause(size: CGFloat = 24) -> UIImage {
        return cached(key: "pause", size: CGSize(width: size, height: size)) { ctx, rect in
            let barWidth = size * 0.22
            let barHeight = size * 0.70
            let gap = size * 0.18
            let startX = (size - (barWidth * 2 + gap)) / 2.0
            let startY = (size - barHeight) / 2.0
            let radius = barWidth * 0.3

            let bar1 = UIBezierPath(roundedRect: CGRect(x: startX, y: startY, width: barWidth, height: barHeight), cornerRadius: radius)
            let bar2 = UIBezierPath(roundedRect: CGRect(x: startX + barWidth + gap, y: startY, width: barWidth, height: barHeight), cornerRadius: radius)

            UIColor.white.setFill()
            bar1.fill()
            bar2.fill()
        }
    }

    static func next(size: CGFloat = 24) -> UIImage {
        return cached(key: "next", size: CGSize(width: size, height: size)) { ctx, rect in
            let path = UIBezierPath()
            let w = size
            let h = size

            // First triangle
            path.move(to: CGPoint(x: w * 0.12, y: h * 0.2))
            path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.5))
            path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.8))
            path.close()

            // Second triangle
            path.move(to: CGPoint(x: w * 0.48, y: h * 0.2))
            path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.5))
            path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.8))
            path.close()

            // End bar
            let bar = UIBezierPath(roundedRect: CGRect(x: w * 0.84, y: h * 0.2, width: w * 0.08, height: h * 0.6), cornerRadius: 1)

            UIColor.white.setFill()
            path.fill()
            bar.fill()
        }
    }

    static func previous(size: CGFloat = 24) -> UIImage {
        let nextImg = next(size: size)
        guard let cgImg = nextImg.cgImage else { return nextImg }
        return UIImage(cgImage: cgImg, scale: nextImg.scale, orientation: .upMirrored).withRenderingMode(.alwaysTemplate)
    }

    // MARK: - Controls

    static func shuffle(size: CGFloat = 22) -> UIImage {
        return cached(key: "shuffle", size: CGSize(width: size, height: size)) { ctx, rect in
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.setLineWidth(size * 0.09)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let s = size
            // Top cross line
            ctx.move(to: CGPoint(x: s * 0.15, y: s * 0.3))
            ctx.addCurve(to: CGPoint(x: s * 0.75, y: s * 0.7),
                         control1: CGPoint(x: s * 0.45, y: s * 0.3),
                         control2: CGPoint(x: s * 0.55, y: s * 0.7))
            ctx.strokePath()

            // Arrow on top cross line
            let arrow1 = UIBezierPath()
            arrow1.move(to: CGPoint(x: s * 0.70, y: s * 0.6))
            arrow1.addLine(to: CGPoint(x: s * 0.85, y: s * 0.7))
            arrow1.addLine(to: CGPoint(x: s * 0.70, y: s * 0.8))
            arrow1.lineWidth = size * 0.09
            arrow1.lineCapStyle = .round
            arrow1.stroke()

            // Bottom cross line
            ctx.move(to: CGPoint(x: s * 0.15, y: s * 0.7))
            ctx.addCurve(to: CGPoint(x: s * 0.75, y: s * 0.3),
                         control1: CGPoint(x: s * 0.45, y: s * 0.7),
                         control2: CGPoint(x: s * 0.55, y: s * 0.3))
            ctx.strokePath()

            // Arrow on bottom cross line
            let arrow2 = UIBezierPath()
            arrow2.move(to: CGPoint(x: s * 0.70, y: s * 0.2))
            arrow2.addLine(to: CGPoint(x: s * 0.85, y: s * 0.3))
            arrow2.addLine(to: CGPoint(x: s * 0.70, y: s * 0.4))
            arrow2.lineWidth = size * 0.09
            arrow2.lineCapStyle = .round
            arrow2.stroke()
        }
    }

    static func repeatMode(size: CGFloat = 22) -> UIImage {
        return cached(key: "repeat", size: CGSize(width: size, height: size)) { ctx, rect in
            let strokeWidth = size * 0.09
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.setLineWidth(strokeWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let s = size
            // Loop rectangle
            let loopRect = CGRect(x: s * 0.2, y: s * 0.25, width: s * 0.6, height: s * 0.5)
            let path = UIBezierPath(roundedRect: loopRect, cornerRadius: s * 0.14)
            path.lineWidth = strokeWidth
            path.stroke()

            // Arrow top right
            let arrow = UIBezierPath()
            arrow.move(to: CGPoint(x: s * 0.68, y: s * 0.15))
            arrow.addLine(to: CGPoint(x: s * 0.82, y: s * 0.25))
            arrow.addLine(to: CGPoint(x: s * 0.68, y: s * 0.35))
            arrow.close()
            arrow.fill()
        }
    }

    static func heart(filled: Bool, size: CGFloat = 22) -> UIImage {
        let key = filled ? "heart_filled" : "heart_outline"
        return cached(key: key, size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            let path = UIBezierPath()
            path.move(to: CGPoint(x: s * 0.5, y: s * 0.82))

            // Left curve
            path.addCurve(to: CGPoint(x: s * 0.15, y: s * 0.42),
                          control1: CGPoint(x: s * 0.28, y: s * 0.68),
                          control2: CGPoint(x: s * 0.15, y: s * 0.55))
            path.addArc(withCenter: CGPoint(x: s * 0.32, y: s * 0.32),
                        radius: s * 0.18,
                        startAngle: .pi,
                        endAngle: 0,
                        clockwise: true)

            // Right curve
            path.addArc(withCenter: CGPoint(x: s * 0.68, y: s * 0.32),
                        radius: s * 0.18,
                        startAngle: .pi,
                        endAngle: 0,
                        clockwise: true)
            path.addCurve(to: CGPoint(x: s * 0.5, y: s * 0.82),
                          control1: CGPoint(x: s * 0.85, y: s * 0.55),
                          control2: CGPoint(x: s * 0.72, y: s * 0.68))
            path.close()

            if filled {
                UIColor.white.setFill()
                path.fill()
            } else {
                UIColor.white.setStroke()
                path.lineWidth = size * 0.08
                path.stroke()
            }
        }
    }

    // MARK: - Utilities

    static func lyrics(size: CGFloat = 22) -> UIImage {
        return cached(key: "lyrics", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(s * 0.08)
            ctx.setLineCap(.round)

            // Quote bubble with sound wave lines
            let bubble = UIBezierPath(roundedRect: CGRect(x: s * 0.12, y: s * 0.15, width: s * 0.76, height: s * 0.60), cornerRadius: s * 0.12)
            bubble.lineWidth = s * 0.08
            bubble.stroke()

            // 3 lines inside bubble
            let y1 = s * 0.33
            let y2 = s * 0.45
            let y3 = s * 0.57

            ctx.move(to: CGPoint(x: s * 0.28, y: y1))
            ctx.addLine(to: CGPoint(x: s * 0.72, y: y1))
            ctx.move(to: CGPoint(x: s * 0.28, y: y2))
            ctx.addLine(to: CGPoint(x: s * 0.62, y: y2))
            ctx.move(to: CGPoint(x: s * 0.28, y: y3))
            ctx.addLine(to: CGPoint(x: s * 0.50, y: y3))
            ctx.strokePath()
        }
    }

    static func queue(size: CGFloat = 22) -> UIImage {
        return cached(key: "queue", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(s * 0.085)
            ctx.setLineCap(.round)

            // 3 horizontal list bars
            for i in 0..<3 {
                let y = s * (0.28 + CGFloat(i) * 0.22)
                ctx.move(to: CGPoint(x: s * 0.18, y: y))
                ctx.addLine(to: CGPoint(x: s * 0.82, y: y))
            }
            ctx.strokePath()
        }
    }

    static func airplay(size: CGFloat = 22) -> UIImage {
        return cached(key: "airplay", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.setLineWidth(s * 0.08)
            ctx.setLineCap(.round)

            // Screen outline with bottom opening
            let screen = UIBezierPath()
            screen.move(to: CGPoint(x: s * 0.38, y: s * 0.72))
            screen.addLine(to: CGPoint(x: s * 0.15, y: s * 0.72))
            screen.addLine(to: CGPoint(x: s * 0.15, y: s * 0.22))
            screen.addLine(to: CGPoint(x: s * 0.85, y: s * 0.22))
            screen.addLine(to: CGPoint(x: s * 0.85, y: s * 0.72))
            screen.addLine(to: CGPoint(x: s * 0.62, y: s * 0.72))
            screen.lineWidth = s * 0.08
            screen.lineCapStyle = .round
            screen.lineJoinStyle = .round
            screen.stroke()

            // Triangle in the gap
            let triangle = UIBezierPath()
            triangle.move(to: CGPoint(x: s * 0.50, y: s * 0.48))
            triangle.addLine(to: CGPoint(x: s * 0.65, y: s * 0.75))
            triangle.addLine(to: CGPoint(x: s * 0.35, y: s * 0.75))
            triangle.close()
            triangle.fill()
        }
    }

    static func volumeMin(size: CGFloat = 18) -> UIImage {
        return cached(key: "vol_min", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            let speaker = UIBezierPath()
            speaker.move(to: CGPoint(x: s * 0.2, y: s * 0.38))
            speaker.addLine(to: CGPoint(x: s * 0.38, y: s * 0.38))
            speaker.addLine(to: CGPoint(x: s * 0.62, y: s * 0.18))
            speaker.addLine(to: CGPoint(x: s * 0.62, y: s * 0.82))
            speaker.addLine(to: CGPoint(x: s * 0.38, y: s * 0.62))
            speaker.addLine(to: CGPoint(x: s * 0.2, y: s * 0.62))
            speaker.close()

            UIColor.white.setFill()
            speaker.fill()
        }
    }

    static func volumeMax(size: CGFloat = 18) -> UIImage {
        return cached(key: "vol_max", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            let speaker = UIBezierPath()
            speaker.move(to: CGPoint(x: s * 0.15, y: s * 0.38))
            speaker.addLine(to: CGPoint(x: s * 0.32, y: s * 0.38))
            speaker.addLine(to: CGPoint(x: s * 0.54, y: s * 0.18))
            speaker.addLine(to: CGPoint(x: s * 0.54, y: s * 0.82))
            speaker.addLine(to: CGPoint(x: s * 0.32, y: s * 0.62))
            speaker.addLine(to: CGPoint(x: s * 0.15, y: s * 0.62))
            speaker.close()

            UIColor.white.setFill()
            speaker.fill()

            // Sound wave arc
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(s * 0.08)
            ctx.setLineCap(.round)
            ctx.addArc(center: CGPoint(x: s * 0.48, y: s * 0.5), radius: s * 0.26, startAngle: -0.65, endAngle: 0.65, clockwise: false)
            ctx.strokePath()
            ctx.addArc(center: CGPoint(x: s * 0.48, y: s * 0.5), radius: s * 0.40, startAngle: -0.75, endAngle: 0.75, clockwise: false)
            ctx.strokePath()
        }
    }

    static func chevronDown(size: CGFloat = 20) -> UIImage {
        return cached(key: "chevron_down", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            let path = UIBezierPath()
            path.move(to: CGPoint(x: s * 0.22, y: s * 0.38))
            path.addLine(to: CGPoint(x: s * 0.50, y: s * 0.66))
            path.addLine(to: CGPoint(x: s * 0.78, y: s * 0.38))
            path.lineWidth = s * 0.11
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.white.setStroke()
            path.stroke()
        }
    }

    static func more(size: CGFloat = 22) -> UIImage {
        return cached(key: "more_horiz", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            let r = s * 0.085
            UIColor.white.setFill()

            let c1 = UIBezierPath(arcCenter: CGPoint(x: s * 0.25, y: s * 0.5), radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            let c2 = UIBezierPath(arcCenter: CGPoint(x: s * 0.50, y: s * 0.5), radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            let c3 = UIBezierPath(arcCenter: CGPoint(x: s * 0.75, y: s * 0.5), radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: true)

            c1.fill()
            c2.fill()
            c3.fill()
        }
    }

    // MARK: - Tab Bar Icons

    static func tabLibrary(size: CGFloat = 25) -> UIImage {
        return cached(key: "tab_library", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(s * 0.075)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            // Multiple stacked folder / library cards
            let card1 = UIBezierPath(roundedRect: CGRect(x: s * 0.24, y: s * 0.14, width: s * 0.60, height: s * 0.52), cornerRadius: s * 0.06)
            let card2 = UIBezierPath(roundedRect: CGRect(x: s * 0.14, y: s * 0.28, width: s * 0.60, height: s * 0.56), cornerRadius: s * 0.06)

            card1.lineWidth = s * 0.075
            card2.lineWidth = s * 0.075
            card1.stroke()
            card2.stroke()
        }
    }

    static func tabForYou(size: CGFloat = 25) -> UIImage {
        return cached(key: "tab_foryou", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            // Heart shape for "For You"
            let heart = self.heart(filled: false, size: s)
            heart.draw(in: rect)
        }
    }

    static func tabBrowse(size: CGFloat = 25) -> UIImage {
        return cached(key: "tab_browse", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(s * 0.075)

            // 4 quadrant square grid (Browse)
            let step = s * 0.32
            let start = s * 0.18
            let boxSize = s * 0.24
            let r = s * 0.04

            let b1 = UIBezierPath(roundedRect: CGRect(x: start, y: start, width: boxSize, height: boxSize), cornerRadius: r)
            let b2 = UIBezierPath(roundedRect: CGRect(x: start + step, y: start, width: boxSize, height: boxSize), cornerRadius: r)
            let b3 = UIBezierPath(roundedRect: CGRect(x: start, y: start + step, width: boxSize, height: boxSize), cornerRadius: r)
            let b4 = UIBezierPath(roundedRect: CGRect(x: start + step, y: start + step, width: boxSize, height: boxSize), cornerRadius: r)

            b1.lineWidth = s * 0.075
            b2.lineWidth = s * 0.075
            b3.lineWidth = s * 0.075
            b4.lineWidth = s * 0.075

            b1.stroke()
            b2.stroke()
            b3.stroke()
            b4.stroke()
        }
    }

    static func tabRadio(size: CGFloat = 25) -> UIImage {
        return cached(key: "tab_radio", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.setLineWidth(s * 0.075)
            ctx.setLineCap(.round)

            // Center antenna dot
            let centerDot = UIBezierPath(arcCenter: CGPoint(x: s * 0.5, y: s * 0.65), radius: s * 0.07, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            centerDot.fill()

            // Radio waves emanating upward
            ctx.addArc(center: CGPoint(x: s * 0.5, y: s * 0.65), radius: s * 0.22, startAngle: -.pi * 0.85, endAngle: -.pi * 0.15, clockwise: false)
            ctx.strokePath()
            ctx.addArc(center: CGPoint(x: s * 0.5, y: s * 0.65), radius: s * 0.38, startAngle: -.pi * 0.85, endAngle: -.pi * 0.15, clockwise: false)
            ctx.strokePath()
        }
    }

    static func tabSearch(size: CGFloat = 25) -> UIImage {
        return cached(key: "tab_search", size: CGSize(width: size, height: size)) { ctx, rect in
            let s = size
            let stroke = s * 0.08
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(stroke)
            ctx.setLineCap(.round)

            let center = CGPoint(x: s * 0.42, y: s * 0.42)
            let radius = s * 0.24
            let circle = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            circle.lineWidth = stroke
            circle.stroke()

            // Handle
            ctx.move(to: CGPoint(x: center.x + radius * 0.707, y: center.y + radius * 0.707))
            ctx.addLine(to: CGPoint(x: s * 0.82, y: s * 0.82))
            ctx.strokePath()
        }
    }
}
