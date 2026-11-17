import Foundation
import Combine
import WidgetKit

public enum QuotaDisplayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case remaining = "remaining"
    case used = "used"
    case both = "both"

    public var id: String { rawValue }

    public var title: String {
        L10n.displayModeTitle(self, .es)
    }

    public func localizedTitle(_ lang: AppLanguage) -> String {
        L10n.displayModeTitle(self, lang)
    }

    public func format(metric: QuotaMetric, compact: Bool = false, language: AppLanguage = .es) -> String {
        let avail = L10n.availShort(language)
        switch self {
        case .remaining:
            return String(format: "%.0f%% %@", metric.remainingPercent, avail)
        case .used:
            let used = L10n.usedShort(language, compact: false)
            return String(format: "%.0f%% %@", metric.usedPercent, used)
        case .both:
            if compact {
                let uShort = L10n.usedShort(language, compact: true)
                return String(format: "%.0f%% %@ (%.0f%% %@)", metric.remainingPercent, avail, metric.usedPercent, uShort)
            }
            let used = L10n.usedShort(language, compact: false)
            return String(format: "%.0f%% %@ · %.0f%% %@", metric.remainingPercent, avail, metric.usedPercent, used)
        }
    }

    public func formatMenuBarPercent(remainingPercent: Double) -> String {
        let clampedRemaining = min(max(remainingPercent, 0.0), 100.0)
        let used = max(0.0, 100.0 - clampedRemaining)
        switch self {
        case .remaining:
            return String(format: "%.0f%%", clampedRemaining)
        case .used:
            return String(format: "%.0f%%u", used)
        case .both:
            return String(format: "%.0f%% (%.0f%%u)", clampedRemaining, used)
        }
    }
}

public enum SummaryWindowMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Muestra únicamente la cuota principal de 7 días (o la de 5h si el pool no tiene semanal).
    case weeklyOnly = "weeklyOnly"
    /// Muestra las ventanas de 5 horas y 7 días, en ese orden.
    case weeklyAndBurst = "weeklyAndBurst"

    public var id: String { rawValue }

    public func localizedTitle(_ lang: AppLanguage) -> String {
        L10n.summaryWindowModeTitle(self, lang)
    }
}

/// Estilo de visualización del resumen de 5h y 7d.
public enum DualWindowLayoutStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Opción 1: Dos líneas apiladas por cada pool (arriba 79% 5h, abajo 34% 7d).
    case stackedTwoLines = "stackedTwoLines"
    /// Opción 2A: En una línea con la 7d entre paréntesis: ❋ 79% (34% 7d).
    case parentheses5h = "parentheses5h"
    /// Opción 2B: En una línea con subíndices y barra vertical entre IAs: ❋ 79%₅ₕ 34%₇𝒹 │ ⏣ 95%₅ₕ 78%₇𝒹.
    case subscripts = "subscripts"
    /// Opción 3: Mini cápsulas (Pills) por IA: [ ❋ 79% 5h · 34% 7d ].
    case capsulePills = "capsulePills"
    /// Opción 4: En línea clásica con punto intermedio: ❋ 79% 5h · 34% 7d.
    case inlineDot = "inlineDot"

    public var id: String { rawValue }

    public func localizedTitle(_ lang: AppLanguage) -> String {
        L10n.dualWindowLayoutStyleTitle(self, lang)
    }
}

/// Componentes estructurados del resumen de un pool para renderizarlo en 1 línea, 2 pisos o cápsula.
public struct ProviderSummaryTokens: Equatable, Sendable {
    public let provider: AIProviderKind
    public let poolId: String
    /// Etiqueta corta del pool; solo presente cuando el proveedor muestra más de un pool.
    public let tag: String?
    public let weekly7dText: String?
    public let weekly7dRemaining: Double?
    public let burst5hText: String?
    public let burst5hRemaining: Double?
    public let burst5hIsShared: Bool
    public let burst5hDetail: String?
    public let singleText: String
    public let statusRemainingPercent: Double

    public var isDualWindow: Bool {
        burst5hText != nil && weekly7dText != nil
    }

    public var taggedText: String {
        [tag, singleText].compactMap { $0 }.joined(separator: " ")
    }
}

public enum MenuBarDisplayStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case logosAndPercentages = "logosAndPercentages"
    case compactInitials = "compactInitials"
    case fullNames = "fullNames"
    case lowestOnly = "lowestOnly"
    case iconOnly = "iconOnly"

    public var id: String { rawValue }

    public var title: String {
        L10n.menuBarStyleTitle(self, .es)
    }

    public func localizedTitle(_ lang: AppLanguage) -> String {
        L10n.menuBarStyleTitle(self, lang)
    }
}

