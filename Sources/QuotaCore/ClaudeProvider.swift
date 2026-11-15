import Foundation

public struct ClaudeProviderClient: Sendable {
    public init() {}

    private struct KeychainPayload: Decodable {
        struct OAuthData: Decodable {
            let accessToken: String?
            let refreshToken: String?
            let expiresAt: Double?
            let subscriptionType: String?
            let rateLimitTier: String?
        }
        let claudeAiOauth: OAuthData?
    }

    private struct ClaudeConfigFile: Decodable {
        struct OAuthAccount: Decodable {
            let emailAddress: String?
            let organizationName: String?
            let billingType: String?
        }
        let oauthAccount: OAuthAccount?
    }

    public struct UsageResponse: Decodable, Sendable {
        public struct WindowUsage: Decodable, Sendable {
            public let utilization: Double?
            public let resets_at: String?
        }
        public struct LimitEntry: Decodable, Sendable {
            public let kind: String?
            public let group: String?
            public let percent: Double?
            public let resets_at: String?
            public let ScopeModel: ScopeInfo?

            public struct ScopeInfo: Decodable, Sendable {
                public struct ModelInfo: Decodable, Sendable {
                    public let id: String?
                    public let display_name: String?
                }
                public let model: ModelInfo?
            }

            enum CodingKeys: String, CodingKey {
                case kind
                case group
                case percent
                case resets_at
                case ScopeModel = "scope"
            }
        }
        public struct WeeklyScopedShare: Decodable, Sendable {
            public let limit_index: Int?
            public let used_percent_of_weekly: Double?
            public let allowance_percent_of_weekly: Double?
        }
        public struct ExtraUsage: Decodable, Sendable {
            public let is_enabled: Bool?
            public let monthly_limit: Double?
            public let used_credits: Double?
            public let utilization: Double?
            public let currency: String?
        }

        public let five_hour: WindowUsage?
        public let seven_day: WindowUsage?
        public let seven_day_opus: WindowUsage?
        public let seven_day_sonnet: WindowUsage?
        public let limits: [LimitEntry]?
        public let weekly_scoped_shares: [WeeklyScopedShare]?
        public let extra_usage: ExtraUsage?
    }

    public func fetchSnapshot() async -> ProviderQuotaSnapshot {
        let accountMetadata = readLocalAccountMetadata()
        guard let credentials = readCredentials(), let token = credentials.accessToken, !token.isEmpty else {
            return ProviderQuotaSnapshot(
                provider: .claude,
                authState: .unauthenticated,
                accountLabel: accountMetadata.email,
                planTier: accountMetadata.plan
            )
        }

        do {
            let usage = try await fetchUsage(accessToken: token)
            let metrics = Self.parseMetrics(from: usage)
            var extraInfo: String? = nil
            if let extra = usage.extra_usage, extra.is_enabled == true,
               let used = extra.used_credits, let limit = extra.monthly_limit {
                extraInfo = String(format: "Uso extra: $%.2f / $%.2f", used / 100.0, limit / 100.0)
            }

            return ProviderQuotaSnapshot(
                provider: .claude,
                authState: .authenticated,
                accountLabel: accountMetadata.email ?? "Sesión activa",
                planTier: (credentials.subscriptionType ?? accountMetadata.plan)?.uppercased(),
                metrics: metrics,
                extraInfo: extraInfo
            )
        } catch let error as QuotaFetchError {
            if case .unauthorized = error {
                return ProviderQuotaSnapshot(
                    provider: .claude,
                    authState: .expired,
                    accountLabel: accountMetadata.email,
                    planTier: credentials.subscriptionType?.uppercased(),
                    errorMessage: "Sesión expirada. Volvé a iniciar sesión."
                )
            }
            return ProviderQuotaSnapshot(
                provider: .claude,
                authState: .error,
                accountLabel: accountMetadata.email,
                planTier: credentials.subscriptionType?.uppercased(),
                errorMessage: error.localizedDescription
            )
        } catch {
            return ProviderQuotaSnapshot(
                provider: .claude,
                authState: .error,
                accountLabel: accountMetadata.email,
                planTier: credentials.subscriptionType?.uppercased(),
                errorMessage: error.localizedDescription
            )
        }
    }

