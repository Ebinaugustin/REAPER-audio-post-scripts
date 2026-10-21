# Validation of the delivered package

## Version 2.2.4 no-selection confirmation

- 87 engine scenarios / 1,096 core assertions plus the production command-loop check pass. Six new scenarios verify that the native OK/Cancel dialog appears before any Undo/edit, Cancel retains all original curves/views/Preview/Capture, OK fills the complete project range, existing selections avoid the alert, optional items and non-OK responses are handled, and other ranges/on-stop remain unchanged.
- The updated regression fixture run against the previous 2.2.3 engine fails because it writes four envelopes instead of cancelling without edits.
- All five CTest targets pass against the updated engine. The Windows native DLL is reused unchanged from 2.2.3; the confirmation uses REAPER’s cross-platform ShowMessageBox API. Installer tests verify the real new payload in scratch resource folders. No live REAPER session was controlled or modified here. macOS/Linux sources include the same engine update; those native targets remain uncompiled/unverified here.

## Version 2.2.3 visibility and version-menu checks

- 81 engine scenarios / 838 core assertions plus the production command-loop check pass. The previous engine fails the updated hidden-lane assertion.
- Regression scenarios cover All Tracks writes with hidden volume/pan and master lanes, inline versus separate lanes, visible lanes, hidden unrelated/bypassed envelopes, explicit Capture, write-on-stop, native action failure, deferred host exposure, no-latch Preview, one latched volume among many armed controls, the visibility-attribute fallback retaining fresh point data, Preview entry/A-B mode transitions and auto-created native lanes, and a repeated Manual Write after Preview ends.
- Actual JUCE context menus are inspected offscreen for a non-actionable version header in the main, settings, Preview and Paste menus, and for updates following the connected engine version. All five CTest targets and the production-host/UI fixture pass.
- The Windows x64 native extension is rebuilt for the menu change. macOS/Linux adapters use the same standard JUCE/Lua code but remain uncompiled/unverified here. Installer tests use scratch folders and its real embedded release payload.
- Read-only inspection of the installed engine receipt and latest ManualWrite diagnostic confirmed v2.2.2 and a verified held curve. Source inspection found that the common envelope preparation helper explicitly requested VISIBLE=1 during writes. No live REAPER project, track visibility or automation was changed here.

## Version 2.2.2 engine hotfix

- 70 engine scenarios / 500 core assertions plus the production command-loop check pass. The fixture now applies PT records when loading envelope chunks, rather than silently retaining stale points.
- New checks simulate a native write-buffer flush on Preview exit, native cursor-only dips/no-ops, delayed overwrite detection, attribute-only lane activation, and optional item writes. They verify the full held range and original outside values, no duplicated guards and balanced Undo. The previous 2.2.1 engine fails the Preview-exit flush regression.
- These are simulated failure conditions; the exact live host cause of the user’s dip is not yet confirmed. The delivered engine records the requested range, source/held values, UI flags, current modes, samples and nearby points to ManualWrite-diagnostics.txt after a real Manual Write. Only the latest operation is retained; no media or full FX/project state is logged.
- The native C++ sources and compiled Windows DLL are unchanged from 2.2.1. All five CTest targets pass with this updated engine fixture, and the updated installer is checked using its real embedded payload in scratch directories. The actual user REAPER project has not been controlled or modified here.
- macOS/Linux use the same engine source update; their native build kits remain uncompiled/unverified here.

## Version 2.2.1 Manual Write checks

- Lua engine model: 65 scenarios / 426 core assertions plus the production command-loop check. Seven new scenarios model host-internal latch values independently from UI/stored trim reads and verify volume, normal pan, send pan and ReaSurround commits throughout each interval.
- Ran the new regression fixture against the previous v2.2 engine: it fails on the held value (expected 0.42, old path writes 1.96); the updated engine passes. This checks the code-path change, not a live reproduction.
- Verified all five write ranges, protected/unarmed envelopes, unselected tracks, per-envelope punch/next ranges, restoration after native action failure, whole-project writes with no original time selection, and separate automation-item/Capture paths.
- Built the Windows x64 extension and ran all five CTest targets. Installer tests use its actual embedded release payload and scratch resource folders only.
- The native command and its workflow were checked against REAPER’s SDK and official user guide. The reported host behavior has not been reproduced in a live REAPER session here; this release switches the live commit to the native path the user reports working. Live validation remains for the user. macOS/Linux sources include the same engine fix but remain uncompiled/unverified here.

## Version 2.2 shortcut-action checks

