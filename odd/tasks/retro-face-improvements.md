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
| T5 | `feat`: segmented step-goal progress bar | inline (1 non-trivial file) | [x] 80d2044 (assess: medium, under_budget) |
| T6 | `feat`: charging bolt indicator (1-bit pixel art drawn with primitives, no SVG) | inline (1 non-trivial file) | [x] 1a67cec (assess: medium, under_budget) |
| T7 | `feat`: phone-disconnected indicator (1-bit pixel art drawn with primitives, no SVG) | inline (1 non-trivial file) | [x] 49af187 (assess: medium, under_budget) |
| T9 | `test`: extract pure formatters (steps, hour, battery fill) into a module and add `(:test)` unit tests the user can run with the SDK | inline (moved code is mechanical; the test file is the only new non-trivial file) | [x] a204dc1 compiler-warning fixes + 295e270 tests (assess: medium, under_budget) |
| T10 | `perf`: cache the heart-rate history fallback per minute (live HR stays per update) | inline (1 small edit) | [x] d77e4aa (assess: medium, under_budget) |
| T11 | `fix`: key the HR fallback cache by epoch minute and invalidate it while live HR is used (review finding `R3-hr-fallback-minute-key-staleness`) | inline (1 small edit) | [x] this commit (build 0 warnings, 9/9 tests) |
| T12 | `style`: replace the SVG-converted Yeshua logo with a hand-drawn 64x24 1-bit PNG | inline (1 asset + 1 XML line) | [x] 570fd8d, **reverted in 28c616c**: the user did not like the redraw |
| T13 | `feat`: move the step-goal meter to a segmented ring around the date in the subscreen (user request: did not like the dots next to the footprint) | inline (1 non-trivial file) | [x] 38036f5 (build 0 warnings, 9/9 tests) |
| T14 | `fix`: keep the leading zero on the hour in 12h mode (**user request**: "me gusta que se vea el 0 antes", seeing `8:16` in the simulator) | inline (1 helper + test) | [x] 6002635 (RED `8=8` -> GREEN `8=08`, 9/9) |
| T15 | `style`: center the date's ink inside the ring (user request: it sat to the left) and move ring angles into `RetroFormat` with a test | inline (view + helper + test) | [x] fa89119 (RED: undefined symbol -> GREEN 10/10) |
| T16 | `style`: minimal pixel fixes on the original Yeshua SVG (user request: keep the original, but improve it) | inline (1 asset) | [x] approved by the user after the simulator preview ("quedó mejor"), 32 px changed |
| T17 | `style`: logo as hero (88x36, viewBox margin so the belly is not clipped, pixel fixes redone for the size), mini battery status row (bolt replaces `%` while charging, battery days dropped), phone icon moved to a data row (user request) | inline (view + helper/test + asset) | [x] 322c3dd (RED arity error -> GREEN 10/10) |
| T18 | `feat`: calories data row with a pixel-art flame (user picked calories over notifications, altitude and Body Battery) | inline (view + helper/test) | [x] f7a4fd9, **removed in T20** after the user saw it in the simulator |
| T19 | `style`: rebalance the top area after seeing it in the simulator (user request: the battery row hugged the subscreen, the logo could be larger, the calories row left too much empty space). Logo at 96x39 (3 px/unit) with pixel fixes redone; status and calories rows left-aligned at the start of the fish body (x=24); time and bottom row moved down 2px | inline (view + asset) | [x] layout commit (0 warnings, 11/11; mock: zero clipped pixels at 50%/0 kcal, charging + phone-off + 12345 kcal, and 100%/1850 kcal) |
| T20 | `style`: drop the calories row (user did not like it) and give its space to the logo: 112x46 (3.5 px/unit, pixel fixes redone, about 3px clear of the display edge per a mock search over scales 3.25 to 4.0), status row centered at x=62, phone-off icon moved between the steps and heart icons; `formatCalories` and its test removed | inline (view + helper/test removal + asset) | [x] layout commit (0 warnings, 10/10; mock: zero clipped pixels normal and charging + phone-off) |
| T21 | `style`: fill the empty bottom area (user request) with a faith symbol and a non-invasive background. After rejected options (laurel, pines, dove, Calvary, plain or dotted crosses), the user chose a 31x30 radiant cross between the stat columns (spacing 28 -> 30) plus a dithered radial vignette (4x4 Bayer, max 19% density) baked into a 176x60 PNG, keeping a 3px margin around the worst-case stats footprint. The phone-off icon moved right of the heart. Measured memory in the simulator: 20376 / 61256 bytes used | inline (view + 2 assets) | [x] cross + vignette commit (0 warnings) |
| T22 | `style`: continuous vignette (user request: the 3px exclusion around the stats looked cut out). The cut-outs are gone, there is an 18px fade-in below the time, and the stat values are drawn with a 1px black outline so they stay readable over the dots | inline (view + asset) | [x] vignette commit (0 warnings) |
| T8 | `docs`: README features and build notes | inline (passive doc) | [x] docs commit that also closes this document (assess pending at commit time) |

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

