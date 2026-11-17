import Foundation

/// Definición de un Pool de cuota: qué modelos agrupa y cómo se lo reconoce en las respuestas de cada API.
public struct PoolDefinition: Identifiable, Equatable, Sendable {
    public let id: String
    public let provider: AIProviderKind
    public let category: QuotaPoolCategory
    public let sharingArchitecture: PoolSharingArchitecture
    /// Nombre corto para etiquetas y opciones de configuración.
    public let shortName: String
    /// Modelos que consumen de este pool (se muestran como subtítulo).
    public let models: [String]
    public let scopeDescription: String?
    /// Etiqueta en la barra superior cuando se muestra más de un pool del mismo proveedor (nil = sin etiqueta).
    public let menuBarTag: String?
    /// Textos que identifican al pool en ids, labels o nombres de grupo devueltos por la API.
    public let matchKeywords: [String]
    /// Claves de modelo de la API cuya cuota representa al pool, en orden de preferencia.
    public let apiModelKeys: [String]

    public init(
        id: String,
        provider: AIProviderKind,
        category: QuotaPoolCategory,
        shortName: String,
        models: [String],
        scopeDescription: String? = nil,
        sharingArchitecture: PoolSharingArchitecture = .standardDual,
        menuBarTag: String? = nil,
        matchKeywords: [String] = [],
        apiModelKeys: [String] = []
    ) {
        self.id = id
        self.provider = provider
        self.category = category
        self.sharingArchitecture = sharingArchitecture
        self.shortName = shortName
        self.models = models
        self.scopeDescription = scopeDescription
        self.menuBarTag = menuBarTag
        self.matchKeywords = matchKeywords
        self.apiModelKeys = apiModelKeys
    }

    public var subtitle: String { scopeDescription ?? models.joined(separator: " · ") }

    public func matches(_ text: String) -> Bool {
        let lower = text.lowercased()
        return matchKeywords.contains { lower.contains($0) }
    }

    public func metric(
        id: String,
        window: QuotaWindowKind,
        usedPercent: Double,
        resetsAt: Date? = nil,
        detail: String? = nil,
        weeklyAllowancePercentOfGeneral: Double? = nil,
        weeklyUsedPercentOfGeneral: Double? = nil
    ) -> QuotaMetric {
        let suffix: String
        switch window {
        case .burst5h: suffix = " (5h)"
        case .weekly7d: suffix = " (7d)"
        case .custom: suffix = ""
        }
        return QuotaMetric(
            id: id,
            label: shortName + suffix,
            usedPercent: usedPercent,
            resetsAt: resetsAt,
            detail: detail,
            poolId: self.id,
            poolTitle: L10n.poolCategoryTitle(category, .es),
            poolSubtitle: subtitle,
            poolCategory: category,
            windowKind: window,
            weeklyAllowancePercentOfGeneral: weeklyAllowancePercentOfGeneral,
            weeklyUsedPercentOfGeneral: weeklyUsedPercentOfGeneral
        )
    }
}

/// Única fuente de verdad de pools y modelos. Si un proveedor cambia sus modelos, se edita solo esta lista.
public enum ModelCatalog {
    public static let pools: [PoolDefinition] = [
        // Claude
        PoolDefinition(
            id: "claude-general",
            provider: .claude,
            category: .core,
            shortName: "Sonnet · Haiku · Opus",
            models: ["Claude Sonnet", "Claude Haiku", "Claude Opus (base)"]
        ),
        PoolDefinition(
            id: "claude-fable",
            provider: .claude,
            category: .dedicated,
            shortName: "Fable",
            models: ["Claude Fable"],
            sharingArchitecture: .shared5hAndScopedWeekly,
            menuBarTag: "F"
        ),

        // Codex
        PoolDefinition(
            id: "codex-general",
            provider: .codex,
            category: .core,
            shortName: "Codex",
            models: [],
            scopeDescription: "Shared usage across Codex models"
        ),
        PoolDefinition(
            id: "codex-review",
            provider: .codex,
            category: .dedicated,
            shortName: "Code Review",
            models: [],
            scopeDescription: "GitHub pull request reviews",
            sharingArchitecture: .independentWeeklyOnly,
            menuBarTag: "CR",
            matchKeywords: ["codex-review"]
        ),

        // Gemini / Antigravity
        PoolDefinition(
            id: "agy-gemini",
            provider: .gemini,
            category: .core,
            shortName: "Hydrogen · Flash · Pro",
            models: ["Gemini 4 Hydrogen", "Gemini 3.8 Flash", "Gemini 2.5 Pro"],
            apiModelKeys: [
                "gemini-4-hydrogen-medium",
                "gemini-3.8-flash-high",
                "gemini-2.5-pro",
                "gemini-3-flash",
                "gemini-3.1-flash-lite"
            ]
        ),
        PoolDefinition(
            id: "agy-argon",
            provider: .gemini,
            category: .dedicated,
            shortName: "Gemini 4 Argon · Orchestrator",
            models: ["Gemini 4 Argon (Low / Med / High)", "Orchestrator"],
            sharingArchitecture: .independentWeeklyOnly,
            menuBarTag: "Ar",
            matchKeywords: ["argon", "orchestrator"],
            apiModelKeys: [
                "gemini-4-argon-medium",
                "gemini-4-argon-low",
                "gemini-4-argon-high",
                "gemini-pro-orchestrator-g1-pro"
            ]
        ),
        PoolDefinition(
            id: "agy-3p",
            provider: .gemini,
            category: .partner,
            shortName: "Claude 5.5 · GPT-OSS 120B",
            models: ["Claude Opus 5.5", "Claude Sonnet 5.5", "GPT-OSS 120B"],
            menuBarTag: "3P",
            matchKeywords: ["3p", "claude", "gpt"],
            apiModelKeys: [
                "claude-sonnet-5-5-high",
                "claude-opus-5-5-high",
                "gpt-oss-120b-medium"
            ]
        )
    ]

    public static func pools(for provider: AIProviderKind) -> [PoolDefinition] {
        pools.filter { $0.provider == provider }
    }

    public static func selectablePools(for snapshot: ProviderQuotaSnapshot) -> [PoolDefinition] {
        let definitions = pools(for: snapshot.provider)
        guard snapshot.provider == .codex else { return definitions }
        let reportedIds = Set(snapshot.metrics.map(\.poolId))
        return definitions.filter { $0.category == .core || reportedIds.contains($0.id) }
    }

    public static func pool(id: String) -> PoolDefinition? {
        pools.first { $0.id == id }
    }

    /// Claude informa límites por modelo de forma dinámica: si el modelo no está en el catálogo se arma un pool exclusivo genérico.
    public static func claudeScopedPool(named modelName: String) -> PoolDefinition {
        let id = "claude-\(modelName.lowercased())"
        return pool(id: id) ?? PoolDefinition(
            id: id,
            provider: .claude,
            category: .dedicated,
            shortName: modelName,
            models: ["Claude \(modelName)"],
            sharingArchitecture: .shared5hAndScopedWeekly,
            menuBarTag: String(modelName.prefix(1))
        )
    }
}
