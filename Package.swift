// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIQuota",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "QuotaCore", targets: ["QuotaCore"]),
        .executable(name: "AIQuotaApp", targets: ["AIQuotaApp"]),
        .executable(name: "AIQuotaWidgetExtension", targets: ["AIQuotaWidgetExtension"])
    ],
    targets: [
        .target(
            name: "QuotaCore",
            path: "Sources/QuotaCore",
            resources: [.copy("Resources/ProviderLogos")]
        ),
        .executableTarget(
            name: "AIQuotaApp",
            dependencies: ["QuotaCore"],
            path: "Sources/AIQuotaApp"
        ),
        .executableTarget(
            name: "AIQuotaWidgetExtension",
            dependencies: ["QuotaCore"],
            path: "Sources/AIQuotaWidget",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"])
            ]
        ),
        .testTarget(
            name: "QuotaCoreTests",
            dependencies: ["QuotaCore"],
            path: "Tests/QuotaCoreTests"
        )
    ]
)
