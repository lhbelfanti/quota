import SwiftUI

struct ProviderCardView: View {
    let snapshot: ProviderQuotaSnapshot
    let displayMode: QuotaDisplayMode
    let language: AppLanguage
    let isSigningIn: Bool
    let onSignIn: () -> Void
    let onSignOut: () -> Void

    private var brandColor: Color {
        QuotaUITheme.providerColor(snapshot.provider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                ProviderBrandLogoView(provider: snapshot.provider, size: 32)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(snapshot.provider.displayName)
                            .font(.subheadline.weight(.semibold))

                        if let plan = snapshot.planTier, !plan.isEmpty {
                            Text(plan)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(brandColor.opacity(0.18), in: Capsule())
                                .foregroundStyle(brandColor)
                        }
                    }

                    Text(snapshot.accountLabel ?? snapshot.provider.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                actionButton
            }

            // Body based on authState
            switch snapshot.authState {
            case .authenticated:
                let pools = snapshot.pools
                if pools.isEmpty {
                    Text(L10n.noMetricsReported(language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(pools) { pool in
                            QuotaPoolCardView(
                                pool: pool,
                                providerColor: brandColor,
                                compact: false,
                                displayMode: displayMode,
                                language: language
                            )
                        }
                    }
                }

                if let extra = snapshot.extraInfo {
                    Text(extra)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

            case .unauthenticated:
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                    Text(L10n.notConnected(language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .expired:
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(snapshot.errorMessage ?? L10n.notConnected(language))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

            case .error:
                HStack(spacing: 6) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text(snapshot.errorMessage ?? "Error")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionButton: some View {
        if isSigningIn {
            ProgressView()
                .controlSize(.small)
        } else {
            switch snapshot.authState {
            case .authenticated:
                Menu {
                    Button(L10n.reconnectAccount(language), action: onSignIn)
                    Divider()
                    Button(L10n.signOut(language), role: .destructive, action: onSignOut)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 22)

            case .unauthenticated, .expired, .error:
                Button(action: onSignIn) {
                    Label(L10n.connect(language), systemImage: "arrow.up.right.square")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(brandColor)
                .controlSize(.small)
            }
        }
    }
}

struct DashboardWindowView: View {
    @ObservedObject var viewModel: QuotaViewModel
    @ObservedObject var preferences: PreferencesStore
    var isPopover: Bool = true

    @State private var showingSettings = false

    private var lang: AppLanguage {
        preferences.data.language
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showingSettings {
                SettingsPanelView(
                    preferences: preferences,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showingSettings = false
                        }
                    }
                )
            } else {
                mainDashboardContent
            }
        }
        .padding(14)
        .frame(width: 445)
        .frame(minHeight: 740, maxHeight: 900)
    }

    @ViewBuilder
    private var mainDashboardContent: some View {
        // Top bar
        HStack(spacing: 10) {
            if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
               let nsImg = NSImage(contentsOf: iconURL) {
                Image(nsImage: nsImg)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("AI Quota")
                        .font(.headline.weight(.bold))

                    Text(L10n.modeBadge(preferences.data.quotaDisplayMode, lang))
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)

                    // Indicador del idioma seleccionado en el menú principal
                    HStack(spacing: 3) {
                        Text(lang.flagEmoji)
                            .font(.system(size: 9))
                        Text(lang.shortCode)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(.primary)
                    .help("\(L10n.languageSectionTitle(lang)): \(lang.displayName)")
                }

                Text(L10n.updatedAt(formattedTime(viewModel.dashboard.lastRefreshedAt), lang))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    Task { await viewModel.refreshAll() }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.refreshTooltip(lang))

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showingSettings = true
                    }
                } label: {
                    Label(L10n.settingsTitle(lang), systemImage: "gearshape.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(L10n.settingsTooltip(lang))
            }
        }

        if let banner = viewModel.statusBanner {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text(banner)
                    .font(.caption)
                Spacer()
                Button {
                    viewModel.statusBanner = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }

        ScrollView {
            VStack(spacing: 10) {
                ForEach(preferences.data.visibleProviders) { kind in
                    let snap = viewModel.dashboard.snapshot(for: kind)
                    ProviderCardView(
                        snapshot: snap,
                        displayMode: preferences.data.quotaDisplayMode,
                        language: lang,
                        isSigningIn: viewModel.signingInProvider == kind,
                        onSignIn: { viewModel.signIn(kind) },
                        onSignOut: { viewModel.signOut(kind) }
                    )
                }
            }
        }
        .frame(minHeight: 630, maxHeight: 790)

        if isPopover {
            Divider()

            HStack {
                HStack(spacing: 4) {
                    Text(lang.flagEmoji)
                        .font(.system(size: 11))
                    Text(lang.displayName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "power")
                            .font(.system(size: 10, weight: .bold))
                        Text(L10n.quit(lang))
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .foregroundStyle(.white)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.90, green: 0.22, blue: 0.21),
                                        Color(red: 0.78, green: 0.15, blue: 0.15)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .help(L10n.quit(lang))
            }
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
