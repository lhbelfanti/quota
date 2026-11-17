#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/AIQuota.app"
WIDGET_BUNDLE="$APP_BUNDLE/Contents/PlugIns/AIQuotaWidgetExtension.appex"
SDK="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx14.0"

echo "==> Compilando AIQuota para $TARGET..."
mkdir -p "$BUILD_DIR"
rm -rf "$APP_BUNDLE"

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$WIDGET_BUNDLE/Contents/MacOS"
mkdir -p "$WIDGET_BUNDLE/Contents/Resources"

# 0. Copiar iconos de la aplicación al bundle y al widget
if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$WIDGET_BUNDLE/Contents/Resources/AppIcon.icns"
fi
if [ -f "$ROOT_DIR/Resources/AppIcon.png" ]; then
    cp "$ROOT_DIR/Resources/AppIcon.png" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
    cp "$ROOT_DIR/Resources/AppIcon.png" "$WIDGET_BUNDLE/Contents/Resources/AppIcon.png"
fi

cp -R "$ROOT_DIR/Sources/QuotaCore/Resources/ProviderLogos" "$APP_BUNDLE/Contents/Resources/"
cp -R "$ROOT_DIR/Sources/QuotaCore/Resources/ProviderLogos" "$WIDGET_BUNDLE/Contents/Resources/"

# 1. Compilar la aplicación principal (Menu Bar)
swiftc -sdk "$SDK" -target "$TARGET" -O -whole-module-optimization \
  "$ROOT_DIR"/Sources/QuotaCore/*.swift \
  "$ROOT_DIR"/Sources/AIQuotaApp/*.swift \
  -o "$APP_BUNDLE/Contents/MacOS/AIQuotaApp"

# 2. Compilar la extensión nativa WidgetKit (.appex)
swiftc -sdk "$SDK" -target "$TARGET" -O -whole-module-optimization \
  -Xlinker -e -Xlinker _NSExtensionMain \
  "$ROOT_DIR"/Sources/QuotaCore/*.swift \
  "$ROOT_DIR"/Sources/AIQuotaWidget/*.swift \
  -o "$WIDGET_BUNDLE/Contents/MacOS/AIQuotaWidgetExtension"

# 3. Crear Info.plist de AIQuota.app
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>es</string>
    <key>CFBundleDisplayName</key>
    <string>AIQuota</string>
    <key>CFBundleExecutable</key>
    <string>AIQuotaApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.lhbelfanti.AIQuota</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AIQuota</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>CFBundleURLName</key>
            <string>com.lhbelfanti.AIQuota</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>aiquota</string>
            </array>
        </dict>
    </array>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>DTPlatformName</key>
    <string>macosx</string>
    <key>DTPlatformVersion</key>
    <string>26.0</string>
    <key>DTSDKName</key>
    <string>macosx26.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 4. Crear Info.plist de AIQuotaWidgetExtension.appex
cat > "$WIDGET_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>es</string>
    <key>CFBundleDisplayName</key>
    <string>AIQuota</string>
    <key>CFBundleExecutable</key>
    <string>AIQuotaWidgetExtension</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.lhbelfanti.AIQuota.WidgetExtension</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AIQuotaWidgetExtension</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>DTPlatformName</key>
    <string>macosx</string>
    <key>DTPlatformVersion</key>
    <string>26.0</string>
    <key>DTSDKName</key>
    <string>macosx26.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
EOF

# 5. Crear entitlements para WidgetKit (macOS exige app-sandbox en extensiones .appex)
cat > "$BUILD_DIR/widget.entitlements" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
EOF

# 6. Firmar ad-hoc primero la extensión (con entitlements) y luego la app contenedora
codesign --force --sign - --entitlements "$BUILD_DIR/widget.entitlements" "$WIDGET_BUNDLE"
codesign --force --sign - "$APP_BUNDLE"

# 7. Instalar en /Applications/AIQuota.app y registrar el plugin en PlugInKit / WidgetKit
if [ -w "/Applications" ]; then
    rm -rf "/Applications/AIQuota.app"
    cp -R "$APP_BUNDLE" "/Applications/AIQuota.app"
    touch "/Applications/AIQuota.app"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "/Applications/AIQuota.app" || true
    pluginkit -a "/Applications/AIQuota.app/Contents/PlugIns/AIQuotaWidgetExtension.appex" || true
    pluginkit -e use -i com.lhbelfanti.AIQuota.WidgetExtension || true
    echo "==> Instalado en /Applications/AIQuota.app y registrado en el selector de Widgets (Edit Widgets...)"
fi

echo "==> Bundle generado exitosamente en: $APP_BUNDLE"
