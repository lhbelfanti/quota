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
        QuotaDashboardState(
            snapshots: [
                ProviderQuotaSnapshot(
                    provider: .claude,
                    authState: .authenticated,
                    accountLabel: "Claude Pro",
                    planTier: "PRO",
                    metrics: [
                        QuotaMetric(
                            id: "claude-5h",
                            label: "Sesión (5h)",
                            usedPercent: 12,
                            poolId: "claude-general",
                            poolTitle: "Pool General",
                            poolCategory: .core,
                            windowKind: .burst5h
                        ),
                        QuotaMetric(
                            id: "claude-7d",
                            label: "Semanal (7d)",
                            usedPercent: 24,
                            poolId: "claude-general",
                            poolTitle: "Pool General",
                            poolCategory: .core,
                            windowKind: .weekly7d
                        ),
                        QuotaMetric(
                            id: "claude-scoped-fable",
                            label: "Fable (7d)",
                            usedPercent: 8,
                            poolId: "claude-fable",
                            poolTitle: "Pool Exclusivo",
                            poolSubtitle: "Claude Fable",
                            poolCategory: .dedicated,
                            windowKind: .weekly7d,
                            weeklyAllowancePercentOfGeneral: 50,
                            weeklyUsedPercentOfGeneral: 4
                        )
                    ]
                ),
                ProviderQuotaSnapshot(
                    provider: .codex,
                    authState: .authenticated,
                    accountLabel: "ChatGPT Plus",
                    planTier: "PLUS",
                    metrics: [
                        QuotaMetric(
                            id: "codex-primary",
                            label: "Sesión (5h)",
                            usedPercent: 5,
                            poolId: "codex-general",
                            poolTitle: "Pool General",
                            poolSubtitle: "GPT-5 · o3 · Codex CLI",
                            poolCategory: .core,
                            windowKind: .burst5h
                        ),
                        QuotaMetric(
                            id: "codex-secondary",
                            label: "Semanal (7d)",
                            usedPercent: 18,
                            poolId: "codex-general",
                            poolTitle: "Pool General",
                            poolSubtitle: "GPT-5 · o3 · Codex CLI",
                            poolCategory: .core,
                            windowKind: .weekly7d
                        )
                    ]
                ),
                ProviderQuotaSnapshot(
                    provider: .gemini,
                    authState: .authenticated,
                    accountLabel: "Google AI Pro",
                    planTier: "AI PRO",
                    metrics: [
                        QuotaMetric(
                            id: "agy-gemini-5h",
                            label: "Gemini Hydrogen / 3.8 Flash / Pro (5h)",
                            usedPercent: 1,
                            poolId: "agy-gemini",
                            poolTitle: "Pool General",
                            poolSubtitle: "Gemini 4 Hydrogen · Gemini 3.8 Flash · Gemini 2.5 Pro",
                            poolCategory: .core,
                            windowKind: .burst5h
                        ),
                        QuotaMetric(
                            id: "agy-gemini-weekly",
                            label: "Gemini Hydrogen / 3.8 Flash / Pro (7d)",
                            usedPercent: 13,
                            poolId: "agy-gemini",
                            poolTitle: "Pool General",
                            poolSubtitle: "Gemini 4 Hydrogen · Gemini 3.8 Flash · Gemini 2.5 Pro",
                            poolCategory: .core,
                            windowKind: .weekly7d
                        ),
                        QuotaMetric(
                            id: "agy-gemini-argon-wtu-weekly",
                            label: "Gemini 4 Argon · Orchestrator (7d)",
                            usedPercent: 44,
                            poolId: "agy-argon",
                            poolTitle: "Pool Exclusivo",
                            poolSubtitle: "Gemini 4 Argon (Low / Med / High) · Orchestrator",
                            poolCategory: .dedicated,
                            windowKind: .weekly7d
                        ),
                        QuotaMetric(
                            id: "agy-3p-5h",
                            label: "Claude 5.5 & GPT-OSS 120B (5h)",
                            usedPercent: 0,
                            poolId: "agy-3p",
                            poolTitle: "Pool de Partners",
                            poolSubtitle: "Claude Opus 5.5 · Claude Sonnet 5.5 · GPT-OSS 120B",
                            poolCategory: .partner,
                            windowKind: .burst5h
                        ),
                        QuotaMetric(
                            id: "agy-3p-weekly",
                            label: "Claude 5.5 & GPT-OSS 120B (7d)",
                            usedPercent: 12,
                            poolId: "agy-3p",
                            poolTitle: "Pool de Partners",
                            poolSubtitle: "Claude Opus 5.5 · Claude Sonnet 5.5 · GPT-OSS 120B",
                            poolCategory: .partner,
                            windowKind: .weekly7d
                        )
                    ]
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
                    Text(kind.displayName)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if let tokens = entry.preferences.summaryTokens(for: snap, compactMenuBar: true) {
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
                    let selectedCategory = entry.preferences.preferredPoolCategory(for: kind)
                    let selectedPool = snap.pool(for: selectedCategory)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            ProviderBrandLogoView(provider: kind, size: 16)
                            Text(kind.displayName)
                                .font(.caption2.weight(.bold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }

                        if snap.authState == .authenticated,
                           let tokens = entry.preferences.summaryTokens(for: snap, compactMenuBar: false) {
                            widgetCompactSummaryBadge(tokens: tokens, isSmallWidget: false)

                            if let selectedPool {
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

        if entry.preferences.summaryWindowMode == .fiveHourAndSevenDay,
           let bText = tokens.burst5hText,
           let wText = tokens.weekly7dText {
            let bColor = QuotaUITheme.statusColor(remainingPercent: tokens.burst5hRemaining ?? tokens.statusRemainingPercent)
            let wColor = QuotaUITheme.statusColor(remainingPercent: tokens.weekly7dRemaining ?? tokens.statusRemainingPercent)

            switch style {
            case .stackedTwoLines:
                if isSmallWidget {
                    VStack(alignment: .trailing, spacing: -1) {
                        Text("\(bText) 5h")
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
                            Text("5h")
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
                HStack(spacing: 3) {
                    Text(bText)
                        .font(.system(size: isSmallWidget ? 9.5 : 10.5, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(bColor)
                    Text("·")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(wText)
                        .font(.system(size: isSmallWidget ? 9 : 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(wColor.opacity(0.9))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.08), in: Capsule())
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
                let orderedPools: [QuotaPoolGroup] = {
                    let all = snap.pools
                    let preferredCat = entry.preferences.preferredPoolCategory(for: kind)
                    // Si hay más de 2 pools (ej. Gemini: General, Exclusivo, Partners) y el usuario eligió Partners como principal,
                    // aseguramos que Pool General y el Pool elegido entren en las 2 filas visibles manteniendo su orden natural.
                    if all.count > 2, preferredCat == .partner {
                        return all.filter { $0.category == .core || $0.category == .partner }
                    }
                    return Array(all.prefix(2))
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
/// Muestra el nombre estandarizado del Pool, los modelos que contiene debajo y la barra de 5h (propia o compartida) y/o 7d.
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

                if let burst = pool.burst5hMetric {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(poolAccent)
                        Text(displayMode.formatMenuBarPercent(remainingPercent: burst.remainingPercent))
                            .font(.system(size: 9, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(QuotaUITheme.statusColor(remainingPercent: burst.remainingPercent))
                        Text("5h")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else if pool.sharingArchitecture == .shared5hAndScopedWeekly, let shared5h = pool.sharedBurst5hMetric {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 6.5))
                            .foregroundStyle(poolAccent)
                        Text(displayMode.formatMenuBarPercent(remainingPercent: shared5h.remainingPercent))
                            .font(.system(size: 8.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(QuotaUITheme.statusColor(remainingPercent: shared5h.remainingPercent).opacity(0.9))
                        Text("5h")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if (pool.burst5hMetric != nil || (pool.sharingArchitecture == .shared5hAndScopedWeekly && pool.sharedBurst5hMetric != nil)) && pool.weekly7dMetric != nil {
                    Text("·")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                if let weekly = pool.weekly7dMetric {
                    HStack(spacing: 2) {
                        Text(displayMode.formatMenuBarPercent(remainingPercent: weekly.remainingPercent))
                            .font(.system(size: 8.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(QuotaUITheme.statusColor(remainingPercent: weekly.remainingPercent).opacity(0.9))
                        Text("7d")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let subtitle = localizedSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 7.5))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)
                    .lineLimit(1)
            }

            if let burst = pool.burst5hMetric {
                let statusColor = QuotaUITheme.statusColor(remainingPercent: burst.remainingPercent)
                let fraction = (displayMode == .used ? burst.usedPercent : burst.remainingPercent) / 100.0
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.primary.opacity(0.12))
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(LinearGradient(colors: [poolAccent, statusColor], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(4, geo.size.width * CGFloat(fraction)))
                    }
                }
                .frame(height: 4.5)
            } else if let weekly = pool.weekly7dMetric {
                let statusColor = QuotaUITheme.statusColor(remainingPercent: weekly.remainingPercent)
                let fraction = (displayMode == .used ? weekly.usedPercent : weekly.remainingPercent) / 100.0
                WeeklyQuintileRulerTrack(
                    fraction: fraction,
                    accentColor: poolAccent,
                    statusColor: statusColor,
                    barHeight: 4.5,
                    showTickLabels: true
                )
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
