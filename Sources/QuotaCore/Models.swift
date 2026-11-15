import Foundation

public enum AIProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case claude = "claude"
    case codex = "codex"
    case gemini = "gemini"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        }
    }

    public var subtitle: String {
        switch self {
        case .claude: return "Anthropic Claude Code"
        case .codex: return "OpenAI Codex / ChatGPT"
        case .gemini: return "Google Gemini / Antigravity (agy)"
        }
    }

    public var symbolName: String {
        switch self {
        case .claude: return "sparkles"
        case .codex: return "terminal.fill"
        case .gemini: return "diamond.fill"
        }
    }

    public var brandColorHex: String {
        switch self {
        case .claude: return "#D97757"
        case .codex: return "#10A37F"
        case .gemini: return "#4E82EE"
        }
    }
}

/// Tipo de ventana de cuota según su alcance temporal y prioridad operativa.
public enum QuotaWindowKind: String, Codable, Equatable, Sendable {
    /// Ventana de ráfaga o sesión inmediata (5 horas) — prioridad primaria en tiempo real.
    case burst5h = "burst5h"
    /// Presupuesto acumulado semanal (7 días) — horizonte de largo plazo.
    case weekly7d = "weekly7d"
    /// Otra ventana especial (ej. Code Review o créditos adicionales).
    case custom = "custom"
}

/// Categoría del Pool de modelos para diferenciar el pool base de pools dedicados/exclusivos.
public enum QuotaPoolCategory: String, Codable, Equatable, Sendable {
    /// Pool principal/general de la cuenta (ej. General en Claude/Codex, Gemini Hydrogen/Flash/Pro en AGY).
    case core = "core"
    /// Pool exclusivo o de modelo dedicado con presupuesto propio (ej. Argon en AGY, Fable/Opus en Claude).
    case dedicated = "dedicated"
    /// Pool de modelos de terceros incluidos en la suscripción (ej. Claude 5.5 & GPT-OSS en AGY).
    case partner = "partner"
}

