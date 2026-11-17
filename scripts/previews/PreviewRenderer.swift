import AppKit
import SwiftUI
import WidgetKit

@main
struct PreviewRenderer {
    @MainActor
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let media = root.appendingPathComponent("media", isDirectory: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)

        for provider in AIProviderKind.allCases {
            guard let url = Bundle.main.url(forResource: provider.rawValue, withExtension: "png", subdirectory: "ProviderLogos"),
                  NSImage(contentsOf: url) != nil else {
                throw CocoaError(.fileReadNoSuchFile)
            }
        }

        let now = Date()
        let dashboard = sampleDashboard(now: now)
        let preferences = QuotaPreferencesData(
            summaryWindowMode: .weeklyAndBurst,
            dualWindowLayoutStyle: .capsulePills,
            menuBarPoolsByProvider: [
                "claude": ["claude-general", "claude-fable"],
                "gemini": ["agy-gemini", "agy-argon", "agy-3p"]
            ],
            language: .en
        )
        let groups = preferences.menuBarProviders.map {
            preferences.summaryTokens(for: dashboard.snapshot(for: $0))
        }
        try render(
            RichMenuBarStatusCanvas(groups: groups, menuBarStyle: .logosAndPercentages, dualLayoutStyle: .capsulePills)
                .padding(8),
            to: media.appendingPathComponent("menubar-status-pills.png")
        )

        let entry = QuotaTimelineEntry(date: now, dashboard: dashboard, preferences: preferences)
        for (family, size, name) in [
            (WidgetFamily.systemSmall, CGSize(width: 170, height: 170), "widget-small.png"),
            (.systemMedium, CGSize(width: 360, height: 170), "widget-medium.png"),
            (.systemLarge, CGSize(width: 360, height: 380), "widget-large.png")
        ] {
            try render(
                AIQuotaWidgetEntryView(entry: entry, family: family)
                    .padding(14)
                    .frame(width: size.width, height: size.height)
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 22))
                    .padding(8),
                to: media.appendingPathComponent(name)
            )
        }

        let store = PreferencesStore()
        store.data = preferences
        let model = QuotaViewModel(dashboard: dashboard)
        let popover = DashboardWindowView(viewModel: model, preferences: store)
            .frame(width: 445, height: 900)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .padding(8)
            .environment(\.colorScheme, .dark)
        let hosting = NSHostingView(rootView: popover)
        let size = hosting.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        try save(bitmap, to: media.appendingPathComponent("menubar-popover.png"))
    }

    @MainActor
    private static func render<Content: View>(_ view: Content, to url: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = 2
        renderer.isOpaque = false
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try save(bitmap, to: url)
    }

    private static func save(_ bitmap: NSBitmapImageRep, to url: URL) throws {
        guard bitmap.hasAlpha,
              bitmap.colorAt(x: 0, y: 0)?.alphaComponent == 0,
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: url)
        print("Rendered \(url.lastPathComponent): \(bitmap.pixelsWide) × \(bitmap.pixelsHigh), transparent PNG")
    }

    private static func sampleDashboard(now: Date) -> QuotaDashboardState {
        func metric(_ pool: String, _ window: QuotaWindowKind, _ used: Double) -> QuotaMetric {
            ModelCatalog.pool(id: pool)!.metric(
                id: "\(pool)-\(window.rawValue)",
                window: window,
                usedPercent: used,
                resetsAt: now.addingTimeInterval(window == .burst5h ? 9720 : 392400)
            )
        }
        return QuotaDashboardState(snapshots: [
            ProviderQuotaSnapshot(provider: .claude, authState: .authenticated, accountLabel: "Claude Pro", planTier: "PRO", metrics: [
                metric("claude-general", .burst5h, 12),
                metric("claude-general", .weekly7d, 24),
                metric("claude-fable", .weekly7d, 8)
            ]),
            ProviderQuotaSnapshot(provider: .codex, authState: .authenticated, accountLabel: "ChatGPT Plus", planTier: "PLUS", metrics: [
                metric("codex-general", .burst5h, 40),
                metric("codex-general", .weekly7d, 50)
            ]),
            ProviderQuotaSnapshot(provider: .gemini, authState: .authenticated, accountLabel: "Google AI Pro", planTier: "AI PRO", metrics: [
                metric("agy-gemini", .burst5h, 80),
                metric("agy-gemini", .weekly7d, 90),
                metric("agy-argon", .weekly7d, 44),
                metric("agy-3p", .burst5h, 0),
                metric("agy-3p", .weekly7d, 12)
            ])
        ], lastRefreshedAt: now)
    }
}
