# Activity and notification policy

**Status: proposed behavior, not running yet.**

## Overview
Activity events are not identical to macOS notifications. The feed may show low-priority changes that should not interrupt work. All notifications are local via `UNUserNotificationCenter` in the default mode and include a durable task/source link where available.

## Proposed priorities
- **Urgent:** selected task becomes overdue; due in 2h when assigned to current user; relevant urgent BLOCKED status.
- **Important:** due within 24h; newly assigned task; configured review/status transition.
- **Informational:** ordinary progress/status change, completion, comments not considered urgent. Default feed-only.
Priority evaluation is configurable; provider availability is not itself a “task overdue” alert.

## UX rules
Request macOS notification permission at onboarding when it makes sense, not silently at app start. If denied, show a system-settings path; don't repeatedly re-prompt. Quiet hours and source/category muting. An optional privacy mode hides task names in notifications.

Click a notification → look up event ID in local data → validate task's HTTPS URL and provider host → open original task. If source URL is unavailable, open local feed and clearly indicate why.

## Anti-spam
- Persist `deliveryKey` and `deliveredAt`; retries do not redeliver an already delivered alert.
- A `due in 24h` notification and a `due in 2h` notification are distinct thresholds, each once per task due-date revision.
- Coalesce rapid successive status changes with a short debounce and avoid redundant intermediate notifications.
- On wake/resume after extended sleep, reconcile snapshot then present a digest/summary rather than a storm.
- First import suppresses historical event notifications.
- Quiet-hour delivery: either defer or feed-only according to explicit policy; never silently leak confidential details.

## Reliability
A popover being closed must not pause the scheduler. A Mac that is asleep, shut down, offline, or disallowed by the OS **cannot guarantee immediate alerts**. The user must see “last successful sync” and reauth failures. Optional server push, if added later, needs a documented trust/security model.

## Testing
Permission granted/denied, URL action, wrong/removed event, repeated polling, app restart, due-time changes, timezone/DST, bulk history import, quiet hours, provider outage, wake from sleep and unread-count behavior.
