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
public enum QuotaPoolCategory: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    /// Pool principal/general de la cuenta (ej. General en Claude/Codex, Gemini Hydrogen/Flash/Pro en AGY).
    case core = "core"
    /// Pool exclusivo o de modelo dedicado con presupuesto propio (ej. Argon en AGY, Fable/Opus en Claude).
    case dedicated = "dedicated"
    /// Pool de modelos de terceros incluidos en la suscripción (ej. Claude 5.5 & GPT-OSS en AGY).
    case partner = "partner"

    public var id: String { rawValue }

    /// Orden estricto de visualización: 1° Pool General, 2° Pool Exclusivo, 3° Pool de Partners.
    public var sortOrder: Int {
        switch self {
        case .core: return 0
        case .dedicated: return 1
        case .partner: return 2
        }
    }
}

/// Modo de arquitectura de cuota de un Pool (cómo interactúan su ventana 5h y su cuota 7d con el resto de la cuenta).
public enum PoolSharingArchitecture: String, Codable, Equatable, Sendable {
    /// Pool estándar con su propia ventana 5h y su propio presupuesto semanal 7d.
    case standardDual = "standardDual"
    /// Sub-límite semanal dentro del Pool General (ej. Claude Fable: tope del 50% del semanal general y comparte la ventana de 5h del Pool General).
    case shared5hAndScopedWeekly = "shared5hAndScopedWeekly"
    /// Pool semanal 100% independiente sin límite de ráfaga de 5h (ej. Gemini 4 Argon en planes AI Pro).
    case independentWeeklyOnly = "independentWeeklyOnly"
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
    /// Si es un sub-límite semanal (ej. Claude Fable), porcentaje máximo permitido del presupuesto semanal total (ej. 50%).
    public let weeklyAllowancePercentOfGeneral: Double?
    /// Si es un sub-límite semanal (ej. Claude Fable), porcentaje ya consumido respecto del presupuesto semanal total (ej. 4%).
    public let weeklyUsedPercentOfGeneral: Double?

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
        windowKind: QuotaWindowKind? = nil,
        weeklyAllowancePercentOfGeneral: Double? = nil,
        weeklyUsedPercentOfGeneral: Double? = nil
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
        self.weeklyAllowancePercentOfGeneral = weeklyAllowancePercentOfGeneral
        self.weeklyUsedPercentOfGeneral = weeklyUsedPercentOfGeneral
    }

    enum CodingKeys: String, CodingKey {
        case id, label, usedPercent, remainingPercent, resetsAt, detail
        case poolId, poolTitle, poolSubtitle, poolCategory, windowKind
        case weeklyAllowancePercentOfGeneral, weeklyUsedPercentOfGeneral
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
        let weeklyAllowancePercentOfGeneral = try container.decodeIfPresent(Double.self, forKey: .weeklyAllowancePercentOfGeneral)
        let weeklyUsedPercentOfGeneral = try container.decodeIfPresent(Double.self, forKey: .weeklyUsedPercentOfGeneral)

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
            windowKind: windowKind,
            weeklyAllowancePercentOfGeneral: weeklyAllowancePercentOfGeneral,
            weeklyUsedPercentOfGeneral: weeklyUsedPercentOfGeneral
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
                return ("claude-general", "Pool General", "Claude Sonnet · Haiku · Opus base", .core, winKind)
            }
            let cleanName = label
                .replacingOccurrences(of: " (7d)", with: "")
                .replacingOccurrences(of: " (5h)", with: "")
            return ("claude-\(cleanName.lowercased())", "Pool Exclusivo", "Claude \(cleanName)", .dedicated, winKind)
        }

        // Codex pools
        if lowerId.hasPrefix("codex-") {
            if lowerId == "codex-review" {
                return ("codex-review", "Pool Exclusivo", "Code Review (PRs)", .dedicated, winKind)
            }
            return ("codex-general", "Pool General", "GPT-5 · o3 · Codex CLI", .core, winKind)
        }

        // Gemini / Antigravity pools
        if lowerId.contains("argon") || lowerLabel.contains("argon") {
            return ("agy-argon", "Pool Exclusivo", "Gemini 4 Argon (Low / Med / High) · Orchestrator", .dedicated, winKind)
        }
        if lowerId.contains("3p") || lowerLabel.contains("claude") || lowerLabel.contains("gpt-oss") {
            return ("agy-3p", "Pool de Partners", "Claude Opus 5.5 · Claude Sonnet 5.5 · GPT-OSS 120B", .partner, winKind)
        }
        if lowerId.hasPrefix("agy-") {
            return ("agy-gemini", "Pool General", "Gemini 4 Hydrogen · Gemini 3.8 Flash · Gemini 2.5 Pro", .core, winKind)
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
    /// Si este pool no tiene su propio tanque de 5h pero comparte la ventana de 5h del Pool General (ej. Claude Fable), contiene esa métrica 5h compartida.
    public let sharedBurst5hMetric: QuotaMetric?
    /// Arquitectura de compartición/independencia del pool.
    public let sharingArchitecture: PoolSharingArchitecture

    public init(
        id: String,
        title: String,
        subtitle: String?,
        category: QuotaPoolCategory,
        burst5hMetric: QuotaMetric?,
        weekly7dMetric: QuotaMetric?,
        otherMetrics: [QuotaMetric] = [],
        sharedBurst5hMetric: QuotaMetric? = nil,
        sharingArchitecture: PoolSharingArchitecture = .standardDual
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.burst5hMetric = burst5hMetric
        self.weekly7dMetric = weekly7dMetric
        self.otherMetrics = otherMetrics
        self.sharedBurst5hMetric = sharedBurst5hMetric
        self.sharingArchitecture = sharingArchitecture
    }

    /// Métrica de 5h efectiva (propia o compartida con el Pool General en el caso de Fable).
    public var effective5hMetric: QuotaMetric? {
        burst5hMetric ?? sharedBurst5hMetric
    }

    /// Métrica principal del pool (prioriza 5h propia si existe, o 7d en pools semanales como Argon/Fable).
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

    /// Agrupa las métricas del proveedor en sus respectivos Pools, ordenados siempre como:
    /// 1° Pool General (.core), 2° Pool Exclusivo (.dedicated), 3° Pool de Partners (.partner).
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

        // Identificar la ventana de 5h del Pool General (.core) por si un pool dedicado comparte esa ventana (ej. Claude Fable)
        let coreBurst5h = metrics.first(where: { $0.poolCategory == .core && $0.windowKind == .burst5h })

        let rawPools: [QuotaPoolGroup] = orderedPoolIds.compactMap { pid in
            guard let items = grouped[pid], let first = items.first else { return nil }
            let burst = items.first(where: { $0.windowKind == .burst5h })
            let weekly = items.first(where: { $0.windowKind == .weekly7d })
            let others = items.filter { $0.windowKind == .custom }
            let subtitle = items.compactMap(\.poolSubtitle).first ?? first.detail

            let architecture: PoolSharingArchitecture
            let shared5h: QuotaMetric?
            if burst == nil && weekly != nil {
                if provider == .claude && first.poolCategory == .dedicated {
                    architecture = .shared5hAndScopedWeekly
                    shared5h = coreBurst5h
                } else {
                    architecture = .independentWeeklyOnly
                    shared5h = nil
                }
            } else {
                architecture = .standardDual
                shared5h = nil
            }

            return QuotaPoolGroup(
                id: pid,
                title: first.poolTitle,
                subtitle: subtitle,
                category: first.poolCategory,
                burst5hMetric: burst,
                weekly7dMetric: weekly,
                otherMetrics: others,
                sharedBurst5hMetric: shared5h,
                sharingArchitecture: architecture
            )
        }

        return rawPools.enumerated().sorted { lhs, rhs in
            if lhs.element.category.sortOrder != rhs.element.category.sortOrder {
                return lhs.element.category.sortOrder < rhs.element.category.sortOrder
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// Devuelve el pool correspondiente a la categoría elegida por el usuario (o el Pool General / primero disponible como fallback).
    public func pool(for preferredCategory: QuotaPoolCategory) -> QuotaPoolGroup? {
        let allPools = pools
        if let exact = allPools.first(where: { $0.category == preferredCategory }) {
            return exact
        }
        return allPools.first
    }

    /// Primary remaining percentage across the most restrictive or primary window
    public var primaryRemainingPercent: Double? {
        guard authState == .authenticated, !metrics.isEmpty else { return nil }
        return pools.first?.primaryMetric?.remainingPercent ?? metrics.first?.remainingPercent
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
