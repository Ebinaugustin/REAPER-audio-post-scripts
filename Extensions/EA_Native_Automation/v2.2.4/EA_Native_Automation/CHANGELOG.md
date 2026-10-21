# Changes in 2.2.4 (engine hotfix)

- Manual Write across selection/project range now asks for confirmation when there is no time selection. The alert explains that proceeding writes the current automation values across the entire session and identifies the panel track scope.
- OK proceeds; Cancel, Escape/window close or any non-OK response stops before Undo, native commands, envelope edits or Preview exit. Preview, captured values, loop/time selection and existing lane views are retained on cancellation.
- The same confirmation covers the middle Manual Write button and its existing Actions-list shortcut, including explicit Capture, suspended Preview and optional automation-item writes. Existing time selections write directly. Other write ranges and automatic write-on-stop remain unchanged.
- Native UI/DLL and all 88 individual action IDs are unchanged from 2.2.3. The connected engine version appears as 2.2.4 in the menu.
- Added six behavioral regression scenarios covering Cancel before edits, confirmed session writes, existing selections, retained Capture/paused Preview, non-OK responses and optional items, and unaffected write ranges/on-stop behavior.

# Changes in 2.2.3

- Manual Write and write-on-stop no longer force target envelopes visible. Hidden native volume/pan lanes remain hidden; visible lanes and inline-versus-separate-lane placement are preserved. Paste keeps its existing destination-reveal behavior.
- Existing lane views are saved across the project, including unselected tracks and the master, and restored after native actions, Preview/A-B mode transitions, failures and deferred host readback. Native volume/pan lanes auto-created by a mode transition are kept hidden. The visibility fallback edits the current VIS fields and retains newly written points.
- Manual Write requires latched/touched controls or an explicit Capture. Empty Preview, suspended Preview and repeated clicks after Preview ends stop with a status message instead of falling back to writing every armed envelope. Capture and write-on-stop retain their explicit value sets.
- Every panel context menu now shows the connected engine version as a non-actionable header. The engine publishes its version with the button state.
- Added eleven engine regression scenarios and offscreen checks of the actual JUCE menus.

# Changes in 2.2.2 (engine hotfix)

- Manual Write now ends Preview before installing the final automation curve. It preserves the held raw native value when the native command produces a full plateau, and uses the held snapshot when that command produces a no-op or cursor-only dip.
- Provisional native edits are removed through point APIs and original outside points restored, preventing duplicate transition guards. The final clean plateau is installed in the same Undo block after the Preview pass finishes.
- Lane activation/visibility uses supported targeted envelope attributes instead of reloading the entire envelope state.
- Added immediate curve verification and delayed host readback. The status reports verified success only after readback; failure shows a status warning and writes ManualWrite-diagnostics.txt beside engine.lua. No extra dialog is shown.
- Optional automation-item Manual Write also ends Preview before creating the final held curve. Existing item pools use the isolated explicit-write path.
- Native C++ UI/DLL and its action IDs are unchanged from 2.2.1. This is a Lua engine update within the JUCE application package.

# Changes in 2.2.1

- Live Manual Write uses REAPER’s native “Write current values for actively-writing envelopes to time selection” action (42013), reading the host’s internal latches for native track volume/pan, send controls and FX, including ReaSurround. It no longer reconstructs these active latches from UI controls.
- The start, selection/project, end, punch and next-breakpoint buttons provide their own exact range, including per-envelope touch/breakpoint ranges.
- Temporarily gates the native action to enabled, armed active envelopes within the panel scope. Restores envelope arms, time selection and loop bounds on success or failure. Track selection, cursor and transport are not changed.
- Successful Manual Write still exits Preview to per-track automation; failures and empty ranges retain Preview. Optional automation items, Capture, suspended Preview and write-on-stop snapshots retain their explicit point writes.
- Added seven regression scenarios covering internal latch values differing from UI/stored trims, five write ranges, scope/protection, per-envelope ranges, failure cleanup, empty selection and explicit captured/item writes.

## Changes in 2.2

- Added 88 native Main Actions-list entries covering every panel control, modifier command, menu, docking/style/size setting and Run at startup. Stable command IDs work across platforms, resource paths and updates; the original panel-toggle ID is preserved.
- Automation shortcuts open the panel automatically and run after the engine connects. Closing or failed startup clears waiting commands.
- Added Actions-list/toolbar toggle and radio states with refreshes only when state changes.
- Added persistent scope switching and published scoped automation-mode state for shortcut indicators.
- No separate shortcut scripts need importing. See `ACTIONS.md` for all entries.

## Changes in 2.1.1

- Active buttons now use the current REAPER enabled-toolbar accent in every panel style, with theme highlight/selection fallbacks for neutral toolbar colours.
- Accent changes apply while the panel is open; no restart is needed after changing REAPER themes.
- Removed fixed blue/teal preset accents and improved active-button label contrast. Preview remains green; selected-track Capture remains blinking amber.
- Monitor dragging no longer fits/scales the floating window during the Windows move loop; after release it uses the monitor with the largest overlap and saves its new position.
- Ctrl/Cmd-click Preview suspends/resumes preview values for A/B comparison with existing automation. Paused Preview is clearly indicated, and Manual Write can commit the held values.

## Changes in 2.1

- Recreate the floating native window on undock and clamp it to a visible monitor position.
- Larger text, section headings, Write Enable and write icons; glass-style rounded buttons with press feedback.
- Automatic monitor/display scaling plus saved right-click size presets from 50% to 200%.
- Cursor-positioned menus and responsive dock layouts with scrolling when space is limited.
- Successful Manual Write leaves Preview and restores per-track automation mode.
- Suspend bypasses track, master and take envelopes, then restores their previous activation states.
- Ctrl/Cmd-click Capture captures selected tracks and blinks; Alt/Option and Alt/Option+Shift capture shortcuts are also supported.

Upgrade with REAPER closed. Replace both `UserPlugins/reaper_ea_automation.dll` and `UserPlugins/EA_Native_Automation/engine.lua`, then restart REAPER. Windows was compiled and checked locally; live REAPER and macOS/Linux checks remain as described in `VALIDATION.md`.