    public static func parseMetrics(from usage: UsageResponse) -> [QuotaMetric] {
        var metrics: [QuotaMetric] = []

        if let fiveHour = usage.five_hour, let util = fiveHour.utilization {
            metrics.append(
                QuotaMetric(
                    id: "claude-5h",
                    label: "Sesión (5h)",
                    usedPercent: util,
                    resetsAt: parseISO8601(fiveHour.resets_at),
                    poolId: "claude-general",
                    poolTitle: "Pool General",
                    poolSubtitle: "Claude Sonnet · Haiku · Opus base",
                    poolCategory: .core,
                    windowKind: .burst5h
                )
            )
        }

        if let sevenDay = usage.seven_day, let util = sevenDay.utilization {
            metrics.append(
                QuotaMetric(
                    id: "claude-7d",
                    label: "Semanal (7d)",
                    usedPercent: util,
                    resetsAt: parseISO8601(sevenDay.resets_at),
                    poolId: "claude-general",
                    poolTitle: "Pool General",
                    poolSubtitle: "Claude Sonnet · Haiku · Opus base",
                    poolCategory: .core,
                    windowKind: .weekly7d
                )
            )
        }

        if let opus = usage.seven_day_opus, let util = opus.utilization {
            metrics.append(
                QuotaMetric(
                    id: "claude-opus-7d",
                    label: "Opus (7d)",
                    usedPercent: util,
                    resetsAt: parseISO8601(opus.resets_at),
                    poolId: "claude-opus",
                    poolTitle: "Pool Exclusivo",
                    poolSubtitle: "Claude Opus",
                    poolCategory: .dedicated,
                    windowKind: .weekly7d
                )
            )
        }

        if let sonnet = usage.seven_day_sonnet, let util = sonnet.utilization {
            metrics.append(
                QuotaMetric(
                    id: "claude-sonnet-7d",
                    label: "Sonnet (7d)",
                    usedPercent: util,
                    resetsAt: parseISO8601(sonnet.resets_at),
                    poolId: "claude-sonnet",
                    poolTitle: "Pool Exclusivo",
                    poolSubtitle: "Claude Sonnet",
                    poolCategory: .dedicated,
                    windowKind: .weekly7d
                )
            )
        }

        if let limits = usage.limits {
            let sharesByIndex: [Int: UsageResponse.WeeklyScopedShare] = Dictionary(
                uniqueKeysWithValues: (usage.weekly_scoped_shares ?? []).compactMap { share in
                    guard let idx = share.limit_index else { return nil }
                    return (idx, share)
                }
            )

            for (index, limit) in limits.enumerated() where limit.kind == "weekly_scoped" {
                if let modelName = limit.ScopeModel?.model?.display_name,
                   let pct = limit.percent {
                    let id = "claude-scoped-\(modelName.lowercased())"
                    if !metrics.contains(where: { $0.id == id }) {
                        let share = sharesByIndex[index]
                        let allowancePct = share?.allowance_percent_of_weekly ?? 50.0
                        let usedOfWeeklyPct = share?.used_percent_of_weekly
                        metrics.append(
                            QuotaMetric(
                                id: id,
                                label: "\(modelName) (7d)",
                                usedPercent: pct,
                                resetsAt: parseISO8601(limit.resets_at),
                                poolId: "claude-\(modelName.lowercased())",
                                poolTitle: "Pool Exclusivo",
                                poolSubtitle: "Claude \(modelName)",
                                poolCategory: .dedicated,
                                windowKind: .weekly7d,
                                weeklyAllowancePercentOfGeneral: allowancePct,
                                weeklyUsedPercentOfGeneral: usedOfWeeklyPct
                            )
                        )
                    }
                }
            }
        }

        return metrics
    }

    private func fetchUsage(accessToken: String) async throws -> UsageResponse {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            throw QuotaFetchError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.1.0", forHTTPHeaderField: "User-Agent")

        return try await QuotaHTTPClient.sendJSON(request, as: UsageResponse.self)
    }

    private func readCredentials() -> KeychainPayload.OAuthData? {
        if let raw = KeychainHelper.readGenericPassword(service: "Claude Code-credentials"),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(KeychainPayload.self, from: data),
           let oauth = decoded.claudeAiOauth {
            return oauth
        }

        // Fallback: ~/.claude/.credentials.json
        let fallbackURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: fallbackURL),
           let decoded = try? JSONDecoder().decode(KeychainPayload.self, from: data) {
            return decoded.claudeAiOauth
        }

        return nil
    }

    private func readLocalAccountMetadata() -> (email: String?, plan: String?) {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json")
        if let data = try? Data(contentsOf: configURL),
           let decoded = try? JSONDecoder().decode(ClaudeConfigFile.self, from: data),
           let account = decoded.oauthAccount {
            return (account.emailAddress, account.billingType)
        }
        return (nil, nil)
    }

    private static func parseISO8601(_ raw: String?) -> Date? {
        QuotaDateUtils.parseISO8601(raw)
    }
}

public enum QuotaDateUtils {
    public static func parseISO8601(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFractional.date(from: raw) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}

public enum QuotaHTTPClient {
    public static func sendJSON<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw QuotaFetchError.invalidResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw QuotaFetchError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            throw QuotaFetchError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

public enum QuotaFetchError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpStatus(Int)
    case custom(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL de consulta inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .unauthorized:
            return "No autorizado o sesión expirada"
        case .httpStatus(let code):
            return "Error HTTP \(code)"
        case .custom(let message):
            return message
        }
    }
}
