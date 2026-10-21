# Actions and keyboard shortcuts — version 2.2.4

All entries below are registered by the native extension in REAPER's **Main** Actions section. Search **EA: Automation**, select an action and choose **Add** in the shortcut area. No separate scripts need importing. The same entries can be used in custom actions and toolbars.

Automation actions open the panel when needed and wait for the engine before executing. Copy buffers and Capture values are cleared on close. Closing or failed startup discards pending actions. The shortcut does not run while the engine is closing.

The original **EA: Native Automation (JUCE) - toggle panel** action remains available with command ID `_EACompactAutomationNative`.

IDs below are stable names for `reaper.NamedCommandLookup`; REAPER's numeric IDs vary between installations. Toggle/radio state reflects the engine while running; stored startup/style/size preferences remain available with the panel closed. A mixed scoped automation mode has no selected mode radio entry.

| Named command ID | Main Actions-list name |
|---|---|
| `_EA_NATIVE_AUTOMATION_OPEN` | EA: Automation - Open panel |
| `_EA_NATIVE_AUTOMATION_CLOSE` | EA: Automation - Close panel |
| `_EA_NATIVE_AUTOMATION_SUSPEND` | EA: Automation - Toggle Suspend (bypass envelopes) |
| `_EA_NATIVE_AUTOMATION_WRITE_ENABLE_PLUGIN` | EA: Automation - Toggle Write Enable: plug-ins |
| `_EA_NATIVE_AUTOMATION_WRITE_ENABLE_VOLUME` | EA: Automation - Toggle Write Enable: track volume |
| `_EA_NATIVE_AUTOMATION_WRITE_ENABLE_SEND_VOLUME` | EA: Automation - Toggle Write Enable: send volume |
| `_EA_NATIVE_AUTOMATION_WRITE_ENABLE_PAN` | EA: Automation - Toggle Write Enable: track pan and ReaSurround |
| `_EA_NATIVE_AUTOMATION_WRITE_ENABLE_SEND_PAN` | EA: Automation - Toggle Write Enable: send pan |
| `_EA_NATIVE_AUTOMATION_WRITE_ENABLE_MUTE` | EA: Automation - Toggle Write Enable: track mute |
| `_EA_NATIVE_AUTOMATION_WRITE_ENABLE_SEND_MUTE` | EA: Automation - Toggle Write Enable: send mute |
| `_EA_NATIVE_AUTOMATION_WRITE_START` | EA: Automation - Manual write: to range start |
| `_EA_NATIVE_AUTOMATION_WRITE_ON_STOP_START` | EA: Automation - Toggle Write on Stop: to range start |
| `_EA_NATIVE_AUTOMATION_WRITE_ALL` | EA: Automation - Manual write: across selection / project range |
| `_EA_NATIVE_AUTOMATION_WRITE_ON_STOP_ALL` | EA: Automation - Toggle Write on Stop: across selection / project range |
| `_EA_NATIVE_AUTOMATION_WRITE_END` | EA: Automation - Manual write: to range end |
| `_EA_NATIVE_AUTOMATION_WRITE_ON_STOP_END` | EA: Automation - Toggle Write on Stop: to range end |
| `_EA_NATIVE_AUTOMATION_WRITE_PUNCH` | EA: Automation - Manual write: from first touch / punch |
| `_EA_NATIVE_AUTOMATION_WRITE_ON_STOP_PUNCH` | EA: Automation - Toggle Write on Stop: from first touch / punch |
| `_EA_NATIVE_AUTOMATION_WRITE_NEXT` | EA: Automation - Manual write: to next breakpoint |
| `_EA_NATIVE_AUTOMATION_WRITE_ON_STOP_NEXT` | EA: Automation - Toggle Write on Stop: to next breakpoint |
| `_EA_NATIVE_AUTOMATION_AUTO_JOIN` | EA: Automation - Toggle Auto Join |
| `_EA_NATIVE_AUTOMATION_AUTO_MATCH` | EA: Automation - Auto Match / clear preview latches |
| `_EA_NATIVE_AUTOMATION_PREVIEW` | EA: Automation - Toggle Preview |
| `_EA_NATIVE_AUTOMATION_PREVIEW_SUSPEND` | EA: Automation - Suspend / resume Preview (A/B) |
| `_EA_NATIVE_AUTOMATION_PREVIEW_PUNCH` | EA: Automation - Punch preview values |
| `_EA_NATIVE_AUTOMATION_CAPTURE` | EA: Automation - Capture current values |
| `_EA_NATIVE_AUTOMATION_CAPTURE_ALL` | EA: Automation - Capture all enabled values on all tracks |
| `_EA_NATIVE_AUTOMATION_CAPTURE_SELECTED` | EA: Automation - Capture enabled values on selected tracks |
| `_EA_NATIVE_AUTOMATION_CAPTURE_PUNCH` | EA: Automation - Punch captured values |
| `_EA_NATIVE_AUTOMATION_CAPTURE_CLEAR` | EA: Automation - Clear captured values |
| `_EA_NATIVE_AUTOMATION_COPY_ALL` | EA: Automation - Copy all automation |
| `_EA_NATIVE_AUTOMATION_COPY_PAN` | EA: Automation - Copy pan automation (including ReaSurround) |
| `_EA_NATIVE_AUTOMATION_COPY_ENABLED` | EA: Automation - Copy write-enabled automation |
| `_EA_NATIVE_AUTOMATION_PASTE_CURSOR` | EA: Automation - Paste automation at edit cursor |
| `_EA_NATIVE_AUTOMATION_PASTE_STRETCH` | EA: Automation - Paste automation: stretch to time selection |
| `_EA_NATIVE_AUTOMATION_PASTE_FILL` | EA: Automation - Paste automation: repeat / fill time selection |
| `_EA_NATIVE_AUTOMATION_SCOPE_ALL` | EA: Automation - Use all tracks |
| `_EA_NATIVE_AUTOMATION_SCOPE_SELECTED` | EA: Automation - Use selected tracks |
| `_EA_NATIVE_AUTOMATION_SCOPE_TOGGLE` | EA: Automation - Toggle all / selected track scope |
| `_EA_NATIVE_AUTOMATION_ITEMS` | EA: Automation - Toggle automation items for write / paste |
| `_EA_NATIVE_AUTOMATION_STARTUP` | EA: Automation - Toggle Run at startup |
| `_EA_NATIVE_AUTOMATION_MODE_0` | EA: Automation - Set scoped automation mode: Trim / Read |
| `_EA_NATIVE_AUTOMATION_MODE_1` | EA: Automation - Set scoped automation mode: Read |
| `_EA_NATIVE_AUTOMATION_MODE_2` | EA: Automation - Set scoped automation mode: Touch |
| `_EA_NATIVE_AUTOMATION_MODE_3` | EA: Automation - Set scoped automation mode: Write |
| `_EA_NATIVE_AUTOMATION_MODE_4` | EA: Automation - Set scoped automation mode: Latch |
| `_EA_NATIVE_AUTOMATION_MODE_5` | EA: Automation - Set scoped automation mode: Latch Preview |
| `_EA_NATIVE_AUTOMATION_SIZE_0` | EA: Automation - Set panel size: Auto |
| `_EA_NATIVE_AUTOMATION_SIZE_50` | EA: Automation - Set panel size: 50% |
| `_EA_NATIVE_AUTOMATION_SIZE_75` | EA: Automation - Set panel size: 75% |
| `_EA_NATIVE_AUTOMATION_SIZE_100` | EA: Automation - Set panel size: 100% |
| `_EA_NATIVE_AUTOMATION_SIZE_125` | EA: Automation - Set panel size: 125% |
| `_EA_NATIVE_AUTOMATION_SIZE_150` | EA: Automation - Set panel size: 150% |
| `_EA_NATIVE_AUTOMATION_SIZE_175` | EA: Automation - Set panel size: 175% |
| `_EA_NATIVE_AUTOMATION_SIZE_200` | EA: Automation - Set panel size: 200% |
| `_EA_NATIVE_AUTOMATION_THEME_0` | EA: Automation - Set panel style: Follow REAPER |
| `_EA_NATIVE_AUTOMATION_THEME_1` | EA: Automation - Set panel style: Graphite |
| `_EA_NATIVE_AUTOMATION_THEME_2` | EA: Automation - Set panel style: Silver |
| `_EA_NATIVE_AUTOMATION_THEME_3` | EA: Automation - Set panel style: Midnight |
| `_EA_NATIVE_AUTOMATION_THEME_4` | EA: Automation - Set panel style: Warm graphite |
| `_EA_NATIVE_AUTOMATION_THEME_5` | EA: Automation - Set panel style: Classic charcoal |
| `_EA_NATIVE_AUTOMATION_DOCK_SIDE_0` | EA: Automation - Dock panel: bottom |
| `_EA_NATIVE_AUTOMATION_DOCK_SIDE_1` | EA: Automation - Dock panel: left |
| `_EA_NATIVE_AUTOMATION_DOCK_SIDE_2` | EA: Automation - Dock panel: top |
| `_EA_NATIVE_AUTOMATION_DOCK_SIDE_3` | EA: Automation - Dock panel: right |
| `_EA_NATIVE_AUTOMATION_DOCK_SIDE_4` | EA: Automation - Dock panel: floating Docker |
| `_EA_NATIVE_AUTOMATION_DOCKER_1` | EA: Automation - Move panel to Docker 1 |
| `_EA_NATIVE_AUTOMATION_DOCKER_2` | EA: Automation - Move panel to Docker 2 |
| `_EA_NATIVE_AUTOMATION_DOCKER_3` | EA: Automation - Move panel to Docker 3 |
| `_EA_NATIVE_AUTOMATION_DOCKER_4` | EA: Automation - Move panel to Docker 4 |
| `_EA_NATIVE_AUTOMATION_DOCKER_5` | EA: Automation - Move panel to Docker 5 |
| `_EA_NATIVE_AUTOMATION_DOCKER_6` | EA: Automation - Move panel to Docker 6 |
| `_EA_NATIVE_AUTOMATION_DOCKER_7` | EA: Automation - Move panel to Docker 7 |
| `_EA_NATIVE_AUTOMATION_DOCKER_8` | EA: Automation - Move panel to Docker 8 |
| `_EA_NATIVE_AUTOMATION_DOCKER_9` | EA: Automation - Move panel to Docker 9 |
| `_EA_NATIVE_AUTOMATION_DOCKER_10` | EA: Automation - Move panel to Docker 10 |
| `_EA_NATIVE_AUTOMATION_DOCKER_11` | EA: Automation - Move panel to Docker 11 |
| `_EA_NATIVE_AUTOMATION_DOCKER_12` | EA: Automation - Move panel to Docker 12 |
| `_EA_NATIVE_AUTOMATION_DOCKER_13` | EA: Automation - Move panel to Docker 13 |
| `_EA_NATIVE_AUTOMATION_DOCKER_14` | EA: Automation - Move panel to Docker 14 |
| `_EA_NATIVE_AUTOMATION_DOCKER_15` | EA: Automation - Move panel to Docker 15 |
| `_EA_NATIVE_AUTOMATION_DOCKER_16` | EA: Automation - Move panel to Docker 16 |
| `_EA_NATIVE_AUTOMATION_UNDOCK` | EA: Automation - Undock / float panel |
| `_EA_NATIVE_AUTOMATION_MENU_PANEL` | EA: Automation - Show panel menu |
| `_EA_NATIVE_AUTOMATION_MENU_PREVIEW` | EA: Automation - Show Preview menu |
| `_EA_NATIVE_AUTOMATION_MENU_PASTE` | EA: Automation - Show Copy / Paste menu |
| `_EA_NATIVE_AUTOMATION_MENU_SETTINGS` | EA: Automation - Show settings menu |
| `_EA_NATIVE_AUTOMATION_MENU_SCOPE` | EA: Automation - Show track-scope menu |


## Manual Write confirmation

The middle ↔ Manual Write button and `_EA_NATIVE_AUTOMATION_WRITE_ALL` share the same guard: without a time selection, **OK** confirms writing across the entire session and **Cancel** stops without writing or leaving Preview. A time selection writes directly. Your existing shortcut mapping remains valid.
