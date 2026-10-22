#!/bin/zsh
# M2.5 local real-core integration smoke. Synthetic input only, no SwiftPM.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Swift compiler unavailable. Check Apple Command Line Tools." >&2
  exit 1
fi

OUT="$ROOT/.build/m25-direct-smoke"
mkdir -p "$OUT"

echo "Compiling M2.5 provider contract and core-backed synthetic preview..."
xcrun swiftc \
  -parse-as-library \
  -module-name OVTasksM25Smoke \
  -target "$(uname -m)-apple-macosx14.0" \
  -lsqlite3 \
  Sources/OVTasksCore/Models/TaskModels.swift \
  Sources/OVTasksCore/Metrics/MetricsCalculator.swift \
  Sources/OVTasksCore/Events/SnapshotDiffer.swift \
  Sources/OVTasksCore/Sync/SyncPlanner.swift \
  Sources/OVTasksCore/Persistence/SQLiteSnapshotStore.swift \
  Sources/OVTasksCore/Providers/ProviderAdapter.swift \
  Sources/OVTasksCore/Demo/CoreDemoFactory.swift \
  Tests/M25StandaloneSmoke.swift \
  -o "$OUT/OVTasksM25Smoke"

echo "Running real-core demo and provider pagination regression..."
"$OUT/OVTasksM25Smoke"