public struct QuotaMetric: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let usedPercent: Double
    public let remainingPercent: Double
    public let resetsAt: Date?
    public let detail: String?
    public let poolId: String
    public let poolTitle: String
    public let poolSubtitle: String?
    public let poolCategory: QuotaPoolCategory
    public let windowKind: QuotaWindowKind

    public init(
        id: String,
        label: String,
        usedPercent: Double,
        resetsAt: Date? = nil,
        detail: String? = nil,
        poolId: String? = nil,
        poolTitle: String? = nil,
        poolSubtitle: String? = nil,
        poolCategory: QuotaPoolCategory? = nil,
        windowKind: QuotaWindowKind? = nil
    ) {
        self.id = id
        self.label = label
        let clampedUsed = min(max(usedPercent, 0.0), 100.0)
        self.usedPercent = clampedUsed
        self.remainingPercent = max(0.0, 100.0 - clampedUsed)
        self.resetsAt = resetsAt
        self.detail = detail

        let inferred = Self.inferPoolAndWindow(id: id, label: label, detail: detail)
        self.poolId = poolId ?? inferred.poolId
        self.poolTitle = poolTitle ?? inferred.poolTitle
        self.poolSubtitle = poolSubtitle ?? inferred.poolSubtitle
        self.poolCategory = poolCategory ?? inferred.poolCategory
        self.windowKind = windowKind ?? inferred.windowKind
    }

    enum CodingKeys: String, CodingKey {
        case id, label, usedPercent, remainingPercent, resetsAt, detail
        case poolId, poolTitle, poolSubtitle, poolCategory, windowKind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let label = try container.decode(String.self, forKey: .label)
        let usedPercent = try container.decode(Double.self, forKey: .usedPercent)
        let resetsAt = try container.decodeIfPresent(Date.self, forKey: .resetsAt)
        let detail = try container.decodeIfPresent(String.self, forKey: .detail)

        let inferred = Self.inferPoolAndWindow(id: id, label: label, detail: detail)
        let poolId = try container.decodeIfPresent(String.self, forKey: .poolId) ?? inferred.poolId
        let poolTitle = try container.decodeIfPresent(String.self, forKey: .poolTitle) ?? inferred.poolTitle
        let poolSubtitle = try container.decodeIfPresent(String.self, forKey: .poolSubtitle) ?? inferred.poolSubtitle
        let poolCategory = try container.decodeIfPresent(QuotaPoolCategory.self, forKey: .poolCategory) ?? inferred.poolCategory
        let windowKind = try container.decodeIfPresent(QuotaWindowKind.self, forKey: .windowKind) ?? inferred.windowKind

        self.init(
            id: id,
            label: label,
            usedPercent: usedPercent,
            resetsAt: resetsAt,
            detail: detail,
            poolId: poolId,
            poolTitle: poolTitle,
            poolSubtitle: poolSubtitle,
            poolCategory: poolCategory,
            windowKind: windowKind
        )
    }

    private static func inferPoolAndWindow(
        id: String,
        label: String,
        detail: String?
    ) -> (poolId: String, poolTitle: String, poolSubtitle: String?, poolCategory: QuotaPoolCategory, windowKind: QuotaWindowKind) {
        let lowerId = id.lowercased()
        let lowerLabel = label.lowercased()

        let winKind: QuotaWindowKind
        if lowerId.contains("5h") || lowerId.contains("primary") || lowerLabel.contains("5h") {
            winKind = .burst5h
        } else if lowerId.contains("7d") || lowerId.contains("weekly") || lowerId.contains("secondary") || lowerLabel.contains("7d") || lowerLabel.contains("semanal") {
            winKind = .weekly7d
        } else {
            winKind = .custom
        }

        // Claude pools
        if lowerId.hasPrefix("claude-") {
            if lowerId == "claude-5h" || lowerId == "claude-7d" {
                return ("claude-general", "Pool General", "Sonnet · Haiku · Opus base", .core, winKind)
            }
            let cleanName = label
                .replacingOccurrences(of: " (7d)", with: "")
                .replacingOccurrences(of: " (5h)", with: "")
            return ("claude-\(cleanName.lowercased())", "Pool \(cleanName)", "Cuota semanal dedicada de \(cleanName)", .dedicated, winKind)
        }

        // Codex pools
        if lowerId.hasPrefix("codex-") {
            if lowerId == "codex-review" {
                return ("codex-review", "Pool Code Review", "Revisiones automáticas de PR", .dedicated, winKind)
            }
            return ("codex-general", "Pool General", "GPT-5 · o3 · Codex CLI", .core, winKind)
        }

        // Gemini / Antigravity pools
        if lowerId.contains("argon") || lowerLabel.contains("argon") {
            return ("agy-argon", "Pool Gemini 4 Argon", "Argon (Low / Med / High) · Orchestrator", .dedicated, winKind)
        }
        if lowerId.contains("3p") || lowerLabel.contains("claude") || lowerLabel.contains("gpt-oss") {
            return ("agy-3p", "Pool Claude 5.5 & GPT-OSS 120B", "Claude Opus 5.5 · Sonnet 5.5 · GPT-OSS 120B", .partner, winKind)
        }
        if lowerId.hasPrefix("agy-") {
            return ("agy-gemini", "Pool General", "Gemini 4 Hydrogen · 3.8 Flash · 2.5 Pro", .core, winKind)
        }

        return ("default-\(id)", label, detail, .core, winKind)
    }

    public func formattedResetCountdown(relativeTo now: Date = Date()) -> String? {
        guard let resetsAt else { return nil }
        let diff = Int(resetsAt.timeIntervalSince(now))
        if diff <= 0 { return "ahora" }
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let minutes = (diff % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Agrupación lógica de un Pool de cuota (ej. un Pool puede tener su ventana de ráfaga 5h y su presupuesto semanal 7d).
public struct QuotaPoolGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let category: QuotaPoolCategory
    public let burst5hMetric: QuotaMetric?
    public let weekly7dMetric: QuotaMetric?
    public let otherMetrics: [QuotaMetric]

    public init(
        id: String,
        title: String,
        subtitle: String?,
        category: QuotaPoolCategory,
        burst5hMetric: QuotaMetric?,
        weekly7dMetric: QuotaMetric?,
        otherMetrics: [QuotaMetric] = []
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.burst5hMetric = burst5hMetric
        self.weekly7dMetric = weekly7dMetric
        self.otherMetrics = otherMetrics
    }

    /// Métrica principal del pool (prioriza 5h si existe, o 7d en pools exclusivamente semanales como Argon/Fable).
    public var primaryMetric: QuotaMetric? {
        burst5hMetric ?? weekly7dMetric ?? otherMetrics.first
    }
}

public enum ProviderAuthState: String, Codable, Equatable, Sendable {
    case authenticated
    case unauthenticated
    case expired
    case error
}

public struct ProviderQuotaSnapshot: Codable, Identifiable, Equatable, Sendable {
    public let provider: AIProviderKind
    public var id: String { provider.rawValue }
    public let authState: ProviderAuthState
    public let accountLabel: String?
    public let planTier: String?
    public let metrics: [QuotaMetric]
    public let extraInfo: String?
    public let errorMessage: String?
    public let updatedAt: Date

    public init(
        provider: AIProviderKind,
        authState: ProviderAuthState,
        accountLabel: String? = nil,
        planTier: String? = nil,
        metrics: [QuotaMetric] = [],
        extraInfo: String? = nil,
        errorMessage: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.provider = provider
        self.authState = authState
        self.accountLabel = accountLabel
        self.planTier = planTier
        self.metrics = metrics
        self.extraInfo = extraInfo
        self.errorMessage = errorMessage
        self.updatedAt = updatedAt
    }

    /// Agrupa las métricas del proveedor en sus respectivos Pools (preservando el orden de aparición).
    public var pools: [QuotaPoolGroup] {
        var orderedPoolIds: [String] = []
        var grouped: [String: [QuotaMetric]] = [:]

        for metric in metrics {
            if grouped[metric.poolId] == nil {
                orderedPoolIds.append(metric.poolId)
                grouped[metric.poolId] = []
            }
            grouped[metric.poolId]?.append(metric)
        }

        return orderedPoolIds.compactMap { pid in
            guard let items = grouped[pid], let first = items.first else { return nil }
            let burst = items.first(where: { $0.windowKind == .burst5h })
            let weekly = items.first(where: { $0.windowKind == .weekly7d })
            let others = items.filter { $0.windowKind == .custom }
            let subtitle = items.compactMap(\.poolSubtitle).first ?? first.detail
            return QuotaPoolGroup(
                id: pid,
                title: first.poolTitle,
                subtitle: subtitle,
                category: first.poolCategory,
                burst5hMetric: burst,
                weekly7dMetric: weekly,
                otherMetrics: others
            )
        }
    }

    /// Primary remaining percentage across the most restrictive or primary window
    public var primaryRemainingPercent: Double? {
        guard authState == .authenticated, !metrics.isEmpty else { return nil }
        return metrics.first?.remainingPercent
    }

    public var minimumRemainingPercent: Double? {
        guard authState == .authenticated, !metrics.isEmpty else { return nil }
        return metrics.map(\.remainingPercent).min()
    }
}

public struct QuotaDashboardState: Codable, Equatable, Sendable {
    public let snapshots: [ProviderQuotaSnapshot]
    public let lastRefreshedAt: Date

    public init(snapshots: [ProviderQuotaSnapshot], lastRefreshedAt: Date = Date()) {
        self.snapshots = snapshots
        self.lastRefreshedAt = lastRefreshedAt
    }

    public func snapshot(for provider: AIProviderKind) -> ProviderQuotaSnapshot {
        snapshots.first(where: { $0.provider == provider }) ?? ProviderQuotaSnapshot(
            provider: provider,
            authState: .unauthenticated
        )
    }
}
