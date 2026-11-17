import Foundation

@main
enum QuotaCoreTestRunner {
    static func main() {
        var passed = 0

        // 1. Test Claude Usage Parsing (including weekly_scoped_shares and shared 5h on Fable)
        do {
            let json = """
            {
              "five_hour": {
                "utilization": 12.5,
                "resets_at": "2026-11-14T00:00:00.306745+00:00"
              },
              "seven_day": {
                "utilization": 30.0,
                "resets_at": "2026-11-19T11:00:00.306763+00:00"
              },
              "limits": [
                {
                  "kind": "session",
                  "group": "session",
                  "percent": 12.5,
                  "resets_at": "2026-11-14T00:00:00+00:00"
                },
                {
                  "kind": "weekly_all",
                  "group": "weekly",
                  "percent": 30.0,
                  "resets_at": "2026-11-19T11:00:00+00:00"
                },
                {
                  "kind": "weekly_scoped",
                  "group": "weekly",
                  "percent": 8,
                  "resets_at": "2026-11-19T11:00:00+00:00",
                  "scope": {
                    "model": {
                      "id": null,
                      "display_name": "Fable"
                    }
                  }
                }
              ],
              "weekly_scoped_shares": [
                {
                  "limit_index": 2,
                  "used_percent_of_weekly": 4,
                  "allowance_percent_of_weekly": 50
                }
              ]
            }
            """.data(using: .utf8)!

            let decoded = try JSONDecoder().decode(ClaudeProviderClient.UsageResponse.self, from: json)
            let metrics = ClaudeProviderClient.parseMetrics(from: decoded)
            precondition(metrics.count == 3, "Expected 3 Claude metrics")
            precondition(abs(metrics[0].remainingPercent - 87.5) < 0.01, "Expected 87.5% remaining on 5h")
            precondition(abs(metrics[1].remainingPercent - 70.0) < 0.01, "Expected 70.0% remaining on 7d")
            precondition(abs(metrics[2].remainingPercent - 92.0) < 0.01, "Expected 92.0% remaining on Fable")
            precondition(metrics[2].weeklyAllowancePercentOfGeneral == 50, "Expected 50% allowance share on Fable")
            precondition(metrics[2].weeklyUsedPercentOfGeneral == 4, "Expected 4% used share on Fable")

            let claudeSnap = ProviderQuotaSnapshot(provider: .claude, authState: .authenticated, metrics: metrics)
            let claudePools = claudeSnap.pools
            precondition(claudePools.count == 2, "Expected 2 Claude pools (Pool General + Pool Exclusivo)")
            precondition(claudePools[0].category == .core && claudePools[0].title == "Pool General", "Expected Pool General first")
            precondition(claudePools[0].burst5hMetric != nil && claudePools[0].weekly7dMetric != nil, "Expected General pool to have both 5h and 7d")
            precondition(claudePools[1].category == .dedicated && claudePools[1].title == "Pool Exclusivo", "Expected Pool Exclusivo second")
            precondition(claudePools[1].sharingArchitecture == .shared5hAndScopedWeekly, "Expected Fable pool to have shared5hAndScopedWeekly architecture")
            precondition(claudePools[1].sharedBurst5hMetric?.remainingPercent == 87.5, "Expected Fable pool to link shared 5h metric from General Pool")
            passed += 1
        } catch {
            fatalError("Claude test failed: \(error)")
        }

        // 2. Test Codex Wham Usage Parsing
        do {
            let json = """
            {
              "plan_type": "plus",
              "rate_limit": {
                "allowed": true,
                "limit_reached": false,
                "primary_window": {
                  "used_percent": 5,
                  "limit_window_seconds": 18000,
                  "reset_after_seconds": 16000,
                  "reset_at": 1794614801
                },
                "secondary_window": {
                  "used_percent": 22,
                  "limit_window_seconds": 604800,
                  "reset_after_seconds": 450000,
                  "reset_at": 1795057753
                }
              }
            }
            """.data(using: .utf8)!

            let decoded = try JSONDecoder().decode(CodexProviderClient.WhamUsageResponse.self, from: json)
            let metrics = CodexProviderClient.parseMetrics(from: decoded)
            precondition(metrics.count == 2, "Expected 2 Codex metrics")
            precondition(abs(metrics[0].remainingPercent - 95.0) < 0.01, "Expected 95% remaining on 5h")
            precondition(abs(metrics[1].remainingPercent - 78.0) < 0.01, "Expected 78% remaining on 7d")
            passed += 1
        } catch {
            fatalError("Codex test failed: \(error)")
        }

        // 3. Test Gemini / Antigravity User Quota & FetchAvailableModels Parsing
        do {
            let json = """
            {
              "buckets": [
                {
                  "remainingAmount": "120",
                  "remainingFraction": 0.8,
                  "resetTime": "2026-11-14T00:00:00Z",
                  "modelId": "models/gemini-2.5-pro"
                },
                {
                  "remainingAmount": "450",
                  "remainingFraction": 0.9,
                  "resetTime": "2026-11-14T00:00:00Z",
                  "modelId": "models/gemini-2.5-flash"
                }
              ]
            }
            """.data(using: .utf8)!

            let decoded = try JSONDecoder().decode(GeminiProviderClient.RetrieveUserQuotaResponse.self, from: json)
            let metrics = GeminiProviderClient.parseMetrics(from: decoded)
            precondition(metrics.count == 2, "Expected 2 Gemini metrics")
            let pro = metrics.first(where: { $0.label == "Gemini 2.5 Pro" })
            precondition(pro != nil, "Expected Gemini 2.5 Pro metric")
            precondition(abs((pro?.remainingPercent ?? 0) - 80.0) < 0.01, "Expected 80% remaining")

            let agyModelsJson = """
            {
              "models": {
                "gemini-2.5-pro": {
                  "displayName": "Gemini 2.5 Pro",
                  "quotaInfo": {
                    "remainingFraction": 0.89,
                    "resetTime": "2026-11-14T00:07:09Z"
                  },
                  "recommended": true
                },
                "gemini-3-flash": {
                  "displayName": "Gemini 3 Flash",
                  "quotaInfo": {
                    "remainingFraction": 0.89,
                    "resetTime": "2026-11-14T00:07:09Z"
                  },
                  "recommended": true
                },
                "claude-sonnet-5-5-high": {
                  "displayName": "Claude Sonnet 5.5 (High)",
                  "quotaInfo": {
                    "remainingFraction": 1.0,
                    "resetTime": "2026-11-14T01:34:21Z"
                  },
                  "recommended": true
                }
              }
            }
            """.data(using: .utf8)!
            let agySummaryJson = """
            {
              "groups": [
                {
                  "buckets": [
                    {
                      "bucketId": "gemini-weekly",
                      "displayName": "Weekly Limit Remaining",
                      "window": "weekly",
                      "resetTime": "2026-11-19T03:15:03Z",
                      "remainingFraction": 0.60
                    },
                    {
                      "bucketId": "gemini-5h",
                      "displayName": "Five Hour Limit Remaining",
                      "window": "5h",
                      "resetTime": "2026-11-14T00:07:09Z",
                      "remainingFraction": 0.84
                    }
                  ],
                  "displayName": "Gemini Models"
                },
                {
                  "buckets": [
                    {
                      "bucketId": "gemini-argon-wtu-weekly",
                      "displayName": "Gemini 4 Argon Weekly Limit",
                      "window": "weekly",
                      "resetTime": "2026-11-20T19:16:58Z",
                      "remainingFraction": 0.497
                    }
                  ],
                  "displayName": "Gemini 4 Argon"
                },
                {
                  "buckets": [
                    {
                      "bucketId": "3p-weekly",
                      "displayName": "Weekly Limit Remaining",
                      "window": "weekly",
                      "resetTime": "2026-11-20T20:54:58Z",
                      "remainingFraction": 1.0
                    },
                    {
                      "bucketId": "3p-5h",
                      "displayName": "Five Hour Limit Remaining",
                      "window": "5h",
                      "resetTime": "2026-11-14T01:54:58Z",
                      "remainingFraction": 0.95
                    }
                  ],
                  "displayName": "Claude and GPT models"
                }
              ]
            }
            """.data(using: .utf8)!
            let summaryDecoded = try JSONDecoder().decode(GeminiProviderClient.RetrieveUserQuotaSummaryResponse.self, from: agySummaryJson)
            let agyDecoded = try JSONDecoder().decode(GeminiProviderClient.FetchAvailableModelsResponse.self, from: agyModelsJson)
            let agyMetrics = GeminiProviderClient.parseAntigravityMetrics(summary: summaryDecoded, modelsResponse: agyDecoded)
            precondition(agyMetrics.count == 5, "Expected 5 AGY pool metrics (Gemini 5h/7d + Argon 7d + Claude/GPT-OSS 5h/7d)")
            precondition(agyMetrics[0].label.contains("Hydrogen"), "Expected Hydrogen in first (Pool General) 5h label")
            precondition(abs(agyMetrics[0].remainingPercent - 84.0) < 0.01, "Expected 84% remaining on Gemini 5h")
            precondition(abs(agyMetrics[1].remainingPercent - 60.0) < 0.01, "Expected 60% remaining on Gemini 7d")
            precondition(agyMetrics[2].label.contains("Argon"), "Expected Argon in second (Pool Exclusivo) label")
            precondition(abs(agyMetrics[2].remainingPercent - 49.7) < 0.01, "Expected 49.7% remaining on Argon 7d")
            precondition(agyMetrics[3].label.contains("GPT-OSS"), "Expected Claude & GPT-OSS in third (Pool de Partners) 5h label")
            precondition(abs(agyMetrics[3].remainingPercent - 95.0) < 0.01, "Expected 95% remaining on 3P 5h")
            precondition(abs(agyMetrics[4].remainingPercent - 100.0) < 0.01, "Expected 100% remaining on 3P 7d")

            let agySnap = ProviderQuotaSnapshot(provider: .gemini, authState: .authenticated, metrics: agyMetrics)
            let agyPools = agySnap.pools
            precondition(agyPools.count == 3, "Expected 3 AGY pools (Pool General + Pool Exclusivo + Pool de Partners)")
            precondition(agyPools[0].id == "agy-gemini" && agyPools[0].category == .core && agyPools[0].title == "Pool General" && agyPools[0].burst5hMetric != nil && agyPools[0].weekly7dMetric != nil, "Expected Pool General (.core) first with 5h + 7d")
            precondition(agyPools[1].id == "agy-argon" && agyPools[1].category == .dedicated && agyPools[1].title == "Pool Exclusivo" && agyPools[1].sharingArchitecture == .independentWeeklyOnly, "Expected Pool Exclusivo (.dedicated) second with independentWeeklyOnly")
            precondition(agyPools[2].id == "agy-3p" && agyPools[2].category == .partner && agyPools[2].title == "Pool de Partners", "Expected Pool de Partners (.partner) third")

            // Test QuotaDisplayMode & SummaryWindowMode formatting
            let m = agyMetrics[0]
            precondition(QuotaDisplayMode.remaining.format(metric: m, language: .es) == "84% disp.", "Expected 84% disp.")
            precondition(QuotaDisplayMode.used.format(metric: m, language: .es) == "16% usado", "Expected 16% usado")
            precondition(QuotaDisplayMode.both.format(metric: m, language: .es) == "84% disp. · 16% usado", "Expected 84% disp. · 16% usado")
            precondition(QuotaDisplayMode.both.formatMenuBarPercent(remainingPercent: 84) == "84% (16%u)", "Expected 84% (16%u) in menu bar for .both")

            func summary(_ prefs: QuotaPreferencesData, _ snap: ProviderQuotaSnapshot) -> String? {
                prefs.formatProviderSummary(snapshot: snap, compactMenuBar: true)?.text
            }
            func dual(_ style: DualWindowLayoutStyle, pools: [String: [String]] = [:]) -> QuotaPreferencesData {
                QuotaPreferencesData(summaryWindowMode: .weeklyAndBurst, dualWindowLayoutStyle: style, menuBarPoolsByProvider: pools)
            }
            precondition(agyPools[0].primaryMetric?.windowKind == .weekly7d, "Expected 7d to be the primary metric of a dual pool")
            precondition(summary(QuotaPreferencesData(), agySnap) == "60%", "Expected the 7d quota (60%) by default")
            precondition(summary(dual(.inlineDot), agySnap) == "60% 7d · 84% 5h", "Expected 7d first for inlineDot mode")
            precondition(summary(dual(.parentheses5h), agySnap) == "60% (84% 5h)", "Expected 5h in parentheses")
            precondition(summary(dual(.subscripts), agySnap) == "60%₇𝒹 84%₅ₕ", "Expected 7d first for subscripts mode")
            precondition(summary(dual(.capsulePills), agySnap) == "60% · 84%", "Expected 7d first for capsulePills mode")
            precondition(summary(dual(.inlineDot, pools: ["gemini": ["agy-3p"]]), agySnap) == "100% 7d · 95% 5h", "Expected Pool de Partners when selected for Gemini")

            // Varios pools por proveedor en la barra superior
            let multiGemini = QuotaPreferencesData(menuBarPoolsByProvider: ["gemini": ["agy-argon", "agy-gemini"]])
            precondition(summary(multiGemini, agySnap) == "60% Ar 50%", "Expected General + Argon in catalog order with the Argon tag")
            precondition(multiGemini.formatProviderSummary(snapshot: agySnap, compactMenuBar: true)?.statusRemainingPercent == agyMetrics[2].remainingPercent, "Expected status to follow the lowest selected pool")

            let claudeSnap = ProviderQuotaSnapshot(
                provider: .claude,
                authState: .authenticated,
                metrics: [
                    ModelCatalog.pool(id: "claude-general")!.metric(id: "claude-5h", window: .burst5h, usedPercent: 13),
                    ModelCatalog.pool(id: "claude-general")!.metric(id: "claude-7d", window: .weekly7d, usedPercent: 30),
                    ModelCatalog.claudeScopedPool(named: "Fable").metric(id: "claude-scoped-fable", window: .weekly7d, usedPercent: 8)
                ]
            )
            let claudeBoth = ["claude": ["claude-general", "claude-fable"]]
            precondition(summary(dual(.parentheses5h, pools: claudeBoth), claudeSnap) == "70% (87% 5h) F 92% 7d", "Expected shared 5h shown once when General + Fable are selected")
            precondition(summary(dual(.parentheses5h, pools: ["claude": ["claude-fable"]]), claudeSnap) == "92% (87% 5h)", "Expected Fable alone to show the shared 5h")

            // Preferencias guardadas por versiones anteriores
            let legacyJSON = """
            {"summaryWindowMode": "fiveHourAndSevenDay", "dualWindowLayoutStyle": "parentheses7d", "preferredPoolByProvider": {"gemini": "partner"}}
            """.data(using: .utf8)!
            let legacy = try JSONDecoder().decode(QuotaPreferencesData.self, from: legacyJSON)
            precondition(legacy.summaryWindowMode == .weeklyAndBurst && legacy.dualWindowLayoutStyle == .parentheses5h, "Expected legacy window settings to migrate")
            precondition(legacy.menuBarPoolIds(for: .gemini) == ["agy-3p"], "Expected legacy pool category to migrate to a pool id")
            precondition(legacy.menuBarPoolIds(for: .claude) == ["claude-general"], "Expected General pool by default")

            // Inferencia de pool desde el catálogo (snapshots cacheados sin datos de pool)
            precondition(QuotaMetric(id: "agy-argon-pool", label: "x (7d)", usedPercent: 1).poolId == "agy-argon", "Expected Argon pool inferred from catalog keywords")
            precondition(QuotaMetric(id: "codex-secondary", label: "x", usedPercent: 1).poolSubtitle == ModelCatalog.pool(id: "codex-general")?.subtitle, "Expected Codex subtitle from catalog")

            precondition(L10n.generalPoolTitle(.de) == "Allgemeiner Pool", "Expected German translation for General Pool")
            precondition(L10n.exclusivePoolTitle(.es) == "Pool Exclusivo", "Expected Spanish translation for Exclusive Pool")
            precondition(L10n.partnerPoolTitle(.es) == "Pool de Partners", "Expected Spanish translation for Partner Pool")
            passed += 1
        } catch {
            fatalError("Gemini test failed: \(error)")
        }

        print("✓ All \(passed) test suites passed!")
    }
}
