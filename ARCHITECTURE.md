# Architecture

Daybar is a single native Swift executable with no third-party dependencies. Responsibilities are separated by files rather than by packages; the app is small enough that additional modules would add little value.

## Data and event flow

```text
UserDefaults ↔ PreferencesRepository ↔ Store ↔ SwiftUI views
                                        ↑
                           Clock / minute timer / wake
                                        ↓
                       Schedule + ReminderScheduler
                                        ↓
                             ReminderPresenter
```

`App.swift` connects the menu bar, store, and reminder presenter. It owns application lifecycle and system event subscriptions. Termination stops scheduling, cancels pending reminder dismissal, and removes observers.

## Scheduling

`Schedule.swift` is independent of AppKit and SwiftUI. It uses an explicit calendar and date to derive concrete occurrences for a local calendar day. The timeline and reminder scheduler use those same occurrences, so daylight-saving changes cannot give them conflicting notions of the current activity.

A nonexistent local time moves to the next valid local time. A repeated local time uses its first occurrence. Equal scheduled times use activity IDs as a deterministic tie-breaker. When several scheduled times resolve to one instant, the latest scheduled minute wins for the upcoming activity, current activity, and reminder; reminders do not stack.

`ReminderScheduler` tracks the last check and recently emitted occurrence identities. It returns at most one reminder per check, skips yesterday's backlog, and suppresses replay when the clock moves backwards. The replay guard is in-memory; startup begins at the current time without replaying past events.

`Store` arms a single timer for the next minute boundary, in common run-loop modes. It checks immediately on wake and clock/time-zone changes. Quiet mode consumes transitions without showing them. Editing a routine refreshes the timeline and rebases scheduling, so an edit does not create a retroactive reminder.

## State and persistence

`Store` runs on the main actor. Its clock, calendar, preferences repository, and login manager can be supplied by tests. Construction loads state without starting a timer; application startup explicitly starts it. Tests use an isolated defaults suite and a fake login manager, never the user's routine or login registration.

`PreferencesRepository` retains the original `blocks`, `appearance`, and `animated` keys and encoding formats. Upgrades preserve existing settings. Decoding validates time ranges, weekdays, unique activity IDs, and sRGB color channels. An unreadable setting produces a visible message and a temporary fallback; the stored value remains intact until that setting is edited. Correcting one setting does not clear another setting's warning.

`LoginManager` wraps the platform login-item API. Registration errors and approval requirements are visible to the user.

## Presentation

`Dashboard`, `BlockEditor`, `ReminderCard`, and `Glass` contain presentation only. Activity bindings resolve IDs on each edit rather than retaining mutable array positions. Menu bar updates subscribe to the published timeline value and skip unchanged current activities.

`ReminderPresenter` owns its panel and cancellation task. Showing another reminder cancels the previous dismissal. The card ignores mouse events, takes no keyboard focus, and disappears automatically. Reduced-motion preferences suppress movement and the exit animation. Shared layout values keep window geometry and SwiftUI content consistent.

## Validation and limits

Tests cover time boundaries, weekdays, sleep/wake catch-up, midnight, both daylight-saving transitions, clock rollback, quiet mode, editing, persistence compatibility, malformed settings, custom colors, and login failures. Native window placement, glass rendering, login behavior, and animation still require a macOS interaction check.

UserDefaults is appropriate for a small personal routine. There is no database, remote service, notification entitlement, completion history, or synchronization layer. Introduce those only if a future feature requires them.
