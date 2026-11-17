import SwiftUI

struct SettingsPanelView: View {
    @ObservedObject var preferences: PreferencesStore
    let dashboard: QuotaDashboardState
    var onBack: () -> Void

    private var lang: AppLanguage {
        preferences.data.language
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Button(action: onBack) {
                    Label(L10n.back(lang), systemImage: "chevron.left")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Text(L10n.settingsTitle(lang))
                    .font(.headline.weight(.bold))

                Spacer()

                // Balance spacing
                Color.clear.frame(width: 58, height: 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Section 1: Idioma
                    settingsCard(title: L10n.languageSectionTitle(lang), icon: "globe") {
                        Picker(L10n.languageSectionTitle(lang), selection: $preferences.data.language) {
                            ForEach(AppLanguage.allCases) { item in
                                Text("\(item.flagEmoji)  \(item.displayName) (\(item.shortCode))")
                                    .tag(item)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                    }

                    // Section 2: Proveedores visibles
                    settingsCard(title: L10n.visibleAIsSectionTitle(lang), icon: "cpu") {
                        ForEach(AIProviderKind.allCases) { kind in
                            Toggle(isOn: Binding(
                                get: { preferences.isProviderVisible(kind) },
                                set: { newVal in
                                    preferences.setProviderVisible(kind, visible: newVal)
                                }
                            )) {
                                HStack(spacing: 8) {
                                    ProviderBrandLogoView(provider: kind, size: 20)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(kind.displayName)
                                            .font(.caption.weight(.semibold))
                                        Text(kind.subtitle)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                    }

                    // Section 3: Top Bar (Menu Bar)
                    settingsCard(title: L10n.topBarSectionTitle(lang), icon: "menubar.rectangle") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.displayFormatLabel(lang))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker("Style", selection: $preferences.data.menuBarStyle) {
                                ForEach(MenuBarDisplayStyle.allCases) { style in
                                    Text(style.localizedTitle(lang)).tag(style)
                                }
                            }
                            .labelsHidden()
                            .controlSize(.small)

                            if preferences.data.menuBarStyle != .iconOnly {
                                Divider()
                                Text(L10n.topBarAIsLabel(lang))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 12) {
                                    ForEach(AIProviderKind.allCases) { kind in
                                        Toggle(isOn: Binding(
                                            get: { preferences.isMenuBarProviderEnabled(kind) },
                                            set: { preferences.setMenuBarProviderEnabled(kind, enabled: $0) }
                                        )) {
                                            HStack(spacing: 4) {
                                                ProviderBrandLogoView(provider: kind, size: 15)
                                                Text(kind.displayName)
                                                    .font(.caption)
                                            }
                                        }
                                        .toggleStyle(.checkbox)
                                        .controlSize(.small)
                                    }
                                }
                            }
                        }
                    }

                    // Section 4: Cuotas del resumen (7d vs 7d + 5h) y Pools por IA
                    settingsCard(title: L10n.summaryWindowSectionTitle(lang), icon: "clock.badge.checkmark") {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("SummaryWindow", selection: $preferences.data.summaryWindowMode) {
                                ForEach(SummaryWindowMode.allCases) { winMode in
                                    Text(winMode.localizedTitle(lang)).tag(winMode)
                                }
                            }
                            .labelsHidden()
                            .controlSize(.small)

                            if preferences.data.summaryWindowMode == .weeklyAndBurst {
                                Text(L10n.dualWindowLayoutStyleLabel(lang))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)

                                Picker("DualWindowStyle", selection: $preferences.data.dualWindowLayoutStyle) {
                                    ForEach(DualWindowLayoutStyle.allCases) { layoutStyle in
                                        Text(layoutStyle.localizedTitle(lang)).tag(layoutStyle)
                                    }
                                }
                                .labelsHidden()
                                .controlSize(.small)
                            }

                            Divider()

                            Text(L10n.preferredPoolSectionTitle(lang))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(L10n.preferredPoolSectionHint(lang))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            ForEach(AIProviderKind.allCases) { kind in
                                let pools = ModelCatalog.selectablePools(for: dashboard.snapshot(for: kind))
                                let selected = preferences.data.menuBarPoolIds(for: kind).filter { id in pools.contains { $0.id == id } }
                                let selectedIds = selected.isEmpty ? pools.prefix(1).map(\.id) : selected
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        ProviderBrandLogoView(provider: kind, size: 16)
                                        Text(kind.displayName)
                                            .font(.caption.weight(.semibold))
                                    }

                                    ForEach(pools) { pool in
                                        Toggle(isOn: Binding(
                                            get: { selectedIds.contains(pool.id) },
                                            set: { preferences.setMenuBarPool(pool.id, for: kind, selected: $0) }
                                        )) {
                                            Text(L10n.poolOptionLabel(pool, lang))
                                                .font(.caption)
                                        }
                                        .disabled(selectedIds.count == 1 && selectedIds.contains(pool.id))
                                        .toggleStyle(.checkbox)
                                        .controlSize(.small)
                                        .padding(.leading, 22)
                                    }
                                }
                            }
                        }
                    }

                    // Section 5: Modo de porcentaje (% Disponible vs % Usado vs Ambos)
                    settingsCard(title: L10n.percentageModeSectionTitle(lang), icon: "percent") {
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("Mode", selection: $preferences.data.quotaDisplayMode) {
                                ForEach(QuotaDisplayMode.allCases) { mode in
                                    Text(mode.localizedTitle(lang)).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .controlSize(.small)

                            Text(L10n.percentageModeNote(lang))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Section 5: Widget nativo de Escritorio
                    settingsCard(title: L10n.desktopWidgetSectionTitle(lang), icon: "widget.small") {
                        Text(L10n.desktopWidgetHint(lang))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }

                    // Section 6: Sistema (Launch at Login)
                    settingsCard(title: L10n.systemSectionTitle(lang), icon: "power.circle") {
                        Toggle(L10n.launchAtLoginLabel(lang), isOn: Binding(
                            get: { preferences.data.launchAtLogin },
                            set: { preferences.setLaunchAtLogin($0) }
                        ))
                        .font(.caption.weight(.medium))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }
            }
            .frame(minHeight: 580, maxHeight: 760)
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)

            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
