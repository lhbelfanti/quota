import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class QuotaViewModel: ObservableObject {
    @Published var dashboard: QuotaDashboardState
    @Published var isRefreshing: Bool = false
    @Published var signingInProvider: AIProviderKind? = nil
    @Published var statusBanner: String? = nil

    private let aggregator = QuotaAggregator()
    private var refreshTimer: Timer?

    init() {
        if let cached = SharedSnapshotStore.load() {
            self.dashboard = cached
        } else {
            self.dashboard = QuotaDashboardState(
                snapshots: AIProviderKind.allCases.map {
                    ProviderQuotaSnapshot(provider: $0, authState: .unauthenticated)
                }
            )
        }

        Task {
            await refreshAll()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshAll()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.lhbelfanti.AIQuota.refreshRequested"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshAll()
            }
        }
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let updated = await aggregator.refreshAll()
        withAnimation(.easeInOut(duration: 0.2)) {
            self.dashboard = updated
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func signIn(_ provider: AIProviderKind) {
        guard signingInProvider == nil else { return }
        signingInProvider = provider
        statusBanner = "Iniciando sesión en \(provider.displayName)…"

        Task {
            do {
                try await AuthController.signIn(provider: provider)
                statusBanner = nil
            } catch {
                statusBanner = "Error al iniciar sesión en \(provider.displayName): \(error.localizedDescription)"
            }
            signingInProvider = nil
            await refreshAll()
        }
    }

    func signOut(_ provider: AIProviderKind) {
        Task {
            await AuthController.signOut(provider: provider)
            await refreshAll()
        }
    }

    func formattedMenuBarText(preferences: QuotaPreferencesData) -> String {
        let style = preferences.menuBarStyle
        if style == .iconOnly {
            return ""
        }

        let enabled = preferences.menuBarProviders
        if enabled.isEmpty {
            return "AI Quota"
        }

        if style == .lowestOnly {
            let candidates: [(AIProviderKind, String, Double)] = enabled.compactMap { kind in
                let snap = dashboard.snapshot(for: kind)
                guard let summary = preferences.formatProviderSummary(snapshot: snap, compactMenuBar: true) else {
                    return nil
                }
                return (kind, summary.text, summary.statusRemainingPercent)
            }
            guard let lowest = candidates.min(by: { $0.2 < $1.2 }) else {
                return "AI Quota"
            }
            return "\(lowest.0.displayName) \(lowest.1)"
        }

        let parts: [String] = enabled.compactMap { kind in
            let snap = dashboard.snapshot(for: kind)
            guard let summary = preferences.formatProviderSummary(snapshot: snap, compactMenuBar: true) else {
                return nil
            }
            let formattedPct = summary.text
            switch style {
            case .logosAndPercentages:
                return "\(kind.menuBarSymbol) \(formattedPct)"
            case .compactInitials:
                let prefix: String
                switch kind {
                case .claude: prefix = "C"
                case .codex: prefix = "X"
                case .gemini: prefix = "G"
                }
                return "\(prefix) \(formattedPct)"
            case .fullNames:
                return "\(kind.displayName) \(formattedPct)"
            case .lowestOnly, .iconOnly:
                return nil
            }
        }

        if parts.isEmpty {
            return "AI Quota"
        }
        if preferences.summaryWindowMode == .weeklyAndBurst {
            switch preferences.dualWindowLayoutStyle {
            case .subscripts:
                return parts.joined(separator: "  │  ")
            case .capsulePills:
                return parts.map { "[ \($0) ]" }.joined(separator: "  ")
            default:
                return parts.joined(separator: " · ")
            }
        }
        return parts.joined(separator: " · ")
    }
}
