#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREVIEW_DIR="$(mktemp -d)"
trap 'rm -rf "$PREVIEW_DIR"' EXIT

python3 - "$ROOT_DIR" "$PREVIEW_DIR" <<'PY'
from pathlib import Path
import sys

root, output = map(Path, sys.argv[1:])
core = output / "core"
core.mkdir()
for source in (root / "Sources/QuotaCore").glob("*.swift"):
    text = source.read_text()
    if source.name == "PreferencesStore.swift":
        start = text.index("    public init() {", text.index("public final class PreferencesStore"))
        end = text.index("    public nonisolated static func loadFromDisk", start)
        text = text[:start] + "    public init() { self.data = QuotaPreferencesData() }\n\n" + text[end:]
        text = text.replace("            save()\n", "", 1)
    (core / source.name).write_text(text)

text = (root / "Sources/AIQuotaApp/QuotaViewModel.swift").read_text()
start = text.index("    init() {")
end = text.index("    func refreshAll()", start)
text = text[:start] + "    init(dashboard: QuotaDashboardState) { self.dashboard = dashboard }\n\n" + text[end:]
(output / "QuotaViewModel.swift").write_text(text)

text = (root / "Sources/AIQuotaApp/AIQuotaApp.swift").read_text()
text = text[text.index("private struct RichMenuBarStatusCanvas:"):]
text = text.replace("private struct RichMenuBarStatusCanvas:", "struct RichMenuBarStatusCanvas:", 1)
(output / "MenuBarCanvas.swift").write_text("import SwiftUI\n" + text)

text = (root / "Sources/AIQuotaWidget/AIQuotaWidget.swift").read_text()
text = text.replace("@main\nstruct AIQuotaWidgetsBundle", "struct AIQuotaWidgetsBundle", 1)
text = text.replace("@Environment(\\.widgetFamily) var family", "var family: WidgetFamily = .systemSmall", 1)
(output / "Widget.swift").write_text(text)
PY

swiftc -whole-module-optimization \
    -sdk "$(xcrun --show-sdk-path)" \
    -target "$(uname -m)-apple-macosx14.0" \
    "$PREVIEW_DIR"/core/*.swift \
    "$PREVIEW_DIR"/*.swift \
    "$ROOT_DIR/Sources/AIQuotaApp/DashboardViews.swift" \
    "$ROOT_DIR/Sources/AIQuotaApp/SettingsView.swift" \
    "$ROOT_DIR/scripts/previews/PreviewRenderer.swift" \
    -o "$PREVIEW_DIR/render-previews"

cp -R "$ROOT_DIR/Sources/QuotaCore/Resources/ProviderLogos" "$PREVIEW_DIR/"
"$PREVIEW_DIR/render-previews" "$ROOT_DIR"