public struct QuotaPreferencesData: Codable, Equatable, Sendable {
    public var visibleProviders: [AIProviderKind]
    public var menuBarProviders: [AIProviderKind]
    public var menuBarStyle: MenuBarDisplayStyle
    public var quotaDisplayMode: QuotaDisplayMode
    public var summaryWindowMode: SummaryWindowMode
    public var dualWindowLayoutStyle: DualWindowLayoutStyle
    /// Ids de los pools (ver `ModelCatalog`) que cada proveedor muestra en la barra superior.
    public var menuBarPoolsByProvider: [String: [String]]
    public var language: AppLanguage
    public var launchAtLogin: Bool

    public init(
        visibleProviders: [AIProviderKind] = AIProviderKind.allCases,
        menuBarProviders: [AIProviderKind] = AIProviderKind.allCases,
        menuBarStyle: MenuBarDisplayStyle = .logosAndPercentages,
        quotaDisplayMode: QuotaDisplayMode = .remaining,
        summaryWindowMode: SummaryWindowMode = .weeklyOnly,
        dualWindowLayoutStyle: DualWindowLayoutStyle = .stackedTwoLines,
        menuBarPoolsByProvider: [String: [String]] = [:],
        language: AppLanguage = .es,
        launchAtLogin: Bool = false
    ) {
        self.visibleProviders = visibleProviders
        self.menuBarProviders = menuBarProviders
        self.menuBarStyle = menuBarStyle
        self.quotaDisplayMode = quotaDisplayMode
        self.summaryWindowMode = summaryWindowMode
        self.dualWindowLayoutStyle = dualWindowLayoutStyle
        self.menuBarPoolsByProvider = menuBarPoolsByProvider
        self.language = language
        self.launchAtLogin = launchAtLogin
    }

    enum CodingKeys: String, CodingKey {
        case visibleProviders, menuBarProviders, menuBarStyle, quotaDisplayMode
        case summaryWindowMode, dualWindowLayoutStyle, menuBarPoolsByProvider
        case language, launchAtLogin
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case preferredPoolByProvider
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.visibleProviders = try container.decodeIfPresent([AIProviderKind].self, forKey: .visibleProviders) ?? AIProviderKind.allCases
        self.menuBarProviders = try container.decodeIfPresent([AIProviderKind].self, forKey: .menuBarProviders) ?? AIProviderKind.allCases
        self.menuBarStyle = try container.decodeIfPresent(MenuBarDisplayStyle.self, forKey: .menuBarStyle) ?? .logosAndPercentages
        self.quotaDisplayMode = try container.decodeIfPresent(QuotaDisplayMode.self, forKey: .quotaDisplayMode) ?? .remaining
        // Valores guardados por versiones anteriores, cuando la ventana de 5h era la principal.
        let legacyValues = [
            "fiveHourOnly": "weeklyOnly",
            "fiveHourAndSevenDay": "weeklyAndBurst",
            "parentheses7d": "parentheses5h"
        ]
        let rawMode = try container.decodeIfPresent(String.self, forKey: .summaryWindowMode) ?? ""
        self.summaryWindowMode = SummaryWindowMode(rawValue: legacyValues[rawMode] ?? rawMode) ?? .weeklyOnly
        let rawStyle = try container.decodeIfPresent(String.self, forKey: .dualWindowLayoutStyle) ?? ""
        self.dualWindowLayoutStyle = DualWindowLayoutStyle(rawValue: legacyValues[rawStyle] ?? rawStyle) ?? .stackedTwoLines

        if let saved = try container.decodeIfPresent([String: [String]].self, forKey: .menuBarPoolsByProvider) {
            self.menuBarPoolsByProvider = saved
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
                .decodeIfPresent([String: QuotaPoolCategory].self, forKey: .preferredPoolByProvider) ?? [:]
            self.menuBarPoolsByProvider = legacy.reduce(into: [:]) { result, item in
                let match = ModelCatalog.pools.first { $0.provider.rawValue == item.key && $0.category == item.value }
                if let match { result[item.key] = [match.id] }
            }
        }
        self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .es
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    }

