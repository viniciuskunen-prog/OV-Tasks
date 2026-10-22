# Interface and UX specification

**Status: design proposal. Screenshots and native layout are not yet validated.**

## Layout
- macOS menu bar monochrome icon, readable in light/dark mode; optional small urgent/unread marker that does not rely only on color.
- Compact anchored popover; initial design range **400–440 pt width**, up to **560–620 pt height**, to confirm on real screens and text scaling. No separate permanent main window.
- Header: **OV Tasks**; accurate state “Updated 5m ago”, “Syncing”, “Offline” or “Reconnect ClickUp”; Settings icon.
- Metrics: 4 tiles, Pending, In progress, Overdue, Completed (last 7 days). Four across when accessible; allow 2×2 when large text/limited space. Values are overlapping, not additive.
- Section **Recent activity**: filter All / Important, 10–15 compact entries, optional Show history. Internal feed scrolling is permitted; whole popover should remain compact.
- Each activity row: semantic icon, “Status changed · [task title]”, second line describing transition or deadline, relative/local timestamp, source label and explicit **Open in [provider]** text link. The link must be an actual accessibility-labeled control, never decorative underlined text.
- Footer: connected-source status, Sync now (rate-limit-safe), Settings, Quit.

## Notification examples
“Due soon · Marketing assets” / “Due in 2 hours · Open in Trello.”
“Status changed · Review landing page” / “In progress → Done · Open in ClickUp.”
Do not show confidential task names on lock screen when privacy setting requests generic text.

## States
Onboarding/no accounts; first sync in progress; empty feed; no pending tasks; partly connected; offline with cached counters; expired token; permission denied; rate-limit; provider outage; paused alerts; no relevant changes. Each conveys one helpful action without inventing success.

## Interaction and accessibility
Keyboard navigation; focus ring; VoiceOver labels; reduced motion; dynamic text sizing; at least WCAG-inspired visual contrast; dates in the user's locale/timezone; ability to navigate without mouse. Pressing an event opens **validated HTTPS original URL**; opening from a notification performs the same action.

## Design language
Minimal utility-oriented macOS UI. Prefer native materials, SF Symbols, restrained status use, spacing and typography consistent with macOS. No requirement to duplicate task platform colors or GimbalBar layout. User visual approval is a gate before connecting real accounts.

## Definition of prototype (M1)
- SwiftUI menu app launches and closes popover without terminating app.
- All dashboard, feed and empty/offline/error states rendered from **synthetic fixtures only**.
- Screenshots in both system appearances and with long titles/dynamic text.
- Link buttons shown as clickable controls pointing to a safe fixture URL (not personal task data).
- No provider tokens, network sync or notifications required in M1.
