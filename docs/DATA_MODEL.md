# Canonical data and metrics

**Status: core models, metric calculation and event diff implemented in M2 source; validation by local Swift tests and mapping against providers are pending.**

## Identity and scope
A source task is uniquely identified by `providerId + accountId + workspaceId? + taskId`. Provider URLs and display names are *attributes*, not durable identifiers. Scopes are selected explicitly by the user (workspace, board/list, assignment filter).

## Proposed types
```text
TaskRef {
  providerId, accountId, workspaceId?, sourceScopeId?, taskId,
  title, originalURL, sourceName,
  rawStatus, normalizedStatus,
  dueAt?, dueKind [dateTime | dateOnly], sourceTimezone?,
  completedAt?, updatedAt?, assigneeIds[], sourceRevision?
}
NormalizedStatus = OPEN | IN_PROGRESS | BLOCKED | DONE | CANCELED | UNKNOWN

ChangeEvent {
  id, taskIdentity, type, occurredAt?, detectedAt,
  previousValue?, nextValue?, importance, dedupeKey,
  readAt?, deliveredAt?, notificationId?, sourceEventId?
}
EventType =
  TASK_CREATED | STATUS_CHANGED | DUE_SOON | OVERDUE |
  DUE_DATE_CHANGED | ASSIGNED | COMMENT_ADDED |
  COMPLETED | SOURCE_UNAVAILABLE

ConnectorState {
  providerId, accountId, selectedScopeIds[], cursor?,
  lastAttemptAt?, lastSuccessAt?, backoffUntil?, errorClass?, stale
}
```

## Dashboard counting contract
Only tasks in explicitly watched scopes, authorized and eligible under selected filters participate.

- **Pending:** eligible, not DONE or CANCELED, excluding UNKNOWN by default until mapping is configured.
- **In progress:** a *subset of Pending* with IN_PROGRESS status.
- **Overdue:** a *subset of Pending* where the due instant passed. Items with no due date are not overdue.
- **Completed:** tasks with DONE status and `completedAt` during the rolling last seven 24-hour days, counted once by task identity; if the source does not expose reliable completion timestamp, label incomplete/unsupported instead of guessing.

For a date-only due date, use end-of-day of the *configured source or user's timezone* consistently; for exact timestamps compare instants. Test daylight saving gaps/overlaps where relevant. Never use “task last modified” as a substitute for actual completion time.

## Event generation
- First successful sync is a baseline: no historical TASK_CREATED or mass STATUS_CHANGED alerts.
- Diff two normalized successful snapshots, with provider-specific event IDs when available.
- Dedup by account + task + event type + revision/transition + threshold identity, persisted across restarts.
- Missing task in a partial page/API error is not a deletion.
- Distinguish source event time (`occurredAt`) from detection time (`detectedAt`).
- When deadlines change, invalidate only relevant future reminder keys; avoid duplicate old reminders.
- Cache local metadata only as necessary; never store raw provider passwords.

## M2 source contract

`TaskIdentity`, `WatchedScope`, `TaskStatus`, `TaskSummary`, `TaskDeadline` and `LocalDueDay` are pure Swift types in `Sources/OVTasksCore/Models/TaskModels.swift`. `StatusMapping` requires explicit mapping and returns UNKNOWN when unmapped. `MetricsCalculator` de-duplicates tasks by account+workspace+task ID within watched scopes and returns `completedIsComplete=false` if DONE lacks reliable `completedAt`. `SnapshotDiffer` emits changes only after the baseline; it does not assert that missing tasks were deleted. `SQLiteSnapshotStore` uses tables for scopes, tasks and events, with atomic scope replacement and schema version 1.

These are **implementation claims only**, not evidence of passing tests. [M2_CORE.md](M2_CORE.md) explains local verification and limitations.

## Migration principles
Version the database schema. Backup/recovery or reversible migration for persistent data changes. No destructive migration without test and recovery plan.
