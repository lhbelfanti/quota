import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case es = "es"
    case en = "en"
    case de = "de"
    case it = "it"
    case pt = "pt"

    public var id: String { rawValue }

    public var shortCode: String {
        rawValue.uppercased()
    }

    public var flagEmoji: String {
        switch self {
        case .es: return "🇪🇸"
        case .en: return "🇺🇸"
        case .de: return "🇩🇪"
        case .it: return "🇮🇹"
        case .pt: return "🇧🇷"
        }
    }

    public var displayName: String {
        switch self {
        case .es: return "Español"
        case .en: return "English"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .pt: return "Português"
        }
    }
}

public enum L10n {
    // MARK: - General & Header
    public static func updatedAt(_ time: String, _ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Actualizado \(time)"
        case .en: return "Updated \(time)"
        case .de: return "Aktualisiert \(time)"
        case .it: return "Aggiornato \(time)"
        case .pt: return "Atualizado \(time)"
        }
    }

    public static func refreshTooltip(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Actualizar cuotas ahora"
        case .en: return "Refresh quotas now"
        case .de: return "Kontingente jetzt aktualisieren"
        case .it: return "Aggiorna quote ora"
        case .pt: return "Atualizar cotas agora"
        }
    }

    public static func settingsTooltip(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Personalizar barra superior, idioma e IAs visibles"
        case .en: return "Customize menu bar, language, and visible AIs"
        case .de: return "Menüleiste, Sprache und sichtbare KIs anpassen"
        case .it: return "Personalizza barra dei menu, lingua e IA visibili"
        case .pt: return "Personalizar barra superior, idioma e IAs visíveis"
        }
    }

    public static func quit(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Salir"
        case .en: return "Quit"
        case .de: return "Beenden"
        case .it: return "Esci"
        case .pt: return "Sair"
        }
    }

    public static func back(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Volver"
        case .en: return "Back"
        case .de: return "Zurück"
        case .it: return "Indietro"
        case .pt: return "Voltar"
        }
    }

    public static func settingsTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Configuración"
        case .en: return "Settings"
        case .de: return "Einstellungen"
        case .it: return "Impostazioni"
        case .pt: return "Configurações"
        }
    }

    // MARK: - Display Modes
    public static func modeBadge(_ mode: QuotaDisplayMode, _ lang: AppLanguage) -> String {
        switch (mode, lang) {
        case (.remaining, .es): return "MODO DISP. %"
        case (.remaining, .en): return "AVAIL. % MODE"
        case (.remaining, .de): return "VERFÜGB. %"
        case (.remaining, .it): return "MODO DISP. %"
        case (.remaining, .pt): return "MODO DISP. %"

        case (.used, .es): return "MODO USADO %"
        case (.used, .en): return "USED % MODE"
        case (.used, .de): return "VERBRAUCHT %"
        case (.used, .it): return "MODO USATO %"
        case (.used, .pt): return "MODO USADO %"

        case (.both, .es): return "DISP. + USADO %"
        case (.both, .en): return "AVAIL. + USED %"
        case (.both, .de): return "VERF. + VERBR. %"
        case (.both, .it): return "DISP. + USATO %"
        case (.both, .pt): return "DISP. + USADO %"
        }
    }

    public static func displayModeTitle(_ mode: QuotaDisplayMode, _ lang: AppLanguage) -> String {
        switch (mode, lang) {
        case (.remaining, .es): return "Cuota disponible (% disp.)"
        case (.remaining, .en): return "Remaining quota (% avail.)"
        case (.remaining, .de): return "Verfügbares Kontingent (% verf.)"
        case (.remaining, .it): return "Quota disponibile (% disp.)"
        case (.remaining, .pt): return "Cota disponível (% disp.)"

        case (.used, .es): return "Cuota usada (% usado — estilo CLI)"
        case (.used, .en): return "Used quota (% used — CLI style)"
        case (.used, .de): return "Verbrauchtes Kontingent (% verbr. — CLI)"
        case (.used, .it): return "Quota usata (% usato — stile CLI)"
        case (.used, .pt): return "Cota usada (% usado — estilo CLI)"

        case (.both, .es): return "Ambos (disponible + usado)"
        case (.both, .en): return "Both (available + used)"
        case (.both, .de): return "Beides (verfügbar + verbraucht)"
        case (.both, .it): return "Entrambi (disponibile + usato)"
        case (.both, .pt): return "Ambos (disponível + usado)"
        }
    }

    public static func availShort(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "disp."
        case .en: return "avail."
        case .de: return "verf."
        case .it: return "disp."
        case .pt: return "disp."
        }
    }

    public static func usedShort(_ lang: AppLanguage, compact: Bool = false) -> String {
        if compact {
            switch lang {
            case .es, .it, .pt, .en: return "u."
            case .de: return "v."
            }
        }
        switch lang {
        case .es: return "usado"
        case .en: return "used"
        case .de: return "verbr."
        case .it: return "usato"
        case .pt: return "usado"
        }
    }

    // MARK: - Menu Bar Styles
    public static func menuBarStyleTitle(_ style: MenuBarDisplayStyle, _ lang: AppLanguage) -> String {
        switch (style, lang) {
        case (.logosAndPercentages, .es): return "Logos de IA + porcentaje"
        case (.logosAndPercentages, .en): return "AI logos + percentage"
        case (.logosAndPercentages, .de): return "KI-Logos + Prozentsatz"
        case (.logosAndPercentages, .it): return "Loghi IA + percentuale"
        case (.logosAndPercentages, .pt): return "Logos de IA + porcentagem"

        case (.compactInitials, .es): return "Iniciales compactas (C · X · G)"
        case (.compactInitials, .en): return "Compact initials (C · X · G)"
        case (.compactInitials, .de): return "Kompakte Initialen (C · X · G)"
        case (.compactInitials, .it): return "Iniziali compatte (C · X · G)"
        case (.compactInitials, .pt): return "Iniciais compactas (C · X · G)"

        case (.fullNames, .es): return "Nombres + porcentaje"
        case (.fullNames, .en): return "Names + percentage"
        case (.fullNames, .de): return "Namen + Prozentsatz"
        case (.fullNames, .it): return "Nomi + percentuale"
        case (.fullNames, .pt): return "Nomes + porcentagem"

        case (.lowestOnly, .es): return "Solo la IA con menor cuota"
        case (.lowestOnly, .en): return "Lowest quota AI only"
        case (.lowestOnly, .de): return "Nur KI mit niedrigstem Kontingent"
        case (.lowestOnly, .it): return "Solo IA con quota inferiore"
        case (.lowestOnly, .pt): return "Apenas a IA com menor cota"

        case (.iconOnly, .es): return "Solo ícono (sin texto)"
        case (.iconOnly, .en): return "Icon only (no text)"
        case (.iconOnly, .de): return "Nur Symbol (kein Text)"
        case (.iconOnly, .it): return "Solo icona (senza testo)"
        case (.iconOnly, .pt): return "Apenas ícone (sem texto)"
        }
    }

    // MARK: - Pools & Windows
    public static func generalPoolTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Pool General"
        case .en: return "General Pool"
        case .de: return "Allgemeiner Pool"
        case .it: return "Pool Generale"
        case .pt: return "Pool Geral"
        }
    }

    public static func poolTitle(for poolId: String, fallback: String, _ lang: AppLanguage) -> String {
        switch poolId {
        case "claude-general", "codex-general", "agy-gemini":
            return generalPoolTitle(lang)
        case "agy-argon":
            return "Pool Gemini 4 Argon"
        case "agy-3p":
            return "Pool Claude 5.5 & GPT-OSS 120B"
        case "codex-review":
            return "Pool Code Review"
        default:
            if poolId.hasPrefix("claude-") {
                let model = fallback
                    .replacingOccurrences(of: "Pool ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return "Pool \(model)"
            }
            return fallback
        }
    }

    public static func poolSubtitle(for poolId: String, fallback: String?, _ lang: AppLanguage) -> String? {
        switch poolId {
        case "claude-general":
            return "Sonnet · Haiku · Opus base"
        case "codex-general":
            return "GPT-5 · o3 · Codex CLI"
        case "agy-gemini":
            return "Gemini 4 Hydrogen · 3.8 Flash · 2.5 Pro"
        case "agy-argon":
            return "Argon (Low / Med / High) · Orchestrator"
        case "agy-3p":
            return "Claude Opus 5.5 · Sonnet 5.5 · GPT-OSS 120B"
        case "codex-review":
            switch lang {
            case .es: return "Revisiones automáticas de PR"
            case .en: return "Automated PR code reviews"
            case .de: return "Automatische PR-Code-Reviews"
            case .it: return "Revisioni automatiche PR"
            case .pt: return "Revisões automáticas de PR"
            }
        default:
            if poolId.hasPrefix("claude-") {
                let model = poolId.replacingOccurrences(of: "claude-", with: "").capitalized
                switch lang {
                case .es: return "Presupuesto semanal dedicado para \(model)"
                case .en: return "Dedicated weekly budget for \(model)"
                case .de: return "Dediziertes Wochenbudget für \(model)"
                case .it: return "Budget settimanale dedicato per \(model)"
                case .pt: return "Orçamento semanal dedicado para \(model)"
                }
            }
            return fallback
        }
    }

    public static func categoryBadge(_ category: QuotaPoolCategory, _ lang: AppLanguage) -> String {
        switch (category, lang) {
        case (.core, _): return "CORE"
        case (.dedicated, .es): return "EXCLUSIVO"
        case (.dedicated, .en): return "DEDICATED"
        case (.dedicated, .de): return "EXKLUSIV"
        case (.dedicated, .it): return "ESCLUSIVO"
        case (.dedicated, .pt): return "EXCLUSIVO"
        case (.partner, _): return "PARTNER"
        }
    }

    public static func burstWindowBadge(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "5H · SESIÓN ACTIVA"
        case .en: return "5H · ACTIVE SESSION"
        case .de: return "5H · AKTIVE SITZUNG"
        case .it: return "5H · SESSIONE ATTIVA"
        case .pt: return "5H · SESSÃO ATIVA"
        }
    }

    public static func weeklyWindowBadge(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "7D · SEMANAL"
        case .en: return "7D · WEEKLY"
        case .de: return "7T · WÖCHENTLICH"
        case .it: return "7G · SETTIMANALE"
        case .pt: return "7D · SEMANAL"
        }
    }

    public static func dedicatedWeeklyBadge(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "7D · PRESUPUESTO SEMANAL EXCLUSIVO"
        case .en: return "7D · DEDICATED WEEKLY BUDGET"
        case .de: return "7T · EXKLUSIVES WOCHENBUDGET"
        case .it: return "7G · BUDGET SETTIMANALE ESCLUSIVO"
        case .pt: return "7D · ORÇAMENTO SEMANAL EXCLUSIVO"
        }
    }

    public static func activePoolsCount(_ count: Int, _ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "\(count) \(count == 1 ? "Pool activo" : "Pools activos")"
        case .en: return "\(count) \(count == 1 ? "active Pool" : "active Pools")"
        case .de: return "\(count) \(count == 1 ? "aktiver Pool" : "aktive Pools")"
        case .it: return "\(count) \(count == 1 ? "Pool attivo" : "Pool attivi")"
        case .pt: return "\(count) \(count == 1 ? "Pool ativo" : "Pools ativos")"
        }
    }

    // MARK: - Auth & Card States
    public static func connect(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Conectar"
        case .en: return "Connect"
        case .de: return "Verbinden"
        case .it: return "Connetti"
        case .pt: return "Conectar"
        }
    }

    public static func reconnectAccount(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Reconectar cuenta…"
        case .en: return "Reconnect account…"
        case .de: return "Konto neu verbinden…"
        case .it: return "Riconnetti account…"
        case .pt: return "Reconectar conta…"
        }
    }

    public static func signOut(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Cerrar sesión"
        case .en: return "Sign out"
        case .de: return "Abmelden"
        case .it: return "Disconnetti"
        case .pt: return "Encerrar sessão"
        }
    }

    public static func notConnected(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "No conectado. Iniciá sesión para ver tu cuota disponible."
        case .en: return "Not connected. Sign in to view your available quota."
        case .de: return "Nicht verbunden. Melde dich an, um dein Kontingent zu sehen."
        case .it: return "Non connesso. Accedi per vedere la tua quota disponibile."
        case .pt: return "Não conectado. Inicie sessão para ver sua cota disponível."
        }
    }

    public static func notConnectedShort(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "No conectado"
        case .en: return "Not connected"
        case .de: return "Nicht verbunden"
        case .it: return "Non connesso"
        case .pt: return "Não conectado"
        }
    }

    public static func signInFromMenuBar(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Iniciá sesión desde el ícono de la barra superior"
        case .en: return "Sign in from the menu bar icon"
        case .de: return "Über das Menüleisten-Symbol anmelden"
        case .it: return "Accedi dall'icona nella barra dei menu"
        case .pt: return "Inicie sessão pelo ícone da barra superior"
        }
    }

    public static func noMetricsReported(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Sin métricas reportadas en este momento"
        case .en: return "No metrics reported at the moment"
        case .de: return "Derzeit keine Metriken gemeldet"
        case .it: return "Nessuna metrica disponibile al momento"
        case .pt: return "Sem métricas reportadas no momento"
        }
    }

    // MARK: - Settings Sections
    public static func languageSectionTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Idioma / Language"
        case .en: return "Language"
        case .de: return "Sprache"
        case .it: return "Lingua"
        case .pt: return "Idioma"
        }
    }

    public static func visibleAIsSectionTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "IAs visibles en el panel y widget"
        case .en: return "Visible AIs in panel and widget"
        case .de: return "Sichtbare KIs im Panel und Widget"
        case .it: return "IA visibili nel pannello e nel widget"
        case .pt: return "IAs visíveis no painel e no widget"
        }
    }

    public static func topBarSectionTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Barra superior (Top Bar)"
        case .en: return "Menu Bar (Top Bar)"
        case .de: return "Menüleiste (Top Bar)"
        case .it: return "Barra dei menu (Top Bar)"
        case .pt: return "Barra superior (Top Bar)"
        }
    }

    public static func displayFormatLabel(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Formato de visualización"
        case .en: return "Display format"
        case .de: return "Anzeigeformat"
        case .it: return "Formato di visualizzazione"
        case .pt: return "Formato de exibição"
        }
    }

    public static func topBarAIsLabel(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "IAs mostradas en la barra superior"
        case .en: return "AIs shown in the menu bar"
        case .de: return "In der Menüleiste angezeigte KIs"
        case .it: return "IA mostrate nella barra superiore"
        case .pt: return "IAs exibidas na barra superior"
        }
    }

    public static func percentageModeSectionTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Cálculo de porcentajes"
        case .en: return "Percentage calculation"
        case .de: return "Prozentberechnung"
        case .it: return "Calcolo delle percentuali"
        case .pt: return "Cálculo de porcentagens"
        }
    }

    public static func percentageModeNote(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Nota: La statusline de Claude CLI muestra % usado del último turno, mientras que AI Quota consulta el endpoint en vivo."
        case .en: return "Note: Claude CLI's statusline shows % used from the last turn, while AI Quota queries the live endpoint."
        case .de: return "Hinweis: Die Claude-CLI-Statuszeile zeigt % verbraucht vom letzten Zug, während AI Quota den Live-Endpunkt abfragt."
        case .it: return "Nota: La statusline di Claude CLI mostra la % usata dell'ultimo turno, mentre AI Quota interroga l'endpoint in tempo reale."
        case .pt: return "Nota: A statusline do Claude CLI mostra % usado do último turno, enquanto o AI Quota consulta o endpoint ao vivo."
        }
    }

    public static func desktopWidgetSectionTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Widget de Escritorio (macOS)"
        case .en: return "Desktop Widget (macOS)"
        case .de: return "Desktop-Widget (macOS)"
        case .it: return "Widget Scrivania (macOS)"
        case .pt: return "Widget da Área de Trabalho (macOS)"
        }
    }

    public static func desktopWidgetHint(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Para agregar el widget al escritorio: hacé click derecho en el escritorio → Edit Widgets... → buscá \"AIQuota\"."
        case .en: return "To add the desktop widget: right-click on the desktop → Edit Widgets... → search for \"AIQuota\"."
        case .de: return "So fügst du das Desktop-Widget hinzu: Rechtsklick auf den Schreibtisch → Widgets bearbeiten… → nach „AIQuota“ suchen."
        case .it: return "Per aggiungere il widget alla scrivania: fai clic destro sulla scrivania → Modifica widget... → cerca \"AIQuota\"."
        case .pt: return "Para adicionar o widget à área de trabalho: clique com o botão direito na área de trabalho → Editar Widgets... → procure \"AIQuota\"."
        }
    }

    public static func systemSectionTitle(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Sistema"
        case .en: return "System"
        case .de: return "System"
        case .it: return "Sistema"
        case .pt: return "Sistema"
        }
    }

    public static func launchAtLoginLabel(_ lang: AppLanguage) -> String {
        switch lang {
        case .es: return "Iniciar automáticamente al hacer login en la Mac"
        case .en: return "Launch automatically at Mac login"
        case .de: return "Automatisch bei der Mac-Anmeldung starten"
        case .it: return "Avvia automaticamente al login sul Mac"
        case .pt: return "Iniciar automaticamente ao fazer login no Mac"
        }
    }
}
