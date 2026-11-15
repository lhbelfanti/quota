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
    public var language: AppLanguage
    public var launchAtLogin: Bool

    public init(
        visibleProviders: [AIProviderKind] = AIProviderKind.allCases,
        menuBarProviders: [AIProviderKind] = AIProviderKind.allCases,
        menuBarStyle: MenuBarDisplayStyle = .logosAndPercentages,
        quotaDisplayMode: QuotaDisplayMode = .remaining,
        language: AppLanguage = .es,
        launchAtLogin: Bool = false
    ) {
        self.visibleProviders = visibleProviders
        self.menuBarProviders = menuBarProviders
        self.menuBarStyle = menuBarStyle
        self.quotaDisplayMode = quotaDisplayMode
        self.language = language
        self.launchAtLogin = launchAtLogin
    }

    enum CodingKeys: String, CodingKey {
        case visibleProviders, menuBarProviders, menuBarStyle, quotaDisplayMode, language, launchAtLogin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.visibleProviders = try container.decodeIfPresent([AIProviderKind].self, forKey: .visibleProviders) ?? AIProviderKind.allCases
        self.menuBarProviders = try container.decodeIfPresent([AIProviderKind].self, forKey: .menuBarProviders) ?? AIProviderKind.allCases
        self.menuBarStyle = try container.decodeIfPresent(MenuBarDisplayStyle.self, forKey: .menuBarStyle) ?? .logosAndPercentages
        self.quotaDisplayMode = try container.decodeIfPresent(QuotaDisplayMode.self, forKey: .quotaDisplayMode) ?? .remaining
        self.language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .es
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
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
