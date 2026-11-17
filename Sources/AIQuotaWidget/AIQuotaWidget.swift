import WidgetKit
import SwiftUI
import AppIntents

public struct RefreshAIQuotaIntent: AppIntent {
    public static var title: LocalizedStringResource = "Actualizar Cuotas AI"
    public static var description = IntentDescription("Actualiza inmediatamente las cuotas de Claude, Codex y Gemini.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.lhbelfanti.AIQuota.refreshRequested"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        let aggregator = QuotaAggregator()
        let fresh = await aggregator.refreshAll()
        if fresh.snapshots.contains(where: { $0.authState == .authenticated }) {
            SharedSnapshotStore.save(fresh)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct QuotaTimelineEntry: TimelineEntry {
    let date: Date
    let dashboard: QuotaDashboardState
    let preferences: QuotaPreferencesData
}

struct QuotaTimelineProvider: TimelineProvider {
    private let aggregator = QuotaAggregator()

    func placeholder(in context: Context) -> QuotaTimelineEntry {
        QuotaTimelineEntry(
            date: Date(),
            dashboard: Self.sampleDashboard,
            preferences: PreferencesStore.loadFromDisk() ?? QuotaPreferencesData()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (QuotaTimelineEntry) -> Void) {
        let prefs = PreferencesStore.loadFromDisk() ?? QuotaPreferencesData()
        if let cached = SharedSnapshotStore.load() {
            completion(QuotaTimelineEntry(date: Date(), dashboard: cached, preferences: prefs))
        } else {
            completion(QuotaTimelineEntry(date: Date(), dashboard: Self.sampleDashboard, preferences: prefs))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaTimelineEntry>) -> Void) {
        Task {
            let prefs = PreferencesStore.loadFromDisk() ?? QuotaPreferencesData()
            let state: QuotaDashboardState
            if let cached = SharedSnapshotStore.load() {
                state = cached
            } else {
                let refreshed = await aggregator.refreshAll()
                let hasAuth = refreshed.snapshots.contains { $0.authState == .authenticated }
                state = hasAuth ? refreshed : Self.sampleDashboard
            }
            let entry = QuotaTimelineEntry(date: state.lastRefreshedAt, dashboard: state, preferences: prefs)
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 2, to: Date()) ?? Date().addingTimeInterval(120)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }

    static var sampleDashboard: QuotaDashboardState {
        func sample(_ poolId: String, _ window: QuotaWindowKind, _ used: Double, allowance: Double? = nil, usedOfGeneral: Double? = nil) -> QuotaMetric? {
            ModelCatalog.pool(id: poolId)?.metric(
                id: "\(poolId)-\(window.rawValue)",
                window: window,
                usedPercent: used,
                weeklyAllowancePercentOfGeneral: allowance,
                weeklyUsedPercentOfGeneral: usedOfGeneral
            )
        }

        return QuotaDashboardState(
            snapshots: [
                ProviderQuotaSnapshot(
                    provider: .claude,
                    authState: .authenticated,
                    accountLabel: "Claude Pro",
                    planTier: "PRO",
                    metrics: [
                        sample("claude-general", .burst5h, 12),
                        sample("claude-general", .weekly7d, 24),
                        sample("claude-fable", .weekly7d, 8, allowance: 50, usedOfGeneral: 4)
                    ].compactMap { $0 }
                ),
                ProviderQuotaSnapshot(
                    provider: .codex,
                    authState: .authenticated,
                    accountLabel: "ChatGPT Plus",
                    planTier: "PLUS",
                    metrics: [
                        sample("codex-general", .burst5h, 5),
                        sample("codex-general", .weekly7d, 18)
                    ].compactMap { $0 }
                ),
                ProviderQuotaSnapshot(
                    provider: .gemini,
                    authState: .authenticated,
                    accountLabel: "Google AI Pro",
                    planTier: "AI PRO",
                    metrics: [
                        sample("agy-gemini", .burst5h, 1),
                        sample("agy-gemini", .weekly7d, 13),
                        sample("agy-argon", .weekly7d, 44),
                        sample("agy-3p", .burst5h, 0),
                        sample("agy-3p", .weekly7d, 12)
                    ].compactMap { $0 }
                )
            ]
        )
    }
}

struct AIQuotaWidgetEntryView: View {
    var entry: QuotaTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    private var lang: AppLanguage {
        entry.preferences.language
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            largeView
        }
    }

    @ViewBuilder
    private var refreshHeaderTimeAndButton: some View {
        HStack(spacing: 5) {
            Text(entry.date, style: .time)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize()

            Button(intent: RefreshAIQuotaIntent()) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .background(Color.primary.opacity(0.10), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Quota")
                    .font(.caption.bold())
                Spacer()
                refreshHeaderTimeAndButton
            }

            ForEach(entry.preferences.visibleProviders) { kind in
                let snap = entry.dashboard.snapshot(for: kind)
                HStack(spacing: 6) {
                    ProviderBrandLogoView(provider: kind, size: 15)
                    if entry.preferences.dualWindowLayoutStyle != .capsulePills || entry.preferences.summaryWindowMode != .weeklyAndBurst {
                        Text(kind.displayName)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 2)
                    if let tokens = entry.preferences.summaryTokens(for: snap, compactMenuBar: true).first {
                        widgetCompactSummaryBadge(tokens: tokens, isSmallWidget: true)
                    } else {
                        Text("—")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("AI Quota Monitor")
                    .font(.caption.bold())
                Spacer()
                refreshHeaderTimeAndButton
            }

            HStack(spacing: 8) {
                ForEach(entry.preferences.visibleProviders) { kind in
                    let snap = entry.dashboard.snapshot(for: kind)
                    let color = QuotaUITheme.providerColor(kind)
                    let allTokens = entry.preferences.summaryTokens(for: snap, compactMenuBar: true)
                    let tokens = entry.preferences.dualWindowLayoutStyle == .capsulePills ? allTokens : Array(allTokens.prefix(1))
                    let selectedPool = entry.preferences.menuBarPools(for: snap).first
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            ProviderBrandLogoView(provider: kind, size: 16)
                            Text(kind.displayName)
                                .font(.caption2.weight(.bold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }

                        if snap.authState == .authenticated, !tokens.isEmpty {
                            ForEach(tokens, id: \.poolId) { item in
                                HStack(spacing: 3) {
                                    if tokens.count > 1 {
                                        Text(item.tag ?? "G")
                                            .font(.system(size: 7, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    widgetCompactSummaryBadge(tokens: item, isSmallWidget: false)
                                }
                                if item.burst5hIsShared, let detail = item.burst5hDetail {
                                    Text(detail)
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            if tokens.count == 1, let selectedPool {
                                Text(L10n.poolTitle(for: selectedPool.id, category: selectedPool.category, fallback: selectedPool.title, lang))
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Text(L10n.activePoolsCount(snap.pools.count, lang))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(color)
                                .lineLimit(1)
                        } else {
                            Text(L10n.notConnectedShort(lang))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private func widgetCompactSummaryBadge(tokens: ProviderSummaryTokens, isSmallWidget: Bool) -> some View {
        let style = entry.preferences.dualWindowLayoutStyle
        let mainStatusColor = QuotaUITheme.statusColor(remainingPercent: tokens.statusRemainingPercent)

        if entry.preferences.summaryWindowMode == .weeklyAndBurst,
           let wText = tokens.weekly7dText,
           let bText = tokens.burst5hText {
            let wColor = tokens.weekly7dRemaining.map { QuotaUITheme.statusColor(remainingPercent: $0) } ?? Color.secondary
            let bColor = tokens.burst5hRemaining.map { QuotaUITheme.statusColor(remainingPercent: $0) } ?? Color.secondary
            let burstLabel = tokens.burst5hIsShared ? "5h↗" : "5h"

            switch style {
            case .stackedTwoLines:
                if isSmallWidget {
                    VStack(alignment: .trailing, spacing: -1) {
                        Text("\(bText) \(burstLabel)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(bColor)
                        Text("\(wText) 7d")
                            .font(.system(size: 8, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(wColor.opacity(0.85))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(bText)
                                .font(.system(size: 12.5, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(bColor)
                            Text(burstLabel)
                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(wText)
                                .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(wColor.opacity(0.9))
                            Text("7d")
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            case .capsulePills:
                ViewThatFits(in: .horizontal) {
                    QuotaSummaryPillSegment(tokens: tokens, fontSize: isSmallWidget ? 9 : 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(bText) \(burstLabel)")
                            .foregroundStyle(bColor)
                        Text("\(wText) 7d")
                            .foregroundStyle(wColor)
                    }
                    .font(.system(size: 8, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            default:
                Text(tokens.singleText)
                    .font(.system(size: isSmallWidget ? 9.5 : 10.5, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(mainStatusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        } else {
            Text(tokens.singleText)
                .font(.system(size: isSmallWidget ? 10.5 : 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(mainStatusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("AI Quota Monitor")
                    .font(.caption.bold())
                Spacer()
                refreshHeaderTimeAndButton
            }

            ForEach(entry.preferences.visibleProviders) { kind in
                let snap = entry.dashboard.snapshot(for: kind)
                let color = QuotaUITheme.providerColor(kind)
                // Solo entran 2 filas: primero los pools elegidos para la barra superior, después el resto.
                let orderedPools: [QuotaPoolGroup] = {
                    let selectedIds = entry.preferences.menuBarPools(for: snap).map(\.id)
                    let all = snap.pools
                    let prioritized = all.filter { selectedIds.contains($0.id) } + all.filter { !selectedIds.contains($0.id) }
                    return Array(prioritized.prefix(2))
                }()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        ProviderBrandLogoView(provider: kind, size: 15)
                        Text(kind.displayName)
                            .font(.caption2.bold())
                        if let plan = snap.planTier {
                            Text(plan)
                                .font(.system(size: 7.5, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(color.opacity(0.2), in: Capsule())
                                .foregroundStyle(color)
                        }
                        Spacer()
                    }

                    if snap.authState == .authenticated {
                        VStack(spacing: 3.5) {
                            ForEach(orderedPools) { pool in
                                WidgetCompactPoolRowView(
                                    pool: pool,
                                    providerColor: color,
                                    displayMode: entry.preferences.quotaDisplayMode,
                                    language: lang
                                )
                            }
                        }
                    } else {
                        Text(L10n.signInFromMenuBar(lang))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(6)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

/// Vista compacta de un Pool para el widget de escritorio Large:
/// Muestra el nombre estandarizado del Pool, los modelos que contiene debajo y la barra de la cuota principal (7d, o 5h si no hay semanal).
struct WidgetCompactPoolRowView: View {
    let pool: QuotaPoolGroup
    let providerColor: Color
    let displayMode: QuotaDisplayMode
    let language: AppLanguage

    private var poolAccent: Color {
        QuotaUITheme.poolCategoryAccent(pool.category, baseColor: providerColor)
    }

    var body: some View {
        let localizedTitle = L10n.poolTitle(for: pool.id, category: pool.category, fallback: pool.title, language)
        let localizedSubtitle = L10n.poolSubtitle(for: pool.id, fallback: pool.subtitle, language)

        VStack(alignment: .leading, spacing: 2.5) {
            HStack(spacing: 5) {
                Circle()
                    .fill(poolAccent)
                    .frame(width: 5, height: 5)

                Text(localizedTitle)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let burst = pool.effective5hMetric {
                    HStack(spacing: 2) {
                        if pool.burst5hMetric == nil {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 6.5))
                                .foregroundStyle(poolAccent)
                        }
                        Text(displayMode.formatMenuBarPercent(remainingPercent: burst.remainingPercent))
                            .font(.system(size: 8.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(QuotaUITheme.statusColor(remainingPercent: burst.remainingPercent).opacity(0.9))
                        Text(pool.burst5hMetric == nil ? "5h↗" : "5h")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(pool.sharingArchitecture == .independentWeeklyOnly ? "∞ 5h" : "— 5h")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .help(pool.sharingArchitecture == .independentWeeklyOnly ? L10n.unlimited5h(language) : L10n.unavailableWindow(language))
                }
                if pool.weekly7dMetric != nil {
                    Text("·")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                if let weekly = pool.weekly7dMetric {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.system(size: 7))
                            .foregroundStyle(poolAccent)
                        Text(displayMode.formatMenuBarPercent(remainingPercent: weekly.remainingPercent))
                            .font(.system(size: 9, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(QuotaUITheme.statusColor(remainingPercent: weekly.remainingPercent))
                        Text("7d")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("— 7d")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if let subtitle = localizedSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 7.5))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
                    .lineLimit(1)
            }

            if pool.sharingArchitecture == .shared5hAndScopedWeekly {
                Text(L10n.shared5hNote(language))
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let weekly = pool.weekly7dMetric {
                let statusColor = QuotaUITheme.statusColor(remainingPercent: weekly.remainingPercent)
                let fraction = (displayMode == .used ? weekly.usedPercent : weekly.remainingPercent) / 100.0
                WeeklyQuintileRulerTrack(
                    fraction: fraction,
                    statusColor: statusColor,
                    barHeight: 4.5,
                    showTickLabels: false
                )
            } else if let burst = pool.burst5hMetric {
                let statusColor = QuotaUITheme.statusColor(remainingPercent: burst.remainingPercent)
                let fraction = (displayMode == .used ? burst.usedPercent : burst.remainingPercent) / 100.0
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.primary.opacity(0.12))
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(statusColor)
                            .frame(width: max(4, geo.size.width * CGFloat(fraction)))
                    }
                }
                .frame(height: 4.5)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))
    }
}

@main
struct AIQuotaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AIQuotaMonitorWidget()
    }
}

struct AIQuotaMonitorWidget: Widget {
    let kind: String = "AIQuotaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuotaTimelineProvider()) { entry in
            AIQuotaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("AI Quota (Claude, Codex, Gemini)")
        .description("Muestra la cuota disponible en tiempo real de tus cuentas de Claude, Codex y Gemini / Antigravity.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
