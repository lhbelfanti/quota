import SwiftUI
import AppKit

/// Authentic vector brand marks for Claude (Anthropic), Codex (OpenAI), and Gemini / Antigravity.
public struct ProviderBrandLogoView: View {
    public let provider: AIProviderKind
    public var size: CGFloat = 30
    public var showBadgeBackground: Bool = true

    public init(provider: AIProviderKind, size: CGFloat = 30, showBadgeBackground: Bool = true) {
        self.provider = provider
        self.size = size
        self.showBadgeBackground = showBadgeBackground
    }

    public var body: some View {
        ZStack {
            if showBadgeBackground {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(badgeGradient)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
                    )
            }

            logoMark
                .frame(width: size * (showBadgeBackground ? 0.62 : 0.90), height: size * (showBadgeBackground ? 0.62 : 0.90))
        }
        .frame(width: size, height: size)
    }

    private var badgeGradient: LinearGradient {
        switch provider {
        case .claude:
            return LinearGradient(
                colors: [
                    Color(red: 0.88, green: 0.49, blue: 0.35),
                    Color(red: 0.77, green: 0.37, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .codex:
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.68, blue: 0.52),
                    Color(red: 0.04, green: 0.48, blue: 0.37)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gemini:
            return LinearGradient(
                colors: [
                    Color(red: 0.29, green: 0.52, blue: 0.96),
                    Color(red: 0.56, green: 0.35, blue: 0.95),
                    Color(red: 0.85, green: 0.38, blue: 0.68)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var logoMark: some View {
        let fgColor: Color = showBadgeBackground ? .white : QuotaUITheme.providerColor(provider)
        switch provider {
        case .claude:
            ClaudeSunburstMark(color: fgColor)
        case .codex:
            OpenAIHexKnotMark(color: fgColor)
        case .gemini:
            GeminiStarMark(
                color: fgColor,
                useGradient: !showBadgeBackground
            )
        }
    }
}

/// Anthropic Claude 10-ray asymmetric sunburst/asterisk mark
private struct ClaudeSunburstMark: View {
    let color: Color

    private let rayAngles: [(angle: Double, lengthScale: CGFloat)] = [
        (-90, 1.0),
        (-52, 0.88),
        (-18, 0.98),
        (16, 0.86),
        (50, 0.96),
        (88, 1.0),
        (125, 0.88),
        (160, 0.96),
        (196, 0.85),
        (232, 0.94)
    ]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) * 0.47
            let innerRadius = maxRadius * 0.14
            let strokeWidth = max(1.6, min(size.width, size.height) * 0.125)

            for ray in rayAngles {
                let rad = ray.angle * .pi / 180.0
                let outer = maxRadius * ray.lengthScale
                var path = Path()
                path.move(
                    to: CGPoint(
                        x: center.x + CGFloat(cos(rad)) * innerRadius,
                        y: center.y + CGFloat(sin(rad)) * innerRadius
                    )
                )
                path.addLine(
                    to: CGPoint(
                        x: center.x + CGFloat(cos(rad)) * outer,
                        y: center.y + CGFloat(sin(rad)) * outer
                    )
                )
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
            }

            let hubRect = CGRect(
                x: center.x - innerRadius * 1.15,
                y: center.y - innerRadius * 1.15,
                width: innerRadius * 2.3,
                height: innerRadius * 2.3
            )
            context.fill(Path(ellipseIn: hubRect), with: .color(color))
        }
    }
}

/// OpenAI / Codex 6-petal interlocking hexagonal knot mark
private struct OpenAIHexKnotMark: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.22
            let petalRadius = min(size.width, size.height) * 0.23
            let strokeWidth = max(1.4, min(size.width, size.height) * 0.105)

            for i in 0..<6 {
                let angle = Double(i) * (.pi / 3.0) - (.pi / 6.0)
                let petalCenter = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radius,
                    y: center.y + CGFloat(sin(angle)) * radius
                )
                let rect = CGRect(
                    x: petalCenter.x - petalRadius,
                    y: petalCenter.y - petalRadius * 0.78,
                    width: petalRadius * 2,
                    height: petalRadius * 1.56
                )
                var petal = Path(roundedRect: rect, cornerRadius: petalRadius * 0.78)
                let transform = CGAffineTransform(translationX: petalCenter.x, y: petalCenter.y)
                    .rotated(by: CGFloat(angle + .pi / 3.0))
                    .translatedBy(x: -petalCenter.x, y: -petalCenter.y)
                petal = petal.applying(transform)

                context.stroke(
                    petal,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

/// Google Gemini / Antigravity curved 4-pointed star + orbit dot mark
private struct GeminiStarMark: View {
    let color: Color
    let useGradient: Bool

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w * 0.48
            let cy = h * 0.52
            let r = min(w, h) * 0.46

            var star = Path()
            let top = CGPoint(x: cx, y: cy - r)
            let right = CGPoint(x: cx + r, y: cy)
            let bottom = CGPoint(x: cx, y: cy + r)
            let left = CGPoint(x: cx - r, y: cy)
            let ctrl = CGPoint(x: cx, y: cy)

            star.move(to: top)
            star.addQuadCurve(to: right, control: ctrl)
            star.addQuadCurve(to: bottom, control: ctrl)
            star.addQuadCurve(to: left, control: ctrl)
            star.addQuadCurve(to: top, control: ctrl)
            star.closeSubpath()

            // Secondary mini sparkle in top-right (Antigravity accent)
            let sx = w * 0.80
            let sy = h * 0.22
            let sr = min(w, h) * 0.16
            var mini = Path()
            mini.move(to: CGPoint(x: sx, y: sy - sr))
            mini.addQuadCurve(to: CGPoint(x: sx + sr, y: sy), control: CGPoint(x: sx, y: sy))
            mini.addQuadCurve(to: CGPoint(x: sx, y: sy + sr), control: CGPoint(x: sx, y: sy))
            mini.addQuadCurve(to: CGPoint(x: sx - sr, y: sy), control: CGPoint(x: sx, y: sy))
            mini.addQuadCurve(to: CGPoint(x: sx, y: sy - sr), control: CGPoint(x: sx, y: sy))
            mini.closeSubpath()

            if useGradient {
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [
                        Color(red: 0.30, green: 0.54, blue: 0.98),
                        Color(red: 0.62, green: 0.38, blue: 0.96)
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: w, y: h)
                )
                context.fill(star, with: shading)
                context.fill(mini, with: shading)
            } else {
                context.fill(star, with: .color(color))
                context.fill(mini, with: .color(color.opacity(0.92)))
            }
        }
    }
}