- T5-T7: bitmasks cross-checked against the mocked pixel art (`bolt match: True`, `phone match: True`); positions match the mock (bolt `clusterX + 26`, phone `clusterX - 36`, meter `centerX - spacing - 22`).
- SDK verification (T9 onward, covering all earlier tasks): `monkeyc -d instinct2` -> BUILD SUCCESSFUL. The first build showed 2 warnings (24x24 launcher icon on a 62x62 device; untyped `dayNames` container access); both were fixed in `a204dc1`, and later builds have 0 warnings. `monkeyc -t` -> BUILD SUCCESSFUL; `monkeydo ... instinct2 -t` -> **PASSED (passed=9, failed=0, errors=0)**.
- Mutation check (RED): reintroducing the original `(steps / 1000).format("%.1f")` in a scratch copy made `formatStepsTruncatesToTenthsFrom10K` FAIL with `12345=12.0K` (8 passed, 1 failed). The real code passes (GREEN).
- Simulator run of the release build: loaded on instinct2 with an empty runtime log (no exceptions). No screenshot was taken because the terminal has no screen-recording permission.
- Review `review-5b60a0611c3b44e1` (lens: reliability) over `cc74857..87e9d97`, run under the user's standing consent: **approved**, acknowledged, authority burned; reviewed boundary is now `87e9d97`. `R3-hr-fallback-minute-key-staleness` (WARNING, a real T10 bug: the `clock.min` key could replay a value from another hour) -> fixed in T11. `R3-hr-cache-untested` (SUGGESTION) -> not taken: after T11 the cache is a single comparison inside device-API code, and extracting a class only to test `!=` adds ceremony without coverage of the real risk (the key choice), which the comment now documents.
- Tooling note: the collect submission for the intended-untracked selection omitted the `--base-ref` selector and resolved the whole branch (`ad09682`) instead of the requested slice (`cc74857`). That START was not run; the preflight was re-issued with `--untracked-scope=exclude --expected-untracked-inventory=...`, which kept the slice target.
- Review `review-8a52d5d9cc171eea` over `87e9d97..7644822` (T11): **approved**, acknowledged; boundary `7644822`. `R3-001` (SUGGESTION, cache test) is the same point as `R3-hr-cache-untested`; not taken for the same reason.
- User feedback after seeing the simulator: (1) the logo converted from SVG looked off. Analysis: the 1-bit conversion broke the serif text (the `A` became a blob) and left a gap in the belly that already existed in the original SVG raster (not caused by the T4 trim). Fix in T12. (2) The vertical step dots were disliked, and the user asked for the progress to sit around the date circle. Fix in T13: `drawArc` ring with radius `subscreen.width / 2 - 5`, mocked clear of the bezel for subscreen centers 1px apart.
- Review `review-...` over `7644822..28c616c` (T12-T14 + revert): **approved**, acknowledged; boundary `28c616c`. `R3-12h-leading-zero-unrequested` (WARNING): the change *was* user-requested; the request is now recorded in T14. `R3-step-ring-geometry-untested` (SUGGESTION) -> taken in T15. `R3-ring-date-clearance-unverified` (SUGGESTION): `activityInfo` is fetched at the top of `onUpdate` (the build proves it is declared); clearance checked with real metrics below.
- Simulator diagnostics (debug copy in the scratchpad, never committed): `getSubscreen()` = x=113 y=0 w=62 h=62 -> center (144, 31); ring radius 26; `getTextWidthInPixels("Mon")` = 36, `("12")` = 24; `getTextDimensions("Mon\n12")` = [36, 27]. Root cause of the off-center date: the glyphs leave an empty right column (ink 1px left), and `VCENTER` centers the 27px box although the ink is 23px tall (about 2px high). Fix: anchor the top at `dateY - 11` and shift +1px. The ink box (35x23, corners about 21px from center) clears the ring's inner edge (radius 25).
- Top-area redesign measured against the display mask: visible band left of the subscreen is x 30..108 at y=4, x 0..100 at y=30 and x 0..112 at y=58. Status row centered at x=67 (y 4..15), logo at (10, 18), data row at y 58..69, time digits from y=79. Mock checks: zero clipped pixels for normal, charging + phone-off + 5-digit calories states.
- Mock bug found and fixed: the icon loader sampled QuickLook rasters with an integer scale (512 // 88 = 5), which stretched and clipped non-power-of-two sizes; it now crops the viewport and resamples with a box filter.
- Review over `28c616c..f7a4fd9` (T15-T18), run under the standing consent: **approved**, acknowledged; reviewed boundary is now `f7a4fd9`. `R3-001` (SUGGESTION): the date offsets come from simulator font metrics. The risk is low because `fontSmall` is the app's own compiled bitmap font (`pixel_small.fnt`), not a device font. The on-device check stays listed as a follow-up.
- Out-of-scope follow-ups: refresh `preview.png` with a new simulator screenshot; on-device check on a real Instinct 2.

## Next step

Feature complete on `feat/retro-face-improvements` (all slices reviewed and acknowledged up to `f7a4fd9`). Pending for the user: on-device check, a new `preview.png` screenshot, then push and the single PR.
