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

        if let primary = usage.rate_limit?.primary_window,
           let used = primary.used_percent {
            let label = windowLabel(seconds: primary.limit_window_seconds, fallback: "Ventana 5h")
            let resetDate = primary.reset_at.map { Date(timeIntervalSince1970: $0) }
            metrics.append(
                QuotaMetric(
                    id: "codex-primary",
                    label: label,
                    usedPercent: used,
                    resetsAt: resetDate,
                    poolId: "codex-general",
                    poolTitle: "Pool General",
                    poolSubtitle: "GPT-5 · o3 · Codex CLI",
                    poolCategory: .core,
                    windowKind: .burst5h
                )
            )
        }

        if let secondary = usage.rate_limit?.secondary_window,
           let used = secondary.used_percent {
            let label = windowLabel(seconds: secondary.limit_window_seconds, fallback: "Semanal (7d)")
            let resetDate = secondary.reset_at.map { Date(timeIntervalSince1970: $0) }
            metrics.append(
                QuotaMetric(
                    id: "codex-secondary",
                    label: label,
                    usedPercent: used,
                    resetsAt: resetDate,
                    poolId: "codex-general",
                    poolTitle: "Pool General",
                    poolSubtitle: "GPT-5 · o3 · Codex CLI",
                    poolCategory: .core,
                    windowKind: .weekly7d
                )
            )
        }

        if let reviewPrimary = usage.code_review_rate_limit?.primary_window,
           let used = reviewPrimary.used_percent {
            let resetDate = reviewPrimary.reset_at.map { Date(timeIntervalSince1970: $0) }
            metrics.append(
                QuotaMetric(
                    id: "codex-review",
                    label: "Code Review",
                    usedPercent: used,
                    resetsAt: resetDate,
                    poolId: "codex-review",
                    poolTitle: "Pool Code Review",
                    poolSubtitle: "Revisiones automáticas de PR",
                    poolCategory: .dedicated,
                    windowKind: .burst5h
                )
            )
        }

        return metrics
    }

    private static func windowLabel(seconds: Int?, fallback: String) -> String {
        guard let seconds, seconds > 0 else { return fallback }
        let hours = seconds / 3600
        if hours == 5 { return "Sesión (5h)" }
        if hours == 168 { return "Semanal (7d)" }
        if hours >= 24 {
            return "Ventana (\(hours / 24)d)"
        }
        return "Ventana (\(hours)h)"
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
