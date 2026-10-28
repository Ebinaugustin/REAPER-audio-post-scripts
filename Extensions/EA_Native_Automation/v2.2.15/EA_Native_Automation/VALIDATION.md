# 2.2.15 validation

- Windows x64 extension compiled with MSVC; layout/model, action catalog, native bridge, actual extension-loader and production JUCE offscreen UI checks passed.
- UI checks observe bright/dim green across the whole active Preview face, no separate dot, steady off/paused state and no automation commands emitted by animation.
- Lua model suite: 104 scenarios / 1,393 assertions plus the production native command loop passed.
- Windows installer: 11 scratch scenarios / 49 assertions passed. No live REAPER session was used.
- Mac universal dylib compiled on a hosted Apple Silicon Mac. Model/layout, bridge and all 104 action-catalog tests ran on both hosted Apple Silicon and Intel Macs. Real user-domain package install and upgrade-backup checks passed on the disposable Mac. See MAC-BUILD-VALIDATION.txt for the original build report.
- ReaPack payload verification checks exact DLL/dylib/engine/source SHA256, universal Mach-O architectures, path safety, source parity and all platform download sets.
- Published index is produced by the official reapack-index with strict metadata checks; previous 2.2.4 history is retained.

These checks do not establish that every behaviour works in a live REAPER session. Track volume/pan Manual Write and unwanted lane visibility reports remain open. Live Mac REAPER automation, docking and scaling still need testing. Linux has no compiled release.
