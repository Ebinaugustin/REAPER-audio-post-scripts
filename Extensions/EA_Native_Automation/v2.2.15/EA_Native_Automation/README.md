# EA Native Automation 2.2.15

A compact Pro Tools-inspired automation panel for REAPER audio post-production. Native JUCE/C++ interface and REAPER integration with a bundled Lua engine. Created by Ebin Augustin while moving from Pro Tools to REAPER.

## Install or update through ReaPack

Compiled platforms: Windows 10/11 x64; macOS Intel x64 and Apple Silicon arm64 use the same universal dylib. Mac remains a preview requiring live REAPER testing. Linux is source only.

1. Run **ReaPack: Import repositories** and add `https://raw.githubusercontent.com/Ebinaugustin/REAPER-audio-post-scripts/main/index.xml` if it is not already imported.
2. Run **ReaPack: Synchronize packages**. In **ReaPack: Browse packages**, find **EA Native Automation**, choose **2.2.15** and Install/Update, then Apply.
3. Restart REAPER. Run **EA: Native Automation (JUCE) - toggle panel** in the Main Actions list.

ReaPack installs the correct binary and matching engine into UserPlugins. No compiler, separate JUCE, ReaImGui or Lua installation is required. Close the older standalone panel and disable its own startup option before using the native extension. Existing manual installations may prompt for file replacement. The native panel's right-click menu has its own Run at startup option.

## Workflow

- Write Enable for plug-in parameters, track volume/pan/mute and send volume/pan/mute. PAN covers ReaSurround and ReaSurroundPan.
- Preview, Ctrl/Cmd-click Preview A/B suspension, Capture, selected-track Capture, punch, Auto Join and Auto Match. The entire Preview button blinks green while active.
- Preview follows every track and Master. Explicit Preview off sets all to Read and removes global automation override. Manual Write/Capture retain their chosen target scope.
- Five Manual Write ranges and five Write on Stop modes. Successful Manual Write exits Preview; no-selection full-session writes ask for confirmation.
- Suspend bypasses existing envelopes and restores their earlier activation.
- Copy All, Copy Pan and separate Copy Send 1 through 10 commands. Send copies include volume, pan and mute. Paste at cursor, stretch to selection or repeat/fill. Normal points are the default; automation items are optional.
- Cross-track parameter matching. Send pastes use existing buses first, then slots; sends/routing are never created. Missing parameters are reported.
- Fixed-size docked row/column flow. Drag the Docker divider to reveal more rows/columns; overflow scrolls. Compact floating layout, theme colours, additional styles, rounded glass-style buttons and press feedback.
- Right-click for docking, themes, exact 50–200% sizes, version, startup and saved Show sections choices for Suspend, Write Enable, Manual Write, Write on Stop and Copy/Paste. Hiding does not change automation states.
- Reads REAPER's Inter/Inter Medium font files when available, uses system fallbacks otherwise, and renders small text/icons at their final pixel-aligned size. REAPER fonts are not redistributed.
- Preserves the user's automatic-envelope creation preference.

## 104 shortcut actions

Search **EA: Automation** in the Main Actions list, choose an action, then use **Add** to assign a key. All 104 commands plus the original panel toggle register automatically. Modifier functions, send-copy slots and section visibility have individual actions. See ACTIONS.md for names and stable IDs.

## Known issues and platform status

Track volume and ordinary track pan Manual Write have reported cursor dips/two-point writes and unwanted envelope lane visibility. Live confirmation remains pending; this release does not claim those reports are resolved. Please include the running version, parameter, Preview state, track scope and time selection in a bug report. The engine can write ManualWrite-diagnostics.txt beside engine.lua on verification failures.

Windows automated native UI, extension-loader and installer checks passed. Lua host-model checks passed 104 scenarios / 1,393 assertions. Mac universal compilation, Intel/Apple Silicon model checks and disposable-Mac installation/upgrade checks passed. Live Mac REAPER docking, scaling and automation remain unverified. The Mac dylib is ad-hoc signed, not Apple notarized. Linux compilation remains pending. See VALIDATION.md and MAC-BUILD-VALIDATION.txt.

## Source and licence

AGPL-3.0-or-later. Complete corresponding C++/Lua source, build configuration and pinned JUCE/REAPER SDK/WDL dependency archives are supplied in EA-Native-Automation-2.2.15-Source.zip beside this release. Third-party notices are retained. REAPER itself is not redistributed.

Website: https://ebinaugustin.github.io/ea-audio-website/automation.html
Forum: https://forum.cockos.com/showthread.php?t=312131
