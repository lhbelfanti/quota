import SwiftUI
import AppKit

public struct ProviderBrandLogoView: View {
    public let provider: AIProviderKind
    public var size: CGFloat

    public init(provider: AIProviderKind, size: CGFloat = 30) {
        self.provider = provider
        self.size = size
    }

    private var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }

    public var body: some View {
        Group {
            if let url = resourceBundle.url(forResource: provider.rawValue, withExtension: "png", subdirectory: "ProviderLogos"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Text(provider.menuBarSymbol)
                    .font(.system(size: size * 0.8, weight: .bold))
                    .foregroundStyle(QuotaUITheme.providerColor(provider))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(provider.displayName)
    }
}
