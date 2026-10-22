#!/bin/zsh
# Safe SwiftPM / PackageDescription diagnostics.
# Uses disposable isolated minimal packages; does NOT modify this repo,
# global developer tool selection, Command Line Tools, or Xcode.
set -euo pipefail

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ovtasks-swiftpm-probe.XXXXXXXX")"
trap 'rm -rf "$ROOT"' EXIT

echo "OV Tasks — isolated SwiftPM manifest diagnosis"
echo "Developer directory: $(xcode-select -p 2>&1 || true)"
echo "Swift executable: $(command -v swift)"
xcrun swift --version
swift package --version
if xcrun --find xctest >/dev/null 2>&1; then
    echo "Native xctest runner: found"
else
    echo "Native xctest runner: not found with active developer tools"
fi

typeset -i passed=0
typeset -i failed=0

probe () {
    local label="$1"
    local manifest="$2"
    local dir="$ROOT/$label"
    mkdir -p "$dir/Sources/Probe"
    printf '%s\n' "$manifest" > "$dir/Package.swift"
    printf 'print("probe")\n' > "$dir/Sources/Probe/main.swift"
    echo ""
    echo "Checking manifest probe: $label"
    if swift package --package-path "$dir" dump-package > "$dir/stdout.txt" 2> "$dir/stderr.txt"; then
        echo "PASS: $label — independent minimal manifest accepted"
        (( passed += 1 ))
    else
        echo "FAIL: $label — manifest failed without any OV Tasks source"
        tail -n 12 "$dir/stderr.txt"
        (( failed += 1 ))
    fi
}

probe "tools59-minimal" '// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Probe", targets: [.executableTarget(name: "Probe")])'

probe "tools59-legacy-overload" '// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Probe",
    platforms: [.macOS(.v14)],
    pkgConfig: nil,
    providers: nil,
    products: [],
    dependencies: [],
    targets: [.executableTarget(name: "Probe")],
    swiftLanguageVersions: nil,
    cLanguageStandard: nil,
    cxxLanguageStandard: nil
)'

probe "tools60-minimal" '// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Probe", targets: [.executableTarget(name: "Probe")])'

echo ""
echo "Diagnostic complete: $passed passed; $failed failed."
if (( failed > 0 )); then
    echo "At least one manifest failed. Use per-probe errors above to isolate CLT vs initializer."
fi
echo "No developer tools, application files or Git tracked sources were changed."
