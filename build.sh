#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "Swift compiler not found. Install Xcode Command Line Tools: xcode-select --install" >&2
    exit 1
fi

APP="$ROOT/build/OVTasks.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SOURCES=(
    Sources/OVTasksApp/OVTasksApp.swift
    Sources/OVTasksApp/Preview/PreviewData.swift
    Sources/OVTasksApp/Views/DashboardView.swift
    Sources/OVTasksApp/Settings/PreviewSettingsView.swift
    Sources/OVTasksApp/ClickUp/ClickUpConnectionStore.swift
    Sources/OVTasksCore/Models/TaskModels.swift
    Sources/OVTasksCore/Metrics/MetricsCalculator.swift
    Sources/OVTasksCore/Events/SnapshotDiffer.swift
    Sources/OVTasksCore/Sync/SyncPlanner.swift
    Sources/OVTasksCore/Persistence/SQLiteSnapshotStore.swift
    Sources/OVTasksCore/Providers/ProviderAdapter.swift
    Sources/OVTasksCore/Providers/ClickUpReadClient.swift
    Sources/OVTasksCore/Security/ClickUpKeychain.swift
    Sources/OVTasksCore/Demo/CoreDemoFactory.swift
)

echo "Building OV Tasks M3B (ClickUp manual read-only connection + synthetic demo fallback)..."
xcrun --sdk macosx swiftc \
    -parse-as-library \
    -target "$(uname -m)-apple-macosx14.0" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Security \
    -lsqlite3 \
    -O \
    $SOURCES \
    -o "$APP/Contents/MacOS/OVTasks"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>pt_BR</string>
    <key>CFBundleDisplayName</key><string>OV Tasks M3B Developer Preview</string>
    <key>CFBundleExecutable</key><string>OVTasks</string>
    <key>CFBundleIdentifier</key><string>studio.ov.OVTasks.preview</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>OVTasks</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist"

# Optional ad-hoc local signing; this is NOT Apple Developer ID signing or notarization.
if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$APP"
fi

echo ""
echo "Local preview created at: $APP"
echo "Open with:"
echo "  open \"$APP\""
echo ""
echo "ClickUp: explicit read-only connection and manual sync; tokens only in Keychain.\nDisconnected mode: synthetic M2.5 demo. No notifications or background polling."
