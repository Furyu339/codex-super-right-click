#!/usr/bin/env zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build-manual"
APP="$BUILD/Codex RightClick.app"
APPEX="$APP/Contents/PlugIns/CodexRightClickExtension.appex"
INSTALL_APP="/Applications/Codex RightClick.app"

pkill -f "/Applications/Codex RightClick.app" 2>/dev/null || true
pkill -f "CodexRightClick" 2>/dev/null || true
pkill -f "CodexRightClickExtension" 2>/dev/null || true

rm -rf "$APP"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/PlugIns" "$APPEX/Contents/MacOS"

cat > "$BUILD/main.swift" <<'SWIFT'
import Foundation

@_silgen_name("NSExtensionMain")
func NSExtensionMain(
    _ argc: Int32,
    _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> Int32

_ = NSExtensionMain(CommandLine.argc, CommandLine.unsafeArgv)
SWIFT

cd "$ROOT"

swiftc -emit-executable -module-name CodexRightClickExtension \
  build-manual/main.swift \
  FlickerExtension/FinderSync.swift \
  Flicker/Shared/AppEntry.swift \
  Flicker/Shared/MenuSettings.swift \
  Flicker/Shared/SharedStore.swift \
  Flicker/Shared/Logger.swift \
  -framework Cocoa -framework FinderSync \
  -o "$APPEX/Contents/MacOS/CodexRightClickExtension"

swiftc -emit-executable -module-name CodexRightClick \
  Flicker/App/AboutView.swift \
  Flicker/App/SettingsView.swift \
  Flicker/App/GeneralSettingsPanel.swift \
  Flicker/App/AppSettings.swift \
  Flicker/App/SidebarView.swift \
  Flicker/App/AppMenuBar.swift \
  Flicker/App/URLOpener.swift \
  Flicker/App/AppEntryEditor.swift \
  Flicker/App/AppEntryStore.swift \
  Flicker/App/ActionControlPanel.swift \
  Flicker/App/AppActions.swift \
  Flicker/App/OpenWithPanel.swift \
  Flicker/App/AppDelegate.swift \
  Flicker/App/ContentView.swift \
  Flicker/App/FlickerApp.swift \
  Flicker/Shared/AppEntry.swift \
  Flicker/Shared/MenuSettings.swift \
  Flicker/Shared/SharedStore.swift \
  Flicker/Shared/Logger.swift \
  -framework SwiftUI -framework AppKit -framework FinderSync -framework ServiceManagement \
  -o "$APP/Contents/MacOS/CodexRightClick"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
  <key>CFBundleDisplayName</key><string>Codex RightClick</string>
  <key>CFBundleExecutable</key><string>CodexRightClick</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>local.codex.rightclick</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Codex RightClick</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeRole</key><string>Viewer</string>
      <key>CFBundleURLName</key><string>local.codex.rightclick</string>
      <key>CFBundleURLSchemes</key><array><string>codexrightclick</string></array>
    </dict>
  </array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><false/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict>
</plist>
PLIST

cat > "$APPEX/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
  <key>CFBundleDisplayName</key><string>Codex RightClick</string>
  <key>CFBundleExecutable</key><string>CodexRightClickExtension</string>
  <key>CFBundleIdentifier</key><string>local.codex.rightclick.extension</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>CodexRightClickExtension</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionAttributes</key><dict/>
    <key>NSExtensionPointIdentifier</key><string>com.apple.FinderSync</string>
    <key>NSExtensionPrincipalClass</key><string>CodexRightClickExtension.FinderSync</string>
  </dict>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict>
</plist>
PLIST

cp "$ROOT/Flicker/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
if [[ -x /opt/homebrew/bin/7zz ]]; then
  cp /opt/homebrew/bin/7zz "$APP/Contents/Resources/7zz"
  chmod +x "$APP/Contents/Resources/7zz"
fi

/usr/bin/codesign --force --sign - --entitlements "$ROOT/FlickerExtension/FlickerExtension.entitlements" "$APPEX"
/usr/bin/codesign --force --sign - --entitlements "$ROOT/Flicker/Resources/Flicker.entitlements" "$APP"

if [[ -d "$INSTALL_APP" ]]; then
  rm -rf "$INSTALL_APP"
fi
cp -R "$APP" "$INSTALL_APP"

pluginkit -r "$INSTALL_APP/Contents/PlugIns/CodexRightClickExtension.appex" 2>/dev/null || true
pluginkit -a "$INSTALL_APP/Contents/PlugIns/CodexRightClickExtension.appex"
pluginkit -e use -i local.codex.rightclick.extension
killall Finder 2>/dev/null || true
open "$INSTALL_APP"
rm -rf "$BUILD"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
killall sharedfilelistd 2>/dev/null || true

echo "Installed $INSTALL_APP"
pluginkit -m -i local.codex.rightclick.extension -A -D -vv
