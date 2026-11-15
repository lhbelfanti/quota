import Foundation
import WidgetKit

public enum SharedSnapshotStore {
    public static var cacheFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("AIQuota", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("quota-snapshot.json")
    }

    public static var widgetContainerCacheFileURL: URL {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let dir = home.appendingPathComponent(
            "Library/Containers/com.lhbelfanti.AIQuota.WidgetExtension/Data/Library/Application Support/AIQuota",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("quota-snapshot.json")
    }

    public static func save(_ state: QuotaDashboardState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: cacheFileURL, options: .atomic)

        // Mirror into the sandboxed WidgetKit extension container so desktop widgets
        // placed via "Right-click Desktop -> Edit Widgets..." always have the latest data.
        let widgetURL = widgetContainerCacheFileURL
        if widgetURL.path != cacheFileURL.path {
            try? data.write(to: widgetURL, options: .atomic)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    public static func load() -> QuotaDashboardState? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: cacheFileURL),
           let decoded = try? decoder.decode(QuotaDashboardState.self, from: data) {
            return decoded
        }
        if let data = try? Data(contentsOf: widgetContainerCacheFileURL),
           let decoded = try? decoder.decode(QuotaDashboardState.self, from: data) {
            return decoded
        }
        return nil
    }
}

public actor QuotaAggregator {
    private let claudeClient = ClaudeProviderClient()
    private let codexClient = CodexProviderClient()
    private let geminiClient = GeminiProviderClient()

    public init() {}

    public func refreshAll() async -> QuotaDashboardState {
        async let claude = claudeClient.fetchSnapshot()
        async let codex = codexClient.fetchSnapshot()
        async let gemini = geminiClient.fetchSnapshot()

        let snapshots = await [claude, codex, gemini]
        let state = QuotaDashboardState(snapshots: snapshots, lastRefreshedAt: Date())
        SharedSnapshotStore.save(state)
        return state
    }

    public func refresh(provider: AIProviderKind, current: QuotaDashboardState?) async -> QuotaDashboardState {
        let updated: ProviderQuotaSnapshot
        switch provider {
        case .claude:
            updated = await claudeClient.fetchSnapshot()
        case .codex:
            updated = await codexClient.fetchSnapshot()
        case .gemini:
            updated = await geminiClient.fetchSnapshot()
        }

        var map: [AIProviderKind: ProviderQuotaSnapshot] = [:]
        if let current {
            for item in current.snapshots {
                map[item.provider] = item
            }
        }
        map[provider] = updated
        let ordered = AIProviderKind.allCases.map { kind in
            map[kind] ?? ProviderQuotaSnapshot(provider: kind, authState: .unauthenticated)
        }
        let state = QuotaDashboardState(snapshots: ordered, lastRefreshedAt: Date())
        SharedSnapshotStore.save(state)
        return state
    }
}