- Compiled the updated Windows x64 extension with the local Microsoft toolchain described below. All five CTest targets passed: panel layouts, native bridge, action catalogue, actual DLL registration/unload and Lua engine model.
- Verified 88 unique stable action IDs covering every panel control, modifier operation, menu and setting. The actual DLL registers all 88 plus the original panel toggle in the Main section, with correct descriptions. Partial-registration failure unregisters every previously added accelerator/API; normal unload also removes all entries. Unknown REAPER actions are not consumed.
- Verified startup, size and style actions and their toggle/radio states with the panel closed in the DLL fixture.
- Passed the offscreen production-host/UI integration check for every engine action's exact command, single engine startup for multiple waiting shortcuts, ordered dispatch after connection, no replay on subsequent ticks, close/failed-startup cancellation and toolbar refreshes only when state changes. Engine state, track-scope radio states and mixed-mode clearing are checked.
- The production headless Lua loop also checks persistent scope-toggle commands and integer mode publication when the host returns a floating-point automation mode. The retained automation model still passes 58 tests / 290 core assertions.
- Rechecked Lua syntax and Windows DLL imports. Only Windows system libraries are required; there is no separate JUCE or Visual C++ runtime DLL dependency.

These are automated checks against a host model and the production binary/component. No REAPER session was opened. Assigning and using shortcuts inside your actual REAPER installation remains a live host check. macOS/Linux source adapters and build kits are updated but remain uncompiled/unverified here.

## Completed locally on Windows x64

- Compiled the production extension with Microsoft C/C++ 19.44.35229, Windows SDK 10.0.26100.0, JUCE 8.0.12 and CMake 4.4. Release build, static C/C++ runtime.
- Loaded the resulting DLL in a separate mock-host executable. Confirmed the exported `ReaperPluginEntry`, required-host-API validation, native action and four Lua bridge APIs, engine-action dispatch, duplicate-open protection and complete unregistering on unload. No REAPER process was opened.
- Checked the DLL's imports: Windows system libraries only; no separate JUCE or Visual C++ runtime DLL is needed by this build.
- Passed layout/action tests for all 30 controls in vertical, horizontal and shallow layouts, including bounds, overlap, larger write-button targets and automatic scale limits.
- Passed bridge tests for FIFO ordering, state parsing, bounded capacity and close discarding queued edits.
- Passed 58 automation-engine model tests / 290 core assertions. These cover automation writing/scaling, pan polarity, copy/stretch/repeat boundaries, compacted points, cross-track native envelopes, existing-send matching, ReaSurround classification and cleanup. New cases verify all-track/take envelope bypass, envelopes added during Suspend, restoration of previously bypassed envelopes, activation-attribute fallback, selected-track Capture without changing scope, unarmed envelope capture and Manual Write exiting Preview only after a successful write. Preview A/B tests cover Read-mode auditioning without point writes, held-value restoration, Manual Write from paused Preview, deleted-envelope handling, latch clearing and cleanup restoring original modes.
- Passed the production headless command-loop test: engine connect, Preview/write/copy/paste/settings commands, state publication, close, restored modes, balanced Undo and idempotent cleanup.
- Passed an offscreen test of the actual production JUCE component. Confirmed glass-style drawing, green Preview, visible pressed feedback, release-triggered actions, cancellation when dragging off a button, Capture modifier commands and timed blinking, cursor menu anchoring including negative screen coordinates, saved size preferences, 50–200% presets and correct click targets in horizontal, shallow and scrolling dock layouts. The `previews` PNGs are actual JUCE renders, not generated design concepts.
- Checked Lua syntax for the engine and launcher.
- Version 2.1.1 checks also cover the live enabled-toolbar accent, green-to-purple changes without reopening the panel in all six styles, neutral-toolbar highlight fallback, missing-token selection fallback and monochrome/no-token themes, plus Ctrl-click Preview command dispatch and its paused visual indicator. The green and purple `reaper` previews use real colours from installed REAPER themes in the mock host; no live theme was changed.

## Still requires platform / host testing

The macOS universal and Linux x64 targets have source adapters, dependency declarations and CI build configurations, but have not been compiled or run here. Linux's native adapter requires GTK 3 and X11/XWayland. The remote GitHub workflow has not been executed.

The DLL load test and offscreen component checks do not validate REAPER's live Docker handling, undocking visibility, monitor/DPI transitions, automation playback, project state chunks or plug-in behaviour. The undocking and deferred monitor-fitting changes compile, but dragging from a secondary to a primary monitor needs your live REAPER check. Preview A/B behaviour also needs an audition with actual native/send/FX automation. As requested, no REAPER session was opened for testing. Start with a duplicate test project, especially for Suspend/restoration, Manual Write, send automation and repeat/fill boundaries.

The implementation is a native JUCE/C++ interface and integration layer with a headless Lua automation engine. It is not a complete C++ rewrite of the automation logic.
