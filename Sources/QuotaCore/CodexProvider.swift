import Foundation

public struct CodexProviderClient: Sendable {
    public init() {}

    public struct AuthFile: Decodable, Sendable {
        public struct Tokens: Decodable, Sendable {
            public let access_token: String?
            public let account_id: String?
            public let id_token: String?
            public let refresh_token: String?
        }
        public let auth_mode: String?
        public let OPENAI_API_KEY: String?
        public let tokens: Tokens?
    }

    public struct WhamUsageResponse: Decodable, Sendable {
        public struct RateLimit: Decodable, Sendable {
            public struct Window: Decodable, Sendable {
                public let used_percent: Double?
                public let limit_window_seconds: Int?
                public let reset_after_seconds: Int?
                public let reset_at: Double?
            }
            public let allowed: Bool?
            public let limit_reached: Bool?
            public let primary_window: Window?
            public let secondary_window: Window?
        }
        public struct Credits: Decodable, Sendable {
            public let has_credits: Bool?
            public let unlimited: Bool?
            public let balance: String?
        }
        public struct ResetCredits: Decodable, Sendable {
            public let available_count: Int?
        }

        public let plan_type: String?
        public let rate_limit: RateLimit?
        public let code_review_rate_limit: RateLimit?
        public let credits: Credits?
        public let rate_limit_reset_credits: ResetCredits?
    }

    public func fetchSnapshot() async -> ProviderQuotaSnapshot {
        guard let auth = readAuthFile(),
              let token = auth.tokens?.access_token,
              !token.isEmpty else {
            return ProviderQuotaSnapshot(
                provider: .codex,
                authState: .unauthenticated
            )
        }

        let email = Self.extractEmailFromJWT(auth.tokens?.id_token)

        do {
            let usage = try await fetchWhamUsage(
                accessToken: token,
                accountId: auth.tokens?.account_id
            )
            let metrics = Self.parseMetrics(from: usage)
            var extraParts: [String] = []
            if let balance = usage.credits?.balance, balance != "0" {
                extraParts.append("Créditos: \(balance)")
            }
            if let resets = usage.rate_limit_reset_credits?.available_count, resets > 0 {
                extraParts.append("Resets disponibles: \(resets)")
            }

            return ProviderQuotaSnapshot(
                provider: .codex,
                authState: .authenticated,
                accountLabel: email ?? "ChatGPT OAuth",
                planTier: usage.plan_type?.uppercased(),
                metrics: metrics,
                extraInfo: extraParts.isEmpty ? nil : extraParts.joined(separator: " • ")
            )
        } catch let error as QuotaFetchError {
            if case .unauthorized = error {
                return ProviderQuotaSnapshot(
                    provider: .codex,
                    authState: .expired,
                    accountLabel: email,
                    errorMessage: "Sesión expirada. Ejecutá login en Codex."
                )
            }
            return ProviderQuotaSnapshot(
                provider: .codex,
                authState: .error,
                accountLabel: email,
                errorMessage: error.localizedDescription
            )
        } catch {
            return ProviderQuotaSnapshot(
                provider: .codex,
                authState: .error,
                accountLabel: email,
                errorMessage: error.localizedDescription
            )
        }
    }

    public static func parseMetrics(from usage: WhamUsageResponse) -> [QuotaMetric] {
        var metrics: [QuotaMetric] = []

        func append(_ window: WhamUsageResponse.RateLimit.Window?, pool: PoolDefinition, id: String, fallback: QuotaWindowKind) {
            guard let window, let used = window.used_percent else { return }
            let kind: QuotaWindowKind
            switch window.limit_window_seconds {
            case 18000: kind = .burst5h
            case 604800: kind = .weekly7d
            case nil: kind = fallback
            default: kind = .custom
            }
            metrics.append(pool.metric(
                id: id,
                window: kind,
                usedPercent: used,
                resetsAt: window.reset_at.map { Date(timeIntervalSince1970: $0) }
            ))
        }

        if let general = ModelCatalog.pool(id: "codex-general") {
            append(usage.rate_limit?.primary_window, pool: general, id: "codex-primary", fallback: .burst5h)
            append(usage.rate_limit?.secondary_window, pool: general, id: "codex-secondary", fallback: .weekly7d)
        }
        if let review = ModelCatalog.pool(id: "codex-review") {
            append(usage.code_review_rate_limit?.primary_window, pool: review, id: "codex-review-primary", fallback: .custom)
            append(usage.code_review_rate_limit?.secondary_window, pool: review, id: "codex-review-secondary", fallback: .custom)
        }
        return metrics
    }

    private func fetchWhamUsage(accessToken: String, accountId: String?) async throws -> WhamUsageResponse {
        guard let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else {
            throw QuotaFetchError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")

        return try await QuotaHTTPClient.sendJSON(request, as: WhamUsageResponse.self)
    }

    private func readAuthFile() -> AuthFile? {
        let authURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: authURL) else { return nil }
        return try? JSONDecoder().decode(AuthFile.self, from: data)
    }

    public static func extractEmailFromJWT(_ jwt: String?) -> String? {
        guard let jwt else { return nil }
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["email"] as? String
    }
}
