import SwiftUI

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

    public static func poolCategoryAccent(_ category: QuotaPoolCategory, baseColor: Color) -> Color {
        switch category {
        case .core:
            return baseColor
        case .dedicated:
            return Color(red: 0.66, green: 0.44, blue: 0.96)
        case .partner:
            return Color(red: 0.25, green: 0.72, blue: 0.88)
        }
    }

    public static func statusColor(remainingPercent: Double) -> Color {
        if remainingPercent <= 15 {
            return .red
        } else if remainingPercent <= 40 {
            return .orange
        } else {
            return .green
        }
    }
}

/// Tarjeta visual de un Pool de Cuota que jerarquiza la ventana inmediata (5h) frente al presupuesto semanal (7d).
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

    public var body: some View {
        let localizedTitle = L10n.poolTitle(for: pool.id, fallback: pool.title, language)
        let localizedSubtitle = L10n.poolSubtitle(for: pool.id, fallback: pool.subtitle, language)

        VStack(alignment: .leading, spacing: compact ? 6 : 9) {
            // Encabezado del Pool: Nombre completo arriba + aclaración debajo (nunca a la derecha)
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
                        .background(poolAccent.opacity(0.16), in: Capsule())
                        .foregroundStyle(poolAccent)
                }

                if let subtitle = localizedSubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: compact ? 8.5 : 9.5))
                        .foregroundStyle(.secondary)
                        .padding(.leading, compact ? 12 : 13)
                        .lineLimit(2)
                }
            }

            if let burst = pool.burst5hMetric, let weekly = pool.weekly7dMetric {
                // Caso Dual: Ventana de Ráfaga (5h) + Presupuesto Semanal (7d) con divisiones 20/40/60/80%
                PrimaryWindowGaugeView(
                    metric: burst,
                    windowBadge: L10n.burstWindowBadge(language),
                    windowIcon: "bolt.fill",
                    accentColor: poolAccent,
                    compact: compact,
                    displayMode: displayMode,
                    language: language
                )

                SecondaryWeeklyRulerView(
                    metric: weekly,
                    accentColor: poolAccent,
                    compact: compact,
                    displayMode: displayMode,
                    language: language
                )
            } else if let burst = pool.burst5hMetric {
                PrimaryWindowGaugeView(
                    metric: burst,
                    windowBadge: L10n.burstWindowBadge(language),
                    windowIcon: "bolt.fill",
                    accentColor: poolAccent,
                    compact: compact,
                    displayMode: displayMode,
                    language: language
                )
            } else if let weekly = pool.weekly7dMetric {
                // Pool exclusivamente semanal (ej. Argon 7d o Fable 7d)
                DedicatedWeeklyPoolRulerView(
                    metric: weekly,
                    accentColor: poolAccent,
                    compact: compact,
                    displayMode: displayMode,
                    language: language
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

/// Barra protagonista de alta prioridad para la ventana inmediata de 5 horas.
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
                    Text("· ↻ \(countdown)")
                        .font(.system(size: compact ? 8 : 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
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
                        .fill(
                            LinearGradient(
                                colors: [accentColor, statusColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * CGFloat(fraction)))
                }
            }
            .frame(height: compact ? 7 : 10)
        }
    }
}

/// Barra semanal (7 días) completa con 4 líneas divisorias sutiles (cortando en 5 partes: 20%, 40%, 60%, 80%)
/// y porcentaje actual al final de la línea.
struct SecondaryWeeklyRulerView: View {
    let metric: QuotaMetric
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

        VStack(alignment: .leading, spacing: compact ? 2 : 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.system(size: compact ? 8 : 8.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.weeklyWindowBadge(language))
                        .font(.system(size: compact ? 8 : 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let countdown = metric.formattedResetCountdown() {
                    Text("· ↻ \(countdown)")
                        .font(.system(size: compact ? 7.5 : 8.5).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 4)

                Text(displayMode.format(metric: metric, compact: compact, language: language))
                    .font(.system(size: compact ? 9.5 : 10.5, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(statusColor.opacity(0.95))
            }

            WeeklyQuintileRulerTrack(
                fraction: fraction,
                accentColor: accentColor,
                statusColor: statusColor,
                barHeight: compact ? 5 : 6.5,
                showTickLabels: true
            )
        }
        .padding(.top, 2)
    }
}

/// Vista para Pools cuyo único límite es semanal (ej. Gemini 4 Argon 7d o Fable 7d en Claude),
/// usando también la barra completa dividida en 5 partes (20%, 40%, 60%, 80%).
struct DedicatedWeeklyPoolRulerView: View {
    let metric: QuotaMetric
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

        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                HStack(spacing: 3) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: compact ? 8 : 9, weight: .bold))
                        .foregroundStyle(accentColor)
                    Text(L10n.dedicatedWeeklyBadge(language))
                        .font(.system(size: compact ? 8 : 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let countdown = metric.formattedResetCountdown() {
                    Text("· ↻ \(countdown)")
                        .font(.system(size: compact ? 8 : 8.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Text(displayMode.format(metric: metric, compact: compact, language: language))
                    .font(.system(size: compact ? 10.5 : 11.5, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(statusColor)
            }

            WeeklyQuintileRulerTrack(
                fraction: fraction,
                accentColor: accentColor,
                statusColor: statusColor,
                barHeight: compact ? 5.5 : 7.5,
                showTickLabels: true
            )
        }
    }
}

/// Barra continua semanal cortada en 5 partes iguales por 4 líneas sutiles con sus etiquetas 20%, 40%, 60%, 80%.
public struct WeeklyQuintileRulerTrack: View {
    public let fraction: Double
    public let accentColor: Color
    public let statusColor: Color
    public let barHeight: CGFloat
    public let showTickLabels: Bool

    private let ticks: [Double] = [0.20, 0.40, 0.60, 0.80]

    public init(
        fraction: Double,
        accentColor: Color,
        statusColor: Color,
        barHeight: CGFloat = 6.5,
        showTickLabels: Bool = true
    ) {
        self.fraction = min(max(fraction, 0.0), 1.0)
        self.accentColor = accentColor
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
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.85), statusColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
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
                        Text("↻ \(countdown)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor,
                                    QuotaUITheme.statusColor(remainingPercent: metric.remainingPercent)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(fraction)))
                }
            }
            .frame(height: compact ? 5 : 7)
        }
    }
}
