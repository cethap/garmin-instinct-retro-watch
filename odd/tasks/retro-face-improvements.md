# Retro face improvements

## Objective

Improve the Instinct 2 retro watch face across functional correctness, performance/memory, and aesthetics, and add three small features (step-goal bar, charging indicator, phone-disconnected indicator) without losing the existing design identity (Yeshua logo, pixel fonts, battery, centered time, steps/HR row, date in the subscreen).

## Problem

- Steps >= 10,000 render with integer division (`12345` -> `12.0K`), and a `null` step count crashes `onUpdate`.
- Heart rate reads `ActivityMonitor.Info.currentHeartRate`, which does not exist (dead branch); the value never resets to `--` and can be up to a minute stale.
- Time ignores the device 12/24h setting.
- The app is still named `testwatch`.
- All 8 battery bitmaps stay loaded in memory; day-name array is rebuilt on every update; unused resources, import and permission ship with the app.
- Date and icons are placed with magic numbers compensating for transparent icon padding.

## Why

Watch faces run under tight memory and CPU budgets and are visible all day; wrong numbers or a crash on the main screen are the most visible defects possible.

## Scope

Authorized by the user ("dale con todo, incluidas las ideas del punto 11"):

- Functional fixes (steps, HR, 12/24h, app name).
- Performance/cleanup (procedural battery, constant day names, dead resources, unused permission/import).
- Aesthetics (subscreen-anchored date, layout constants without padding compensation).
- Features: step-goal progress bar, charging bolt, phone-disconnected indicator.

Out of scope: new device targets, user settings/properties, localization, changing the app UUID.

## Constraints

- Target: Instinct 2 (176x176 monochrome MIP, subscreen top-right), `minApiLevel` 3.4.0.
- Connect IQ SDK 9.2.0 became available mid-feature (user installed it during T9). Builds use the keg-only `openjdk@17` via `PATH` and a throwaway developer key in the session scratchpad (never committed). Earlier tasks (T1-T7) were first verified structurally, then by the T9 build.
- Keep the app UUID unchanged (changing it creates a different app on the device/store).
- Commits: Conventional Commits, no AI attribution.

## Delivery

- Strategy: `ask-on-risk` (default). Forecast: ~300 authored changed lines (under the ~400 budget) -> single branch/PR.
- User decision when the budget was exceeded: **single PR** (`single-pr`), no chained PRs.
- Push and PR creation remain the user's decision.
- RDD: the user gave standing consent ("RDD granted hasta que el riesgo sea bajo"): medium/high consent envelopes run the `granted` invocation and are reported.
- Base (first reviewed boundary): `ad09682`.

## Tasks

| ID | Task | Route | Status |
|----|------|-------|--------|
| T1 | `fix`: steps float division and >=100K, null-safe steps, live HR via `Activity.getActivityInfo()` with history fallback and `--` reset, 12/24h support | inline (1 non-trivial file, full context already held) | [x] c108f02 (assess: medium, under_budget) |
| T2 | `chore`: rename app `testwatch` -> `Retro Instinct` (string, App class/file, manifest entry; UUID unchanged) | inline (mechanical) | [x] 32f1d83 (assess: medium, under_budget) |
| T3 | `perf`: procedural battery (drop 8 SVGs), constant day names, remove `layout.xml`, `bolt.png`, `footprint.png`, `SensorHistory` import + permission | inline (1 non-trivial file + deletions) | [x] e48f097 (assess: medium, under_budget) |
| T4 | `style`: date anchored to `WatchUi.getSubscreen()`, named layout constants without padding compensation | inline (1 non-trivial file) | [x] cc74857 (assess: medium, slice_budget_reached -> review granted, approved, acknowledged) |
| T5 | `feat`: segmented step-goal progress bar | inline (1 non-trivial file) | [ ] |
| T6 | `feat`: charging bolt indicator (1-bit pixel art drawn with primitives, no SVG) | inline (1 non-trivial file) | [ ] |
| T7 | `feat`: phone-disconnected indicator (1-bit pixel art drawn with primitives, no SVG) | inline (1 non-trivial file) | [ ] |
| T9 | `test`: extract pure formatters (steps, hour, battery fill) into a module and add `(:test)` unit tests the user can run with the SDK | inline (moved code is mechanical; the test file is the only new non-trivial file) | [ ] |
| T10 | `perf`: cache the heart-rate history fallback per minute (live HR stays per update) | inline (1 small edit) | [ ] |
| T8 | `docs`: README features and build notes | inline (passive doc) | [ ] |

## Acceptance criteria

- `12345` steps renders `12.3K`; `null` steps renders `--` without crashing.
- HR shows live `currentHeartRate`, falls back to the newest valid history sample, and shows `--` when neither is available.
- 12h devices show `6:09`, 24h devices show `18:09`.
- App shows as `Retro Instinct` in the watch face list.
- No battery bitmaps loaded; battery fill is proportional to the percentage.
- No unused resources, imports or permissions remain.
- Date is centered in the subscreen on any device that reports one, with the previous position as fallback.
- Step bar, charging bolt and phone-disconnected icon render without overlapping other elements in the layout mock.

## Checks

- Test-first exception for T1-T8: no runnable RED existed (no SDK at the time). From T9 on: `monkeyc -d instinct2` app build, `monkeyc -t` unit-test build, and `monkeydo <test.prg> instinct2 -t` in the simulator.
- `xmllint --noout` on every changed XML/SVG.
- Rez reference check: every `Rez.*` used in `source/` exists in `resources/`.
- Layout mock: a scratchpad Python renderer reproduces the 176x176 frame with the real bitmap fonts to catch overlaps.
- Parent readback of each diff.
- Pending for the user: on-device check on a real Instinct 2.

## Progress

- Exploration done; API facts verified in the official docs (`ActivityMonitor.Info` has no `currentHeartRate`; `steps` is nullable; `getSubscreen()` since API 3.2.7 and supported on the Instinct 2 family; `ActivityMonitor.getHeartRateHistory` needs no permission).

- T1-T3 done. Structural checks passed per task: `xmllint` on changed XML, every `Rez.*` reference in `source/` resolves to a resource id, no leftover `SensorHistory`/battery-bitmap references.
- Layout mock built in the scratchpad (bitmap fonts + rasterized SVGs + display mask calibrated from `preview.png`); it reproduces the current preview. Chosen design: vertical 10-segment step meter left of the footprint, bolt right of the battery, crossed-phone icon left of the battery, bottom spacing 25 -> 28 so `12.3K` does not touch the HR value. A bolt inverted inside the battery fill and a horizontal bar under the time were mocked and rejected (bolt looked split; bar touched the digits).
- 12h mode shows no AM/PM marker: the time already spans up to 166 of 176 px and the subscreen has no room for a third line without crowding.
- Running count after T3: 395 changed lines (includes ~80 lines of deleted battery SVGs) -> delivery budget reached; chain strategy asked once (ask-on-risk).

- Review `review-8cb40be8abca118c` (lens: reliability) over `ad09682..cc74857`: **approved**, acknowledged, authority burned. Reviewed boundary is now `cc74857`. Advisory, non-blocking findings: `R3-untested-formatters` (WARNING) -> accepted as T9; `R3-hr-query-unthrottled` (SUGGESTION) -> accepted as T10 (live HR was already read first; only the fallback runs per update); `R3-task-status-drift` (SUGGESTION) -> fixed in this document.

## Next step

T5.
