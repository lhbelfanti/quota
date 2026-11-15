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
        let summary = viewModel.formattedMenuBarText(preferences: preferences.data)
        if summary.isEmpty {
            Image(systemName: "sparkles")
        } else {
            Text(summary)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
    }
}
