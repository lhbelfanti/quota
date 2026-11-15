import SwiftUI
import AppKit

@MainActor
final class AIQuotaAppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = QuotaViewModel()
    let preferences = PreferencesStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = iconImage
        }
    }
}

@main
struct AIQuotaApp: App {
    @NSApplicationDelegateAdaptor(AIQuotaAppDelegate.self) private var appDelegate
    @ObservedObject private var preferences: PreferencesStore

    init() {
        if CommandLine.arguments.contains("--cli-status") {
            Task.detached {
                let agg = QuotaAggregator()
                let state = await agg.refreshAll()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(state),
                   let str = String(data: data, encoding: .utf8) {
                    print(str)
                }
                exit(0)
            }
            RunLoop.main.run(until: Date().addingTimeInterval(15))
            exit(1)
        }

        let prefs = PreferencesStore.shared
        self._preferences = ObservedObject(wrappedValue: prefs)
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardWindowView(
                viewModel: appDelegate.viewModel,
                preferences: preferences,
                isPopover: true
            )
            .handlesExternalEvents(preferring: Set(arrayLiteral: "refresh"), allowing: Set(arrayLiteral: "*"))
            .onOpenURL { url in
                if url.scheme == "aiquota" {
                    Task {
                        await appDelegate.viewModel.refreshAll()
                    }
                }
            }
        } label: {
            MenuBarStatusLabel(
                viewModel: appDelegate.viewModel,
                preferences: preferences
            )
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarStatusLabel: View {
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject var preferences: PreferencesStore

    var body: some View {
        let prefs = preferences.data
        let summary = viewModel.formattedMenuBarText(preferences: prefs)
        if summary.isEmpty {
            Image(systemName: "sparkles")
        } else if prefs.summaryWindowMode == .fiveHourAndSevenDay,
                  (prefs.dualWindowLayoutStyle == .stackedTwoLines || prefs.dualWindowLayoutStyle == .capsulePills),
                  let renderedImage = renderRichMenuBarImage(prefs: prefs) {
            Image(nsImage: renderedImage)
        } else {
            Text(summary)
                .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
        }
    }

    @MainActor
    private func renderRichMenuBarImage(prefs: QuotaPreferencesData) -> NSImage? {
        let enabled = prefs.menuBarProviders
        let allTokens: [ProviderSummaryTokens] = enabled.compactMap { kind in
            prefs.summaryTokens(for: viewModel.dashboard.snapshot(for: kind), compactMenuBar: true)
        }
        guard !allTokens.isEmpty else { return nil }

        let targetTokens: [ProviderSummaryTokens]
        if prefs.menuBarStyle == .lowestOnly {
            guard let lowest = allTokens.min(by: { $0.statusRemainingPercent < $1.statusRemainingPercent }) else {
                return nil
            }
            targetTokens = [lowest]
        } else {
            targetTokens = allTokens
        }

        let content = RichMenuBarStatusCanvas(
            tokensList: targetTokens,
            menuBarStyle: prefs.menuBarStyle,
            dualLayoutStyle: prefs.dualWindowLayoutStyle
        )

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        guard let nsImage = renderer.nsImage else { return nil }
        nsImage.isTemplate = true
        return nsImage
    }
}

private struct RichMenuBarStatusCanvas: View {
    let tokensList: [ProviderSummaryTokens]
    let menuBarStyle: MenuBarDisplayStyle
    let dualLayoutStyle: DualWindowLayoutStyle

    private func prefixLabel(for provider: AIProviderKind) -> String {
        switch menuBarStyle {
        case .logosAndPercentages:
            switch provider {
            case .claude: return "✳︎"
            case .codex: return "⬢"
            case .gemini: return "✦"
            }
        case .compactInitials:
            switch provider {
            case .claude: return "C"
            case .codex: return "X"
            case .gemini: return "G"
            }
        case .fullNames, .lowestOnly:
            return provider.displayName
        case .iconOnly:
            return ""
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: dualLayoutStyle == .capsulePills ? 5 : 8) {
            ForEach(Array(tokensList.enumerated()), id: \.element.provider) { idx, item in
                if dualLayoutStyle == .stackedTwoLines {
                    HStack(alignment: .center, spacing: 3) {
                        Text(prefixLabel(for: item.provider))
                            .font(.system(size: 11, weight: .bold, design: .rounded))

                        if let b = item.burst5hText, let w = item.weekly7dText {
                            VStack(alignment: .leading, spacing: -1.5) {
                                Text("\(b) 5h")
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded).monospacedDigit())
                                Text("\(w) 7d")
                                    .font(.system(size: 7.5, weight: .medium, design: .rounded).monospacedDigit())
                                    .opacity(0.78)
                            }
                        } else {
                            Text(item.singleText)
                                .font(.system(size: 9.5, weight: .bold, design: .rounded).monospacedDigit())
                        }
                    }

                    if idx < tokensList.count - 1 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.32))
                            .frame(width: 1, height: 12)
                    }
                } else {
                    // Opción 3: Mini cápsulas (Pills) por IA
                    HStack(alignment: .center, spacing: 3.5) {
                        Text(prefixLabel(for: item.provider))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                        Text(item.singleText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    }
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.45), lineWidth: 1)
                    )
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 2)
        .frame(height: 20)
        .fixedSize()
    }
}
