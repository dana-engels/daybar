# Daybar

A quiet, customizable macOS menu bar companion for your daily routine. See what’s happening now, glance at what’s next, and get a brief glass reminder when it’s time to move on.

## Features

- A compact daily timeline with automatic activity transitions.
- Glass reminder cards that animate from the menu bar and fade after six seconds.
- Editable activity names, times, icons, and recurring weekdays.
- Six accent presets—Iris, Ocean, Lagoon, Sage, Amber, and Rose—plus a custom color picker.
- Optional launch at login, quiet mode, and reduced-motion support.
- Local settings with no account, analytics, network requests, or system notifications.

## Build and run

Requires macOS 14 or later and Xcode 26 or later (Swift 6.2+). macOS 26+ uses native Liquid Glass; earlier systems use native materials.

```sh
git clone https://github.com/dana-engels/daybar.git
cd daybar
swift run Daybar
```

For a standalone app:

```sh
sh scripts/package.sh
open dist/Daybar.app
```

The script creates an ad hoc signed app for local use. Developer ID signing and notarization are required for normal public app distribution. Source code is provided here; no notarized installer is included.

## Make it yours

1. Click the Daybar menu bar item to see your routine.
2. Click an activity to edit its name, time, weekdays, or icon.
3. Use the sliders button to choose a color, preview a transition, or adjust preferences.
4. Enable launch at login after placing the app at its permanent location. macOS may request approval under General → Login Items.

Changes save automatically in local UserDefaults. The repository includes a generic starter routine, not saved user settings.

## Behavior

- The current activity changes automatically at its scheduled time and remains current until the next block or midnight.
- Reminders require the app to be running. After sleep, only the latest missed transition from today appears.
- Reminder cards require no action and never record completion.
- Quiet mode silences reminders until the app quits.
- Schedule edits change the recurring routine; today-only overrides are not implemented.

## Development

```sh
swift test
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the component boundaries, scheduling rules, persistence compatibility, and test coverage.