    /// Ids de los pools elegidos para la barra superior, en el orden del catálogo (por defecto, el Pool General).
    public func menuBarPoolIds(for provider: AIProviderKind) -> [String] {
        let catalogIds = ModelCatalog.pools(for: provider).map(\.id)
        let saved = menuBarPoolsByProvider[provider.rawValue] ?? []
        let selected = catalogIds.filter(saved.contains)
        return selected.isEmpty ? Array(catalogIds.prefix(1)) : selected
    }

    /// Pools del snapshot que se muestran en la barra superior (si ninguno de los elegidos existe, el primero disponible).
    public func menuBarPools(for snapshot: ProviderQuotaSnapshot) -> [QuotaPoolGroup] {
        let allPools = snapshot.pools
        let ids = menuBarPoolIds(for: snapshot.provider)
        let selected = allPools.filter { ids.contains($0.id) }
        return selected.isEmpty ? Array(allPools.prefix(1)) : selected
    }

    /// Devuelve un resumen estructurado por cada pool elegido del proveedor (5h antes de 7d cuando se muestran ambas).
    public func summaryTokens(for snapshot: ProviderQuotaSnapshot, compactMenuBar: Bool = true) -> [ProviderSummaryTokens] {
        guard snapshot.authState == .authenticated else { return [] }
        let pools = menuBarPools(for: snapshot)
        return pools.compactMap { pool in
            guard let primary = pool.primaryMetric else { return nil }
            let tag = pools.count > 1 ? ModelCatalog.pool(id: pool.id)?.menuBarTag : nil
            let burst = pool.effective5hMetric
            let weekly = pool.weekly7dMetric
            let isShared = pool.sharingArchitecture == .shared5hAndScopedWeekly
            let burstDetail: String? = isShared ? L10n.shared5hNote(language)
                : (pool.sharingArchitecture == .independentWeeklyOnly ? L10n.unlimited5h(language) : nil)

            if summaryWindowMode == .weeklyAndBurst {
                let wStr = weekly.map { quotaDisplayMode.formatMenuBarPercent(remainingPercent: $0.remainingPercent) } ?? "—"
                let bStr = burst.map { quotaDisplayMode.formatMenuBarPercent(remainingPercent: $0.remainingPercent) }
                    ?? (pool.sharingArchitecture == .independentWeeklyOnly ? "∞" : "—")
                let link = isShared ? "↗" : ""
                let formatted: String
                switch dualWindowLayoutStyle {
                case .stackedTwoLines, .inlineDot, .capsulePills:
                    formatted = "\(bStr) 5h\(link) · \(wStr) 7d"
                case .parentheses5h:
                    formatted = "\(bStr)\(link) (\(wStr) 7d)"
                case .subscripts:
                    formatted = "\(bStr)₅ₕ\(link) \(wStr)₇𝒹"
                }
                return ProviderSummaryTokens(
                    provider: snapshot.provider,
                    poolId: pool.id,
                    tag: tag,
                    weekly7dText: wStr,
                    weekly7dRemaining: weekly?.remainingPercent,
                    burst5hText: bStr,
                    burst5hRemaining: burst?.remainingPercent,
                    burst5hIsShared: isShared,
                    burst5hDetail: burstDetail,
                    singleText: formatted,
                    statusRemainingPercent: [weekly?.remainingPercent, burst?.remainingPercent].compactMap { $0 }.min() ?? primary.remainingPercent
                )
            }

            let text = compactMenuBar
                ? quotaDisplayMode.formatMenuBarPercent(remainingPercent: primary.remainingPercent)
                : quotaDisplayMode.format(metric: primary, compact: true, language: language)
            let isWeekly = primary.windowKind == .weekly7d
            let percent = quotaDisplayMode.formatMenuBarPercent(remainingPercent: primary.remainingPercent)
            return ProviderSummaryTokens(
                provider: snapshot.provider,
                poolId: pool.id,
                tag: tag,
                weekly7dText: isWeekly ? percent : nil,
                weekly7dRemaining: isWeekly ? primary.remainingPercent : nil,
                burst5hText: isWeekly ? nil : percent,
                burst5hRemaining: isWeekly ? nil : primary.remainingPercent,
                burst5hIsShared: isShared,
                burst5hDetail: burstDetail,
                singleText: text,
                statusRemainingPercent: primary.remainingPercent
            )
        }
    }

