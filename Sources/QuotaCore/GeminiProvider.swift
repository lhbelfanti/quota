import Foundation

public struct GeminiProviderClient: Sendable {
    // Optional OAuth client configuration via environment variables (or read dynamically from local `agy` / `gemini` CLI installations)
    public static var oauthClientID: String? {
        ProcessInfo.processInfo.environment["AIQUOTA_GOOGLE_CLIENT_ID"]
    }
    public static var oauthClientSecret: String? {
        ProcessInfo.processInfo.environment["AIQUOTA_GOOGLE_CLIENT_SECRET"]
    }
    public static let oauthScopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/userinfo.email",
        "https://www.googleapis.com/auth/userinfo.profile"
    ]

    public static let antigravityUserAgent = "antigravity/cli/1.5.8 (aidev_client; os_type=darwin; arch=amd64; cl=1020628950; auth_method=consumer)"
    public static let antigravityBaseURL = "https://daily-cloudcode-pa.googleapis.com/v1internal"
    public static let defaultAntigravityProject = "aicode-consumers"

    public init() {}

    public struct StoredOAuthCreds: Codable, Sendable {
        public var access_token: String?
        public var refresh_token: String?
        public var token_type: String?
        public var scope: String?
        public var expiry_date: Double?
        public var email: String?

        public init(
            access_token: String? = nil,
            refresh_token: String? = nil,
            token_type: String? = nil,
            scope: String? = nil,
            expiry_date: Double? = nil,
            email: String? = nil
        ) {
            self.access_token = access_token
            self.refresh_token = refresh_token
            self.token_type = token_type
            self.scope = scope
            self.expiry_date = expiry_date
            self.email = email
        }
    }

    private struct AntigravityKeyringPayload: Codable {
        struct TokenData: Codable {
            let access_token: String?
            let refresh_token: String?
            let token_type: String?
            let expiry: String?
        }
        let auth_method: String?
        let id_token_email: String?
        let token: TokenData?
    }

    private struct KeychainMCPWrapper: Codable {
        struct TokenObj: Codable {
            let accessToken: String?
            let refreshToken: String?
            let tokenType: String?
            let scope: String?
            let expiresAt: Double?
        }
        let serverName: String?
        let token: TokenObj?
    }

    private struct GoogleAccountsFile: Codable {
        var active: String?
        var old: [String]?
    }

    public struct LoadCodeAssistResponse: Decodable, Sendable {
        public struct Tier: Decodable, Sendable {
            public struct Credit: Decodable, Sendable {
                public let creditType: String?
                public let creditAmount: String?
            }
            public let id: String?
            public let name: String?
            public let availableCredits: [Credit]?
        }
        public let currentTier: Tier?
        public let paidTier: Tier?
        public let cloudaicompanionProject: String?
    }

    public struct FetchAvailableModelsResponse: Decodable, Sendable {
        public struct ModelEntry: Decodable, Sendable {
            public struct QuotaInfo: Decodable, Sendable {
                public let remainingFraction: Double?
                public let resetTime: String?
            }
            public let displayName: String?
            public let quotaInfo: QuotaInfo?
            public let recommended: Bool?
            public let modelProvider: String?
        }
        public let models: [String: ModelEntry]?
    }

    public struct RetrieveUserQuotaResponse: Decodable, Sendable {
        public struct BucketInfo: Decodable, Sendable {
            public let remainingAmount: String?
            public let remainingFraction: Double?
            public let resetTime: String?
            public let tokenType: String?
            public let modelId: String?
        }
        public let buckets: [BucketInfo]?
    }

    public struct RetrieveUserQuotaSummaryResponse: Decodable, Sendable {
        public struct QuotaGroup: Decodable, Sendable {
            public struct SummaryBucket: Decodable, Sendable {
                public let bucketId: String?
                public let displayName: String?
                public let window: String?
                public let resetTime: String?
                public let description: String?
                public let remainingFraction: Double?

                public init(
                    bucketId: String? = nil,
                    displayName: String? = nil,
                    window: String? = nil,
                    resetTime: String? = nil,
                    description: String? = nil,
                    remainingFraction: Double? = nil
                ) {
                    self.bucketId = bucketId
                    self.displayName = displayName
                    self.window = window
                    self.resetTime = resetTime
                    self.description = description
                    self.remainingFraction = remainingFraction
                }
            }
            public let buckets: [SummaryBucket]?
            public let displayName: String?
            public let description: String?

            public init(
                buckets: [SummaryBucket]? = nil,
                displayName: String? = nil,
                description: String? = nil
            ) {
                self.buckets = buckets
                self.displayName = displayName
                self.description = description
            }
        }
        public let groups: [QuotaGroup]?
        public let description: String?

        public init(groups: [QuotaGroup]? = nil, description: String? = nil) {
            self.groups = groups
            self.description = description
        }
    }

    public func fetchSnapshot() async -> ProviderQuotaSnapshot {
        let fallbackEmail = readAccountEmail()
        guard var creds = readCredentials(),
              let rawToken = creds.access_token,
              !rawToken.isEmpty else {
            return ProviderQuotaSnapshot(
                provider: .gemini,
                authState: .unauthenticated,
                accountLabel: fallbackEmail
            )
        }

        let email = creds.email ?? fallbackEmail

        do {
            // Refresh token if expired or expiring within 60s
            let activeToken: String
            if let expiry = creds.expiry_date,
               Date().timeIntervalSince1970 * 1000 >= (expiry - 60_000),
               let refreshToken = creds.refresh_token {
                if let refreshed = try? await refreshAccessToken(refreshToken: refreshToken),
                   let newToken = refreshed.access_token {
                    creds.access_token = newToken
                    if let exp = refreshed.expiry_date {
                        creds.expiry_date = exp
                    }
                    activeToken = newToken
                } else {
                    activeToken = rawToken
                }
            } else {
                activeToken = rawToken
            }

            let resolvedEmail: String?
            if let email, !email.isEmpty {
                resolvedEmail = email
            } else {
                resolvedEmail = try? await Self.fetchUserEmail(accessToken: activeToken)
                if let resolvedEmail {
                    Self.saveAccountEmail(resolvedEmail)
                }
            }

            async let codeAssistTask = try? loadCodeAssist(accessToken: activeToken)
            async let summaryTask = try? retrieveUserQuotaSummary(
                accessToken: activeToken
            )
            async let modelsTask = fetchAvailableModels(
                accessToken: activeToken
            )

            let codeAssist = await codeAssistTask
            let quotaSummary = await summaryTask
            let modelsResponse = try await modelsTask

            let rawTier = codeAssist?.paidTier?.name
                ?? codeAssist?.currentTier?.name
                ?? codeAssist?.currentTier?.id
                ?? "ANTIGRAVITY"
            let tierName: String
            if rawTier.lowercased().contains("google ai pro") {
                tierName = "AI PRO"
            } else if rawTier.lowercased().contains("ultra") {
                tierName = "AI ULTRA"
            } else {
                tierName = rawTier.uppercased()
            }

            var metrics = Self.parseAntigravityMetrics(
                summary: quotaSummary,
                modelsResponse: modelsResponse
            )

            if metrics.isEmpty, let projectId = codeAssist?.cloudaicompanionProject, !projectId.isEmpty {
                if let quota = try? await retrieveUserQuota(accessToken: activeToken, projectId: projectId) {
                    metrics = Self.parseMetrics(from: quota)
                }
            }

            var extraParts: [String] = []
            if let credits = codeAssist?.paidTier?.availableCredits?.first(where: { $0.creditType == "GOOGLE_ONE_AI" })?.creditAmount {
                extraParts.append("Créditos AI: \(credits)")
            }

            return ProviderQuotaSnapshot(
                provider: .gemini,
                authState: .authenticated,
                accountLabel: resolvedEmail ?? "Antigravity OAuth",
                planTier: tierName,
                metrics: metrics,
                extraInfo: extraParts.isEmpty ? nil : extraParts.joined(separator: " · ")
            )
        } catch let error as QuotaFetchError {
            if case .unauthorized = error {
                return ProviderQuotaSnapshot(
                    provider: .gemini,
                    authState: .expired,
                    accountLabel: email,
                    errorMessage: "Sesión de Antigravity/Gemini expirada. Ejecutá `agy` o reconectá."
                )
            }
            return ProviderQuotaSnapshot(
                provider: .gemini,
                authState: .error,
                accountLabel: email,
                errorMessage: error.localizedDescription
            )
        } catch {
            return ProviderQuotaSnapshot(
                provider: .gemini,
                authState: .error,
                accountLabel: email,
                errorMessage: error.localizedDescription
            )
        }
    }

    public static func parseAntigravityMetrics(
        summary: RetrieveUserQuotaSummaryResponse?,
        modelsResponse: FetchAvailableModelsResponse
    ) -> [QuotaMetric] {
        var metrics: [QuotaMetric] = []

        if let groups = summary?.groups, !groups.isEmpty {
            var argonMetrics: [QuotaMetric] = []
            var gemini5h: QuotaMetric?
            var geminiWeekly: QuotaMetric?
            var thirdParty5h: QuotaMetric?
            var thirdPartyWeekly: QuotaMetric?
            var otherMetrics: [QuotaMetric] = []

            for group in groups {
                let groupNameLower = group.displayName?.lowercased() ?? ""
                let isArgonGroup = groupNameLower.contains("argon")
                let isThirdParty = groupNameLower.contains("claude") || groupNameLower.contains("gpt")

                for bucket in group.buckets ?? [] {
                    guard let fraction = bucket.remainingFraction else { continue }
                    let remainingPct = min(max(fraction * 100.0, 0.0), 100.0)
                    let usedPct = max(0.0, 100.0 - remainingPct)
                    let resetDate = parseISO8601(bucket.resetTime)
                    let bId = bucket.bucketId ?? ""
                    let window = bucket.window?.lowercased() ?? ""

                    if isArgonGroup || bId.lowercased().contains("argon") {
                        let winSuffix = window == "5h" ? "5h" : "7d"
                        let winKind: QuotaWindowKind = window == "5h" ? .burst5h : .weekly7d
                        argonMetrics.append(
                            QuotaMetric(
                                id: "agy-\(bId.isEmpty ? "argon-\(winSuffix)" : bId)",
                                label: "Gemini 4 Argon · Orchestrator (\(winSuffix))",
                                usedPercent: usedPct,
                                resetsAt: resetDate,
                                detail: group.description ?? "Pool exclusivo de Gemini 4 Argon (Low/Medium/High) y Orchestrator",
                                poolId: "agy-argon",
                                poolTitle: "Pool Exclusivo",
                                poolSubtitle: "Gemini 4 Argon (Low / Med / High) · Orchestrator",
                                poolCategory: .dedicated,
                                windowKind: winKind
                            )
                        )
                    } else if bId == "gemini-5h" || (!isThirdParty && window == "5h") {
                        gemini5h = QuotaMetric(
                            id: "agy-gemini-5h",
                            label: "Gemini Hydrogen / 3.8 Flash / Pro (5h)",
                            usedPercent: usedPct,
                            resetsAt: resetDate,
                            detail: "Gemini 4 Hydrogen, Gemini 3.8 Flash, Gemini 2.5 Pro",
                            poolId: "agy-gemini",
                            poolTitle: "Pool General",
                            poolSubtitle: "Gemini 4 Hydrogen · Gemini 3.8 Flash · Gemini 2.5 Pro",
                            poolCategory: .core,
                            windowKind: .burst5h
                        )
                    } else if bId == "gemini-weekly" || (!isThirdParty && window == "weekly") {
                        geminiWeekly = QuotaMetric(
                            id: "agy-gemini-weekly",
                            label: "Gemini Hydrogen / 3.8 Flash / Pro (7d)",
                            usedPercent: usedPct,
                            resetsAt: resetDate,
                            detail: "Límite semanal compartido de Gemini Hydrogen, Flash y Pro",
                            poolId: "agy-gemini",
                            poolTitle: "Pool General",
                            poolSubtitle: "Gemini 4 Hydrogen · Gemini 3.8 Flash · Gemini 2.5 Pro",
                            poolCategory: .core,
                            windowKind: .weekly7d
                        )
                    } else if bId == "3p-5h" || (isThirdParty && window == "5h") {
                        thirdParty5h = QuotaMetric(
                            id: "agy-3p-5h",
                            label: "Claude 5.5 & GPT-OSS 120B (5h)",
                            usedPercent: usedPct,
                            resetsAt: resetDate,
                            detail: "Claude Opus 5.5, Claude Sonnet 5.5, GPT-OSS 120B",
                            poolId: "agy-3p",
                            poolTitle: "Pool de Partners",
                            poolSubtitle: "Claude Opus 5.5 · Claude Sonnet 5.5 · GPT-OSS 120B",
                            poolCategory: .partner,
                            windowKind: .burst5h
                        )
                    } else if bId == "3p-weekly" || (isThirdParty && window == "weekly") {
                        thirdPartyWeekly = QuotaMetric(
                            id: "agy-3p-weekly",
                            label: "Claude 5.5 & GPT-OSS 120B (7d)",
                            usedPercent: usedPct,
                            resetsAt: resetDate,
                            detail: "Límite semanal compartido Claude + GPT-OSS",
                            poolId: "agy-3p",
                            poolTitle: "Pool de Partners",
                            poolSubtitle: "Claude Opus 5.5 · Claude Sonnet 5.5 · GPT-OSS 120B",
                            poolCategory: .partner,
                            windowKind: .weekly7d
                        )
                    } else {
                        otherMetrics.append(
                            QuotaMetric(
                                id: "agy-\(bId.isEmpty ? UUID().uuidString : bId)",
                                label: bucket.displayName ?? group.displayName ?? bId,
                                usedPercent: usedPct,
                                resetsAt: resetDate,
                                detail: bucket.description ?? group.description
                            )
                        )
                    }
                }
            }

            // If Argon was not in summary groups, check fetchAvailableModels for gemini-4-argon-*
            if argonMetrics.isEmpty,
               let models = modelsResponse.models,
               let argonEntry = models["gemini-4-argon-medium"] ?? models["gemini-4-argon-low"] ?? models["gemini-4-argon-high"] ?? models["gemini-pro-orchestrator-g1-pro"],
               let fraction = argonEntry.quotaInfo?.remainingFraction {
                let remainingPct = min(max(fraction * 100.0, 0.0), 100.0)
                let usedPct = max(0.0, 100.0 - remainingPct)
                argonMetrics.append(
                    QuotaMetric(
                        id: "agy-argon-weekly",
                        label: "Gemini 4 Argon · Orchestrator (7d)",
                        usedPercent: usedPct,
                        resetsAt: parseISO8601(argonEntry.quotaInfo?.resetTime),
                        detail: "Pool exclusivo de Gemini 4 Argon y Orchestrator"
                    )
                )
            }

            // Orden estricto: 1° Pool General (gemini5h + geminiWeekly), 2° Pool Exclusivo (argonMetrics), 3° Pool de Partners (thirdParty5h + thirdPartyWeekly)
            metrics.append(contentsOf: [gemini5h, geminiWeekly].compactMap { $0 })
            metrics.append(contentsOf: argonMetrics)
            metrics.append(contentsOf: [thirdParty5h, thirdPartyWeekly].compactMap { $0 })
            metrics.append(contentsOf: otherMetrics)
        }

        if !metrics.isEmpty {
            return metrics
        }

        return parseAvailableModelsMetrics(from: modelsResponse)
    }

    public static func parseAvailableModelsMetrics(from response: FetchAvailableModelsResponse) -> [QuotaMetric] {
        guard let models = response.models, !models.isEmpty else { return [] }

        var metrics: [QuotaMetric] = []
        var seenFractionsAndReset: Set<String> = []

        // 1. Gemini Hydrogen / 3.8 Flash / 2.5 Pro pool (Pool General primero)
        let preferredGeminiKeys = [
            ("gemini-4-hydrogen-medium", "Gemini Hydrogen / 3.8 Flash / Pro (5h)"),
            ("gemini-3.8-flash-high", "Gemini Hydrogen / 3.8 Flash / Pro (5h)"),
            ("gemini-2.5-pro", "Gemini Hydrogen / Flash / Pro (5h)"),
            ("gemini-3-flash", "Gemini 3 Flash (5h)"),
            ("gemini-3.1-flash-lite", "Gemini 3.1 Flash Lite (5h)")
        ]

        // Mark Argon signature so it isn't deduplicated into general Gemini keys
        if let argonEntry = models["gemini-4-argon-medium"] ?? models["gemini-4-argon-low"] ?? models["gemini-4-argon-high"] ?? models["gemini-pro-orchestrator-g1-pro"],
           let fraction = argonEntry.quotaInfo?.remainingFraction {
            let resetStr = argonEntry.quotaInfo?.resetTime ?? ""
            let signature = String(format: "%.3f-%@", fraction, resetStr)
            seenFractionsAndReset.insert(signature)
        }

        for (key, title) in preferredGeminiKeys {
            guard let entry = models[key],
                  let fraction = entry.quotaInfo?.remainingFraction else { continue }
            let resetStr = entry.quotaInfo?.resetTime ?? ""
            let signature = String(format: "%.3f-%@", fraction, resetStr)
            let remainingPct = min(max(fraction * 100.0, 0.0), 100.0)
            let usedPct = max(0.0, 100.0 - remainingPct)

            if seenFractionsAndReset.contains(signature) {
                continue
            }
            seenFractionsAndReset.insert(signature)

            metrics.append(
                QuotaMetric(
                    id: "agy-\(key)",
                    label: title,
                    usedPercent: usedPct,
                    resetsAt: parseISO8601(entry.quotaInfo?.resetTime),
                    detail: "Gemini 4 Hydrogen, 3.8 Flash, 2.5 Pro"
                )
            )
        }

        // 2. Also check if any other Gemini model has a distinct quota bucket
        for (key, entry) in models.sorted(by: { $0.key < $1.key }) where key.hasPrefix("gemini-") && !key.contains("argon") && !key.contains("orchestrator") {
            guard let displayName = entry.displayName,
                  let fraction = entry.quotaInfo?.remainingFraction else { continue }
            let resetStr = entry.quotaInfo?.resetTime ?? ""
            let signature = String(format: "%.3f-%@", fraction, resetStr)
            guard !seenFractionsAndReset.contains(signature) else { continue }
            seenFractionsAndReset.insert(signature)

            let remainingPct = min(max(fraction * 100.0, 0.0), 100.0)
            let usedPct = max(0.0, 100.0 - remainingPct)
            metrics.append(
                QuotaMetric(
                    id: "agy-\(key)",
                    label: displayName,
                    usedPercent: usedPct,
                    resetsAt: parseISO8601(entry.quotaInfo?.resetTime)
                )
            )
        }

        // 3. Separate Gemini 4 Argon pool (Pool Exclusivo segundo)
        if let argonEntry = models["gemini-4-argon-medium"] ?? models["gemini-4-argon-low"] ?? models["gemini-4-argon-high"] ?? models["gemini-pro-orchestrator-g1-pro"],
           let fraction = argonEntry.quotaInfo?.remainingFraction {
            let remainingPct = min(max(fraction * 100.0, 0.0), 100.0)
            let usedPct = max(0.0, 100.0 - remainingPct)
            metrics.append(
                QuotaMetric(
                    id: "agy-argon-pool",
                    label: "Gemini 4 Argon · Orchestrator (7d)",
                    usedPercent: usedPct,
                    resetsAt: parseISO8601(argonEntry.quotaInfo?.resetTime),
                    detail: "Pool exclusivo de Gemini 4 Argon"
                )
            )
        }

        // 4. Antigravity third-party model quota (Pool de Partners tercero: Claude Opus/Sonnet 5.5 + GPT-OSS 120B)
        if let agy3P = models["claude-sonnet-5-5-high"] ?? models["claude-opus-5-5-high"] ?? models["gpt-oss-120b-medium"],
           let fraction = agy3P.quotaInfo?.remainingFraction {
            let remainingPct = min(max(fraction * 100.0, 0.0), 100.0)
            let usedPct = max(0.0, 100.0 - remainingPct)
            metrics.append(
                QuotaMetric(
                    id: "agy-claude-pool",
                    label: "Claude 5.5 & GPT-OSS 120B (5h)",
                    usedPercent: usedPct,
                    resetsAt: parseISO8601(agy3P.quotaInfo?.resetTime),
                    detail: "Claude Opus 5.5, Sonnet 5.5, GPT-OSS 120B"
                )
            )
        }

        return metrics
    }

    public static func parseMetrics(from quota: RetrieveUserQuotaResponse) -> [QuotaMetric] {
        guard let buckets = quota.buckets, !buckets.isEmpty else { return [] }

        var grouped: [String: RetrieveUserQuotaResponse.BucketInfo] = [:]
        for bucket in buckets {
            guard bucket.remainingFraction != nil else { continue }
            let key = bucket.modelId ?? bucket.tokenType ?? "General"
            if let existing = grouped[key],
               let existingFrac = existing.remainingFraction,
               let newFrac = bucket.remainingFraction {
                if newFrac < existingFrac {
                    grouped[key] = bucket
                }
            } else {
                grouped[key] = bucket
            }
        }

        let sortedKeys = grouped.keys.sorted()
        var metrics: [QuotaMetric] = []
        for key in sortedKeys.prefix(4) {
            guard let bucket = grouped[key],
                  let remainingFraction = bucket.remainingFraction else { continue }
            let remainingPct = min(max(remainingFraction * 100.0, 0.0), 100.0)
            let usedPct = max(0.0, 100.0 - remainingPct)
            let resetDate = parseISO8601(bucket.resetTime)
            let cleanLabel = formatModelName(key)
            metrics.append(
                QuotaMetric(
                    id: "gemini-\(key)",
                    label: cleanLabel,
                    usedPercent: usedPct,
                    resetsAt: resetDate,
                    detail: bucket.remainingAmount.map { "\($0) restantes" }
                )
            )
        }

        return metrics
    }

    private static func formatModelName(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(of: "models/", with: "")
        if cleaned.contains("gemini-2.5-pro") { return "Gemini 2.5 Pro" }
        if cleaned.contains("gemini-2.5-flash") { return "Gemini 2.5 Flash" }
        if cleaned.contains("gemini-3") { return cleaned.replacingOccurrences(of: "gemini-", with: "Gemini ").capitalized }
        return cleaned
    }

    private func postAntigravity<T: Decodable>(
        endpoint: String,
        accessToken: String,
        body: Data,
        as type: T.Type
    ) async throws -> T {
        guard let url = URL(string: "\(Self.antigravityBaseURL):\(endpoint)") else {
            throw QuotaFetchError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.antigravityUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return try await QuotaHTTPClient.sendJSON(request, as: type)
    }

    private func loadCodeAssist(accessToken: String) async throws -> LoadCodeAssistResponse {
        let payload: [String: Any] = [
            "metadata": [
                "ideType": "ANTIGRAVITY",
                "platform": "DARWIN_AMD64",
                "pluginType": "GEMINI"
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await postAntigravity(endpoint: "loadCodeAssist", accessToken: accessToken, body: body, as: LoadCodeAssistResponse.self)
    }

    private func fetchAvailableModels(
        accessToken: String,
        projectId: String? = nil
    ) async throws -> FetchAvailableModelsResponse {
        let body: Data
        if let projectId, !projectId.isEmpty {
            body = try JSONSerialization.data(withJSONObject: ["project": projectId])
        } else {
            body = Data("{}".utf8)
        }
        return try await postAntigravity(endpoint: "fetchAvailableModels", accessToken: accessToken, body: body, as: FetchAvailableModelsResponse.self)
    }

    private func retrieveUserQuotaSummary(
        accessToken: String,
        projectId: String? = nil
    ) async throws -> RetrieveUserQuotaSummaryResponse {
        let body: Data
        if let projectId, !projectId.isEmpty {
            body = try JSONSerialization.data(withJSONObject: ["project": projectId])
        } else {
            body = Data("{}".utf8)
        }
        return try await postAntigravity(endpoint: "retrieveUserQuotaSummary", accessToken: accessToken, body: body, as: RetrieveUserQuotaSummaryResponse.self)
    }

    private func retrieveUserQuota(accessToken: String, projectId: String) async throws -> RetrieveUserQuotaResponse {
        let body = try JSONSerialization.data(withJSONObject: ["project": projectId])
        return try await postAntigravity(endpoint: "retrieveUserQuota", accessToken: accessToken, body: body, as: RetrieveUserQuotaResponse.self)
    }

    public func refreshAccessToken(refreshToken: String) async throws -> StoredOAuthCreds {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw QuotaFetchError.invalidURL
        }

        struct TokenRefreshResponse: Decodable {
            let access_token: String
            let expires_in: Double?
            let scope: String?
            let token_type: String?
        }

        var clientPairs: [(String, String)] = []
        if let envID = Self.oauthClientID, let envSecret = Self.oauthClientSecret, !envID.isEmpty, !envSecret.isEmpty {
            clientPairs.append((envID, envSecret))
        }
        clientPairs.append(contentsOf: Self.discoverLocalInstalledCLIClients())

        for (clientID, clientSecret) in clientPairs {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            var comps = URLComponents()
            comps.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "client_secret", value: clientSecret),
                URLQueryItem(name: "refresh_token", value: refreshToken),
                URLQueryItem(name: "grant_type", value: "refresh_token")
            ]
            request.httpBody = comps.percentEncodedQuery?.data(using: .utf8)

            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let decoded = try? JSONDecoder().decode(TokenRefreshResponse.self, from: data) {
                let expiryMs = decoded.expires_in.map { (Date().timeIntervalSince1970 + $0) * 1000.0 }
                return StoredOAuthCreds(
                    access_token: decoded.access_token,
                    refresh_token: refreshToken,
                    token_type: decoded.token_type ?? "Bearer",
                    scope: decoded.scope,
                    expiry_date: expiryMs
                )
            }
        }

        throw QuotaFetchError.unauthorized
    }

    public static func fetchUserEmail(accessToken: String) async throws -> String? {
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        struct UserInfo: Decodable {
            let email: String?
        }
        return try? JSONDecoder().decode(UserInfo.self, from: data).email
    }

    public func readCredentials() -> StoredOAuthCreds? {
        // 1. Check Antigravity (`agy`) Keychain entry: service="gemini", account="antigravity"
        // Format: "go-keyring-base64:<base64-json>"
        if let raw = KeychainHelper.readGenericPassword(service: "gemini", account: "antigravity") {
            let prefix = "go-keyring-base64:"
            let b64 = raw.hasPrefix(prefix) ? String(raw.dropFirst(prefix.count)) : raw
            if let decodedData = Data(base64Encoded: b64.trimmingCharacters(in: .whitespacesAndNewlines)),
               let payload = try? JSONDecoder().decode(AntigravityKeyringPayload.self, from: decodedData),
               let token = payload.token,
               let accessToken = token.access_token,
               !accessToken.isEmpty {
                let expiryMs = Self.parseISO8601(token.expiry).map { $0.timeIntervalSince1970 * 1000.0 }
                return StoredOAuthCreds(
                    access_token: accessToken,
                    refresh_token: token.refresh_token,
                    token_type: token.token_type ?? "Bearer",
                    expiry_date: expiryMs,
                    email: payload.id_token_email
                )
            }
        }

        // 2. Check ~/.gemini/oauth_creds.json
        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/oauth_creds.json")
        if let data = try? Data(contentsOf: fileURL),
           let creds = try? JSONDecoder().decode(StoredOAuthCreds.self, from: data),
           creds.access_token != nil {
            return creds
        }

        // 3. Check Keychain "gemini-cli-oauth" (account "main-account")
        if let raw = KeychainHelper.readGenericPassword(service: "gemini-cli-oauth", account: "main-account"),
           let data = raw.data(using: .utf8),
           let wrapper = try? JSONDecoder().decode(KeychainMCPWrapper.self, from: data),
           let token = wrapper.token {
            return StoredOAuthCreds(
                access_token: token.accessToken,
                refresh_token: token.refreshToken,
                token_type: token.tokenType,
                scope: token.scope,
                expiry_date: token.expiresAt
            )
        }

        return nil
    }

    public static func saveCredentials(_ creds: StoredOAuthCreds, email: String? = nil) {
        let geminiDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini")
        try? FileManager.default.createDirectory(at: geminiDir, withIntermediateDirectories: true)

        let fileURL = geminiDir.appendingPathComponent("oauth_creds.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(creds) {
            try? data.write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        }

        if let email, !email.isEmpty {
            saveAccountEmail(email)
        }
    }

    public static func saveAccountEmail(_ email: String) {
        let accountsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/google_accounts.json")
        var accounts = GoogleAccountsFile(active: email, old: [])
        if let existingData = try? Data(contentsOf: accountsURL),
           let existing = try? JSONDecoder().decode(GoogleAccountsFile.self, from: existingData) {
            var oldList = existing.old ?? []
            if let prev = existing.active, prev != email, !oldList.contains(prev) {
                oldList.append(prev)
            }
            accounts = GoogleAccountsFile(active: email, old: oldList)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(accounts) {
            try? data.write(to: accountsURL, options: .atomic)
        }
    }

    private func readAccountEmail() -> String? {
        let accountsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini/google_accounts.json")
        guard let data = try? Data(contentsOf: accountsURL),
              let decoded = try? JSONDecoder().decode(GoogleAccountsFile.self, from: data) else {
            return nil
        }
        return decoded.active ?? decoded.old?.first
    }

    private static func parseISO8601(_ raw: String?) -> Date? {
        QuotaDateUtils.parseISO8601(raw)
    }

    /// Reads OAuth client configuration dynamically from locally installed `gemini` CLI files on disk if present,
    /// avoiding any hardcoded OAuth client secrets in the repository.
    public static func discoverLocalInstalledCLIClients() -> [(String, String)] {
        let candidatePaths = [
            "/usr/local/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js",
            "/opt/homebrew/lib/node_modules/@google/gemini-cli/node_modules/@google/gemini-cli-core/dist/src/code_assist/oauth2.js"
        ]
        var results: [(String, String)] = []
        let idPattern = #"(\d{10,}-[a-z0-9]+\.apps\.googleusercontent\.com)"#
        let secretPattern = #"(GOCSPX-[A-Za-z0-9_-]+)"#

        for path in candidatePaths {
            guard let content = try? String(contentsOfFile: path, encoding: .utf8),
                  let idRange = content.range(of: idPattern, options: .regularExpression),
                  let secretRange = content.range(of: secretPattern, options: .regularExpression) else {
                continue
            }
            results.append((String(content[idRange]), String(content[secretRange])))
        }
        return results
    }
}
