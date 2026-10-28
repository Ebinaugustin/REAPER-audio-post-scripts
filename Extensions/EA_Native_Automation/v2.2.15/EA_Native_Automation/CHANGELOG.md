# Changes in 2.2.15 (whole Preview button blink)

- Removes the blinking Preview dot. The whole button face alternates bright/dim green while on, with the full label width restored.
- Off remains a steady normal button; A/B suspension remains steady amber. Other controls, fonts, sizes and automation behavior are retained.
- Native UI checks observe matching left/right face colors through both green phases, verify the old dot region has no separate indicator, and check steady off/paused states with zero automation commands.

# Changes in 2.2.14 (REAPER fonts and Preview indicator)

- Removes the custom pixel typeface and loads REAPER's actual Inter-Regular / Inter-Medium font files. Uses Medium weight without synthetic bold, caches typefaces in-process, and safely falls back if files or the optional path API are unavailable.
- Uses readable native-size small labels with an 11-pixel minimum, retaining the same button sizes and uncompressed aliases/tooltips.
- Adds a small blinking green Preview lamp. Preview off stays dark and A/B suspension is steady amber. Text stays steady and blinking never changes automation state or sends commands.
- Retains all 104 actions, saved sections, fixed-size Docker reveal, presets, native context support and engine behavior.
- Tests the actual REAPER fonts through an application-folder fixture, optional/missing-font fallbacks, both green blink phases, steady off/paused states and existing UI/engine checks.

# Changes in 2.2.13 (compact pixel typeface)

- Uses an embedded narrow seven-pixel typeface at 50% / 75%, with solid integer-aligned strokes and no font installation. Larger presets retain platform lettering; unsupported characters fall back to it.
- Measures labels using the actual pixel glyph widths. Every standard horizontal caption fits in full at 50% on a 1× display, without changing button geometry or commands. Existing aliases/tooltips remain available for other constraints.
- Retains fixed-size docking, all size/section preferences, native context handling, theme/feedback states, all 104 actions and automation behavior.
- Adds glyph coverage/bounds/width checks and a production 1× raster check for exactly seven foreground rows with no softened text cells. Includes the actual component preview.

# Changes in 2.2.12 (sharper compact rendering)

- Replaces roughly six-pixel text at 50% with direct-size label rendering and a minimum 10-logical-pixel font. Measured short labels replace font compression where necessary; full tooltips and action names remain.
- Aligns button edges and text origins/baselines with physical pixels and gives icons a minimum one-physical-pixel stroke. Retains rounded glass styling, theme accent, Preview/Capture state and press feedback.
- Preserves the exact compact button sizes, dock minimum hints, fixed-size divider reveal, five section preferences, 104 actions and Lua automation behavior.
- Adds physical-pixel alignment checks at common OS densities and a real 1× compact render check for visible glyph height and solid text pixels. Includes a 1× LCD preview in the source package.

# Changes in 2.2.11 (restore compact dock sizing)

- Removes the forced 100% dock minimum, restoring the saved 50% / 75% presets. Explicit 50–200% settings apply exactly. Auto defaults to a compact 75% while docked, with floating Auto monitor sizing unchanged.
- Keeps fixed-size progressive reveal/reflow while dragging, five saved section toggles and all 104 existing actions. Automation and native context-menu behavior are retained.
- Adds compact native docking minimum-size hints at the selected preset. The extension does not resize the shared Docker; its actual size and other-tab constraints remain controlled by REAPER.
- Checks the reported eight-control 50% row in a 20-pixel content strip, exact preset scales, compact Auto defaults, native minimum geometry, existing layouts/actions and unchanged engine behavior.

# Changes in 2.2.10 (fixed-size Docker reveal)

- Removes automatic button enlargement and short-axis stretching while dragging Docker dividers. Docked controls keep fixed dimensions and fonts at the chosen effective preset.
- Thin docks keep one row/column; expanding reveals additional rows/columns. Controls remain ordered, section visibility is retained, and overflow scrolls along the primary axis. Content stays anchored at the upper-left and resizing resets stale scroll offsets.
- Handles native WM_CONTEXTMENU requests in the extension dialog, so forwarded dock-tab/native-wrapper requests open the same panel menu. The extension does not hook the shared Docker/flag window. Actual REAPER flag behavior remains a live confirmation item.
- Retains five saved section choices, 104 stable actions, floating sizing, theme/feedback, Preview and send-copy behavior. Lua automation differs only in version markers.
- Checks fixed button dimensions through divider changes at all presets and all 32 section masks, progressive row/column reveal, no overlap and original action dispatch. Includes production component renders before/after expanding a Docker.

