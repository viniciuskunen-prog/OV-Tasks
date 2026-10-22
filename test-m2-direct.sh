#!/bin/zsh
# M2 direct-Swift regression tests; bypass SwiftPM manifest loading on machines
# affected by a mismatched Command Line Tools PackageDescription library.
# This does not replace XCTest and must not be presented as a full release gate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Apple Swift compiler is unavailable; check Command Line Tools." >&2
  exit 1
fi

OUT="$ROOT/.build/m2-direct-smoke"
mkdir -p "$OUT"

echo "Building OVTasksCore regression runner with swiftc (no Swift Package Manager)..."
xcrun swiftc \
  -parse-as-library \
  -module-name OVTasksCoreSmoke \
  -target "$(uname -m)-apple-macosx14.0" \
  -lsqlite3 \
  Sources/OVTasksCore/Models/TaskModels.swift \
  Sources/OVTasksCore/Metrics/MetricsCalculator.swift \
  Sources/OVTasksCore/Events/SnapshotDiffer.swift \
  Sources/OVTasksCore/Sync/SyncPlanner.swift \
  Sources/OVTasksCore/Persistence/SQLiteSnapshotStore.swift \
  Tests/M2StandaloneSmoke.swift \
  -o "$OUT/OVTasksM2Smoke"

echo "Running synthetic-data regression checks..."
"$OUT/OVTasksM2Smoke"

echo ""
echo "Direct Swift smoke checks succeeded. XCTest / 'swift test' remains pending."