    /// Texto resumen de un proveedor con todos sus pools elegidos, más el menor porcentaje disponible entre ellos.
    public func formatProviderSummary(
        snapshot: ProviderQuotaSnapshot,
        compactMenuBar: Bool
    ) -> (text: String, statusRemainingPercent: Double)? {
        let tokens = summaryTokens(for: snapshot, compactMenuBar: compactMenuBar)
        guard let lowest = tokens.map(\.statusRemainingPercent).min() else { return nil }
        return (tokens.map(\.taggedText).joined(separator: " "), lowest)
    }
}

@MainActor
public final class PreferencesStore: ObservableObject {
    public static let shared = PreferencesStore()

    @Published public var data: QuotaPreferencesData {
        didSet {
            save()
        }
    }

    private nonisolated static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("AIQuota", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("preferences.json")
    }

    private nonisolated static var widgetContainerFileURL: URL {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let dir = home.appendingPathComponent(
            "Library/Containers/com.lhbelfanti.AIQuota.WidgetExtension/Data/Library/Application Support/AIQuota",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("preferences.json")
    }

    public init() {
        var loaded = Self.loadFromDisk() ?? QuotaPreferencesData()
        loaded.launchAtLogin = LaunchAtLoginManager.isEnabled()
        self.data = loaded
        self.save()
    }

    public nonisolated static func loadFromDisk() -> QuotaPreferencesData? {
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(QuotaPreferencesData.self, from: raw) {
            return decoded
        }
        if let raw = try? Data(contentsOf: widgetContainerFileURL),
           let decoded = try? JSONDecoder().decode(QuotaPreferencesData.self, from: raw) {
            return decoded
        }
        return nil
    }

    public func isProviderVisible(_ kind: AIProviderKind) -> Bool {
        data.visibleProviders.contains(kind)
    }

    public func setProviderVisible(_ kind: AIProviderKind, visible: Bool) {
        var list = data.visibleProviders
        if visible {
            if !list.contains(kind) {
                list.append(kind)
            }
        } else if list.count > 1 {
            list.removeAll { $0 == kind }
        }
        data.visibleProviders = AIProviderKind.allCases.filter { list.contains($0) }
    }

    public func isMenuBarProviderEnabled(_ kind: AIProviderKind) -> Bool {
        data.menuBarProviders.contains(kind)
    }

    public func setMenuBarProviderEnabled(_ kind: AIProviderKind, enabled: Bool) {
        var list = data.menuBarProviders
        if enabled {
            if !list.contains(kind) {
                list.append(kind)
            }
        } else {
            list.removeAll { $0 == kind }
        }
        data.menuBarProviders = AIProviderKind.allCases.filter { list.contains($0) }
    }

    public func isMenuBarPoolSelected(_ poolId: String, for provider: AIProviderKind) -> Bool {
        data.menuBarPoolIds(for: provider).contains(poolId)
    }

    public func setMenuBarPool(_ poolId: String, for provider: AIProviderKind, selected: Bool) {
        var ids = data.menuBarPoolIds(for: provider)
        if selected {
            ids.append(poolId)
        } else if ids.count > 1 {
            ids.removeAll { $0 == poolId }
        }
        data.menuBarPoolsByProvider[provider.rawValue] = ids
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLoginManager.setEnabled(enabled)
        data.launchAtLogin = LaunchAtLoginManager.isEnabled()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let encoded = try? encoder.encode(data) {
            try? encoded.write(to: Self.fileURL, options: .atomic)
            let widgetURL = Self.widgetContainerFileURL
            if widgetURL.path != Self.fileURL.path {
                try? encoded.write(to: widgetURL, options: .atomic)
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

public enum LaunchAtLoginManager {
    public static let agentLabel = "com.lhbelfanti.AIQuota"

    public static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }

    public static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    public static func setEnabled(_ enabled: Bool) {
        let fm = FileManager.default
        if enabled {
            let launchAgentsDir = plistURL.deletingLastPathComponent()
            try? fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

            let executablePath = resolveAppExecutablePath()
            let plistDict: [String: Any] = [
                "Label": agentLabel,
                "ProgramArguments": [executablePath],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Interactive"
            ]
            if let data = try? PropertyListSerialization.data(
                fromPropertyList: plistDict,
                format: .xml,
                options: 0
            ) {
                try? data.write(to: plistURL, options: .atomic)
            }
        } else {
            try? fm.removeItem(at: plistURL)
        }
    }

    private static func resolveAppExecutablePath() -> String {
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.hasSuffix(".app"),
           let execPath = Bundle.main.executablePath {
            return execPath
        }
        return CommandLine.arguments.first ?? "/Applications/AIQuota.app/Contents/MacOS/AIQuotaApp"
    }
}
