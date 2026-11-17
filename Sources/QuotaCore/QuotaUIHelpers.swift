import SwiftUI

public struct QuotaSummaryPillSegment: View {
    public let tokens: ProviderSummaryTokens
    public var showPoolTag: Bool
    public var monochrome: Bool
    public var fontSize: CGFloat

    public init(tokens: ProviderSummaryTokens, showPoolTag: Bool = false, monochrome: Bool = false, fontSize: CGFloat = 10) {
        self.tokens = tokens
        self.showPoolTag = showPoolTag
        self.monochrome = monochrome
        self.fontSize = fontSize
    }

    public var body: some View {
        HStack(spacing: 4) {
            if showPoolTag {
                Text(tokens.tag ?? "G")
                    .font(.system(size: fontSize - 1, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let burst = tokens.burst5hText {
                value(burst, window: tokens.burst5hIsShared ? "5h↗" : "5h", remaining: tokens.burst5hRemaining)
                    .help(tokens.burst5hDetail ?? "5h")
            }
            if tokens.isDualWindow {
                Text("·")
                    .foregroundStyle(.secondary)
            }
            if let weekly = tokens.weekly7dText {
                value(weekly, window: "7d", remaining: tokens.weekly7dRemaining)
            }
        }
        .font(.system(size: fontSize, weight: .semibold, design: .rounded).monospacedDigit())
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func value(_ text: String, window: String, remaining: Double?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(text)
                .foregroundStyle(monochrome ? Color.primary : remaining.map { QuotaUITheme.statusColor(remainingPercent: $0) } ?? Color.secondary)
            Text(window)
                .font(.system(size: fontSize - 3, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

public enum QuotaUITheme {
    public static func providerColor(_ provider: AIProviderKind) -> Color {
        switch provider {
        case .claude:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex:
            return Color(red: 0.06, green: 0.64, blue: 0.50)
        case .gemini:
            return Color(red: 0.31, green: 0.51, blue: 0.93)
        }
    }

    public static func poolCategoryColor(_ category: QuotaPoolCategory) -> Color {
        switch category {
        case .core:
            return Color(red: 0.06, green: 0.64, blue: 0.50)
        case .dedicated:
            return Color(red: 0.66, green: 0.44, blue: 0.96)
        case .partner:
            return Color(red: 0.25, green: 0.72, blue: 0.88)
        }
    }

    public static func poolCategoryAccent(_ category: QuotaPoolCategory, baseColor: Color) -> Color {
        category == .core ? baseColor : poolCategoryColor(category)
    }

    public static func statusColor(remainingPercent: Double) -> Color {
        let fraction = min(max(remainingPercent, 0), 100) / 100
        return Color(hue: fraction / 3, saturation: 0.85, brightness: 0.8)
    }
}

/// Tarjeta visual de un Pool de Cuota: la cuota semanal (7d) es la principal y la ventana de 5h cuelga de ella como secundaria.
public struct QuotaPoolCardView: View {
    public let pool: QuotaPoolGroup
    public let providerColor: Color
    public let compact: Bool
    public let displayMode: QuotaDisplayMode
    public let language: AppLanguage

    public init(
        pool: QuotaPoolGroup,
        providerColor: Color,
        compact: Bool = false,
        displayMode: QuotaDisplayMode = .remaining,
        language: AppLanguage = .es
    ) {
        self.pool = pool
        self.providerColor = providerColor
        self.compact = compact
        self.displayMode = displayMode
        self.language = language
    }

    private var poolAccent: Color {
        QuotaUITheme.poolCategoryAccent(pool.category, baseColor: providerColor)
    }

    private func weeklyBadgeLabel(for weekly: QuotaMetric) -> String {
        switch pool.sharingArchitecture {
        case .shared5hAndScopedWeekly:
            return L10n.scopedWeeklyBadgeLabel(allowancePercent: Int(weekly.weeklyAllowancePercentOfGeneral ?? 50), language)
        case .independentWeeklyOnly:
            return L10n.independentWeeklyBadgeLabel(language)
        case .standardDual:
            return L10n.weeklyWindowBadge(language)
        }
    }

    public var body: some View {
        let localizedTitle = L10n.poolTitle(for: pool.id, category: pool.category, fallback: pool.title, language)
        let localizedSubtitle = L10n.poolSubtitle(for: pool.id, fallback: pool.subtitle, language)
        let sharingNote = L10n.poolSharingNote(for: pool, language)
        let categoryColor = QuotaUITheme.poolCategoryColor(pool.category)

        VStack(alignment: .leading, spacing: compact ? 6 : 9) {
            // Encabezado del Pool: Nombre estandarizado arriba + modelos debajo + nota de arquitectura de compartición si aplica
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 6) {
                    Circle()
                        .fill(poolAccent)
                        .frame(width: compact ? 6 : 7, height: compact ? 6 : 7)

                    Text(localizedTitle)
                        .font(compact ? .system(size: 10.5, weight: .bold) : .system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Text(L10n.categoryBadge(pool.category, language))
                        .font(.system(size: compact ? 7 : 8, weight: .heavy, design: .rounded))
                        .padding(.horizontal, compact ? 4 : 6)
                        .padding(.vertical, 2)
                        .background(categoryColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(categoryColor)
                }

                if let subtitle = localizedSubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: compact ? 8.5 : 9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, compact ? 12 : 13)
                        .lineLimit(2)
                }

                if let sharingNote, !sharingNote.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: pool.sharingArchitecture == .shared5hAndScopedWeekly ? "arrow.triangle.branch" : "lock.shield")
                            .font(.system(size: compact ? 7.5 : 8))
                            .foregroundStyle(poolAccent)
                        Text(sharingNote)
                            .font(.system(size: compact ? 8 : 8.5))
                            .foregroundStyle(.secondary.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, compact ? 12 : 13)
                    .padding(.top, 1)
                }
            }

            if let weekly = pool.weekly7dMetric {
                PrimaryWeeklyRulerView(
                    metric: weekly,
                    badgeLabel: weeklyBadgeLabel(for: weekly),
                    accentColor: poolAccent,
                    compact: compact,
                    displayMode: displayMode,
                    language: language
                )
            } else {
                QuotaWindowStatusRow(window: "7d", message: L10n.unavailableWindow(language), compact: compact)
            }

            if let burst = pool.effective5hMetric {
                if pool.weekly7dMetric != nil {
                    SecondaryBurstRowView(
                        metric: burst,
                        badgeLabel: pool.burst5hMetric == nil ? L10n.shared5hBadgeLabel(language) : L10n.burstWindowBadge(language),
                        accentColor: poolAccent,
                        compact: compact,
                        displayMode: displayMode,
                        language: language
                    )
                } else {
                    PrimaryWindowGaugeView(
                        metric: burst,
                        windowBadge: L10n.burstWindowBadge(language),
                        windowIcon: "bolt.fill",
                        accentColor: poolAccent,
                        compact: compact,
                        displayMode: displayMode,
                        language: language
                    )
                }
            } else {
                QuotaWindowStatusRow(
                    window: pool.sharingArchitecture == .shared5hAndScopedWeekly ? L10n.shared5hBadgeLabel(language) : "5h",
                    message: pool.sharingArchitecture == .independentWeeklyOnly ? L10n.unlimited5h(language) : L10n.unavailableWindow(language),
                    compact: compact
                )
            }

            ForEach(pool.otherMetrics) { other in
                QuotaMetricBarView(
                    metric: other,
                    accentColor: poolAccent,
                    compact: compact,
                    displayMode: displayMode,
                    language: language
                )
            }
        }
        .padding(compact ? 7 : 10)
        .background(
            RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
                .fill(Color.primary.opacity(compact ? 0.045 : 0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 8 : 10, style: .continuous)
                .strokeBorder(poolAccent.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct QuotaWindowStatusRow: View {
    let window: String
    let message: String
    let compact: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(window.uppercased())
                .font(.system(size: compact ? 7.5 : 8.5, weight: .semibold, design: .rounded))
            Spacer(minLength: 4)
            Text(message)
                .font(.system(size: compact ? 8 : 9, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 2)
    }
}

private struct QuotaResetCountdownView: View {
    let countdown: String
    let accentColor: Color
    let compact: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(accentColor)
            Text(countdown)
                .foregroundStyle(.primary.opacity(0.85))
        }
        .font(.system(size: compact ? 8.5 : 9.5, weight: .semibold).monospacedDigit())
        .padding(.horizontal, compact ? 4 : 5)
        .padding(.vertical, 2)
        .background(accentColor.opacity(0.10), in: Capsule())
        .fixedSize()
    }
}

/// Barra protagonista para pools que solo tienen ventana de 5 horas.
struct PrimaryWindowGaugeView: View {
    let metric: QuotaMetric
    let windowBadge: String
    let windowIcon: String
    let accentColor: Color
    let compact: Bool
    let displayMode: QuotaDisplayMode
    let language: AppLanguage

    var body: some View {
        let statusColor = QuotaUITheme.statusColor(remainingPercent: metric.remainingPercent)
        let fraction: Double = {
            switch displayMode {
            case .remaining, .both: return metric.remainingPercent / 100.0
            case .used: return metric.usedPercent / 100.0
            }
        }()

        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                HStack(spacing: 3) {
                    Image(systemName: windowIcon)
                        .font(.system(size: compact ? 8 : 9, weight: .bold))
                        .foregroundStyle(accentColor)
                    Text(windowBadge)
                        .font(.system(size: compact ? 8.5 : 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                if let countdown = metric.formattedResetCountdown() {
                    QuotaResetCountdownView(countdown: countdown, accentColor: accentColor, compact: compact)
                }

                Spacer(minLength: 4)

                Text(displayMode.format(metric: metric, compact: compact, language: language))
                    .font(.system(size: compact ? 10.5 : 12, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(statusColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous)
                        .fill(Color.primary.opacity(0.12))

                    RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous)
                        .fill(statusColor)
                        .frame(width: max(6, geo.size.width * CGFloat(fraction)))
                }
            }
            .frame(height: compact ? 7 : 10)
        }
    }
}

/// Cuota principal del pool: barra semanal (7 días) dividida en 5 partes (20%, 40%, 60%, 80%).
struct PrimaryWeeklyRulerView: View {
    let metric: QuotaMetric
    let badgeLabel: String
    let accentColor: Color
    let compact: Bool
    let displayMode: QuotaDisplayMode
    let language: AppLanguage

    var body: some View {
        let statusColor = QuotaUITheme.statusColor(remainingPercent: metric.remainingPercent)
        let fraction = (displayMode == .used ? metric.usedPercent : metric.remainingPercent) / 100.0

        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.system(size: compact ? 8 : 9, weight: .bold))
                        .foregroundStyle(accentColor)
                    Text(badgeLabel)
                        .font(.system(size: compact ? 8.5 : 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                if let countdown = metric.formattedResetCountdown() {
                    QuotaResetCountdownView(countdown: countdown, accentColor: accentColor, compact: compact)
                }

                Spacer(minLength: 4)

                Text(displayMode.format(metric: metric, compact: compact, language: language))
                    .font(.system(size: compact ? 10.5 : 12, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(statusColor)
            }

            WeeklyQuintileRulerTrack(
                fraction: fraction,
                statusColor: statusColor,
                barHeight: compact ? 6.5 : 9,
                showTickLabels: true
            )
        }
    }
}

/// Cuota secundaria del pool: ventana de 5 horas (propia o compartida con el Pool General), anidada bajo la semanal.
struct SecondaryBurstRowView: View {
    let metric: QuotaMetric
    let badgeLabel: String
    let accentColor: Color
    let compact: Bool
    let displayMode: QuotaDisplayMode
    let language: AppLanguage

    var body: some View {
        let statusColor = QuotaUITheme.statusColor(remainingPercent: metric.remainingPercent)
        let fraction = (displayMode == .used ? metric.usedPercent : metric.remainingPercent) / 100.0

        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: compact ? 7.5 : 8.5, weight: .semibold))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: compact ? 7 : 7.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(badgeLabel)
                            .font(.system(size: compact ? 7.5 : 8.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let countdown = metric.formattedResetCountdown() {
                        QuotaResetCountdownView(countdown: countdown, accentColor: accentColor, compact: compact)
                    }

                    Spacer(minLength: 4)

                    Text(displayMode.format(metric: metric, compact: compact, language: language))
                        .font(.system(size: compact ? 9 : 10, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(statusColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.10))
                        Capsule()
                            .fill(statusColor)
                            .frame(width: max(3, geo.size.width * CGFloat(fraction)))
                    }
                }
                .frame(height: compact ? 3 : 4)
            }
        }
        .padding(.leading, compact ? 4 : 6)
    }
}

/// Barra continua semanal cortada en 5 partes iguales por 4 líneas sutiles con sus etiquetas 20%, 40%, 60%, 80%.
public struct WeeklyQuintileRulerTrack: View {
    public let fraction: Double
    public let statusColor: Color
    public let barHeight: CGFloat
    public let showTickLabels: Bool

    private let ticks: [Double] = [0.20, 0.40, 0.60, 0.80]

    public init(
        fraction: Double,
        statusColor: Color,
        barHeight: CGFloat = 6.5,
        showTickLabels: Bool = true
    ) {
        self.fraction = min(max(fraction, 0.0), 1.0)
        self.statusColor = statusColor
        self.barHeight = barHeight
        self.showTickLabels = showTickLabels
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                ZStack(alignment: .leading) {
                    // Fondo de la barra completa
                    RoundedRectangle(cornerRadius: barHeight / 2, style: .continuous)
                        .fill(Color.primary.opacity(0.11))

                    // Relleno continuo según el porcentaje actual
                    if fraction > 0 {
                        RoundedRectangle(cornerRadius: barHeight / 2, style: .continuous)
                            .fill(statusColor)
                            .frame(width: max(4, totalWidth * CGFloat(fraction)))
                    }

                    // 4 líneas divisorias sutiles que cortan la barra en 5 partes (20%, 40%, 60%, 80%)
                    ForEach(ticks, id: \.self) { tick in
                        let xPos = totalWidth * CGFloat(tick)
                        Rectangle()
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.65))
                            .frame(width: 1.2, height: barHeight)
                            .overlay(
                                Rectangle()
                                    .fill(Color.primary.opacity(0.28))
                                    .frame(width: 0.8, height: barHeight)
                            )
                            .offset(x: xPos - 0.6)
                    }
                }
            }
            .frame(height: barHeight)

            if showTickLabels {
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    ZStack(alignment: .topLeading) {
                        ForEach(ticks, id: \.self) { tick in
                            let pctInt = Int(tick * 100)
                            let xPos = totalWidth * CGFloat(tick)
                            Text("\(pctInt)%")
                                .font(.system(size: 7.5, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(.secondary.opacity(0.62))
                                .frame(width: 26, alignment: .center)
                                .offset(x: xPos - 13)
                        }
                    }
                }
                .frame(height: 10)
            }
        }
    }
}

public struct QuotaMetricBarView: View {
    public let metric: QuotaMetric
    public let accentColor: Color
    public let compact: Bool
    public let displayMode: QuotaDisplayMode
    public let language: AppLanguage

    public init(
        metric: QuotaMetric,
        accentColor: Color,
        compact: Bool = false,
        displayMode: QuotaDisplayMode = .remaining,
        language: AppLanguage = .es
    ) {
        self.metric = metric
        self.accentColor = accentColor
        self.compact = compact
        self.displayMode = displayMode
        self.language = language
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.label)
                    .font(compact ? .caption2.weight(.medium) : .caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .help(metric.detail ?? metric.label)

                Spacer()

                HStack(spacing: 6) {
                    if let countdown = metric.formattedResetCountdown(), !compact {
                        QuotaResetCountdownView(countdown: countdown, accentColor: accentColor, compact: compact)
                    }

                    Text(displayMode.format(metric: metric, compact: compact, language: language))
                        .font(compact ? .caption2.monospacedDigit().bold() : .caption.monospacedDigit().bold())
                        .foregroundStyle(QuotaUITheme.statusColor(remainingPercent: metric.remainingPercent))
                }
            }

            GeometryReader { geo in
                let fraction: Double = {
                    switch displayMode {
                    case .remaining, .both:
                        return metric.remainingPercent / 100.0
                    case .used:
                        return metric.usedPercent / 100.0
                    }
                }()
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.10))

                    Capsule()
                        .fill(QuotaUITheme.statusColor(remainingPercent: metric.remainingPercent))
                        .frame(width: max(4, geo.size.width * CGFloat(fraction)))
                }
            }
            .frame(height: compact ? 5 : 7)
        }
    }
}