# Changes in 2.2.9 (readable docks and section visibility)

- Fixes tiny docked buttons caused by a saved 50% / 75% size. Docked controls use a minimum 100% text/icon scale, expand into spare width/height and retain single-row / single-column reflow. Floating size presets keep their original behavior.
- Short-axis button geometry fits the Docker without uniformly shrinking labels. Longer strips scroll along their own axis; full strips fit when space permits without falling below the readable minimum.
- Adds Show sections to context and settings menus: Suspend, Write Enable, Manual Write, Write on Stop, Copy / Paste, and Show all sections. Choices persist; hidden controls/headings disappear and remaining sections reflow. Floating height follows the visible sections.
- Visibility changes are cosmetic and never toggle automation state. Hidden controls retain their existing shortcut actions. Adds six stable visibility actions, for 104 individual actions plus the original panel toggle.
- Checks every one of the 32 section combinations in all five layouts and production JUCE dock layouts, all size presets, saved menu/action states, invalid preference fallback, closed-engine visibility shortcuts, existing actions and unchanged Lua automation behavior.

# Changes in 2.2.8 (compact docking)

- Thin top/bottom docks automatically reflow all 30 controls onto one row; narrow left/right docks use one column. Floating Docker containers choose orientation from their shape. Expanding/undocking restores the grouped layouts.
- Size presets and display scaling determine the responsive breakpoints. Compact labels and vector icons fit the available button geometry, with W/S badges identifying Manual Write and Write on Stop.
- Overflow stays on the same axis, with a small draggable scrollbar, wheel and trackpad scrolling. All controls retain their full tooltips and original actions; horizontal strips also support Shift+wheel.
- Retains all 98 stable shortcut actions, shared cross-platform source, theme colours, button feedback, Preview synchronization, Send 1–10 copying and the automatic-envelope preference fix.
- Adds geometry checks for five layouts/all dock sides/every size preset and production JUCE checks for every compact hit target and action, both scroll directions, no-overflow and overflow strips, trackpad/Shift+wheel, and restoring the normal panel after undocking.

# Changes in 2.2.7 (engine hotfix)

- Stops changing REAPER's automatic-envelope creation preference. Removed both the repeated protection-pass writes and the cleanup restore of a potentially stale value.
- Write Enable and Suspend now leave the user's checkbox and unrelated preference flags untouched. Existing envelope arming and bypass protection remain active; new protected envelopes are gated on the next guard pass.
- Added six preference-preservation regression scenarios covering enabled/disabled states, unrelated flag bits, user changes while protection is active, Suspend, new envelopes, missing SWS preference APIs and zero global-preference writes across the complete suite and production loop.
- Retains all-track Preview synchronization, the ten separate send-copy commands, all 98 stable action IDs and the existing 2.2.5 native DLL.

# Changes in 2.2.6 (engine hotfix)

- Preview on forces all current tracks and Master into Latch Preview; Preview off forces them into Read. Both transitions clear the global automation override, independently of track scope.
- Explicit Preview off no longer restores earlier Write, Latch or Latch Preview modes. The existing panel-close/project-switch cleanup still restores its saved state when Preview was left active.
- New tracks join the active Preview state; during A/B suspension they stay Read until Preview resumes.
- A/B preserves held values for all previewed tracks. Manual Write from paused Preview filters the held values to the selected write scope, protecting unrelated automation.
- Preserves envelope-lane visibility through mode transitions. Button and shortcut use the same engine command.
- Added six behavioural regression scenarios and production command-loop assertions. The native 2.2.5 DLL and all 98 action IDs are retained.

# Changes in 2.2.5

- Added ten separate Copy Send 1–10 commands in the Copy/Paste dropdown and panel context menu, with ten stable shortcut actions. The total is 98 individual actions plus the panel toggle; existing action IDs are unchanged.
- Copies existing normal-send volume/pan/mute automation from selected source tracks using the existing copy range. Excludes hardware outputs, other slots, native track and FX automation. Explicit copy commands are independent of Write Enable gates.
- Reuses existing cursor, stretch and repeat/fill pasting. Matching destination bus/channels have priority, followed by the existing send-slot fallback. Sends and routing are never created.
- An empty source send slot clears the clipboard and reports status; invalid slots cannot replace a valid clipboard. Missing destination parameters retain the existing unmatched-envelope dialog.
- Added send-copy regression coverage for every slot, volume/pan/mute, hardware exclusion, cross-track bus matching, empty slots, invalid commands, native command dispatch and menu/action coverage.
- Native track volume/pan Manual Write and lane-visibility reports remain separate known issues requiring live confirmation.

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
