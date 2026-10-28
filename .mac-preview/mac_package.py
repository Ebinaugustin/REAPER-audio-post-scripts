"""Run only on the hosted Mac after building and staging EA Native Automation."""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, zipfile

def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT)

root = Path.cwd()
version = '2.2.15'
source = root/'snapshot/Source'
stage = root/'stage'
work = root/'package-work'
dest = root/'mac-delivery'
for p in (work, dest): p.mkdir(exist_ok=True)
dylib = stage/'UserPlugins/reaper_ea_automation.dylib'
assert {'arm64','x86_64'} == set(run('lipo','-archs',str(dylib)).split())
assert '_ReaperPluginEntry' in run('nm','-gU',str(dylib))
run('codesign','--force','--sign','-',str(dylib))
run('codesign','--verify','--strict',str(dylib))
assert b'2.2.15' in (stage/'UserPlugins/EA_Native_Automation/engine.lua').read_bytes()
assert (stage/'UserPlugins/EA_Native_Automation/engine.lua').read_bytes() == (source/'runtime/EA_Native_Automation/engine.lua').read_bytes()

payload = work/'payload'
resource = payload/'Library/Application Support/REAPER'
shutil.copytree(stage/'UserPlugins',resource/'UserPlugins',dirs_exist_ok=True)
shutil.copytree(stage/'Scripts',resource/'Scripts',dirs_exist_ok=True)
for name in ('LICENSE.txt','THIRD-PARTY-NOTICES.md','ACTIONS.md'):
    shutil.copy2(source/name,resource/'UserPlugins/EA_Native_Automation'/name)
scripts = work/'scripts'
scripts.mkdir(exist_ok=True)
pre = scripts/'preinstall'
pre.write_text('''#!/bin/sh
set -eu
if /usr/bin/pgrep -ix REAPER >/dev/null 2>&1; then
  echo "Please quit REAPER before installing EA Native Automation." >&2
  exit 1
fi
resource="$HOME/Library/Application Support/REAPER"
plugins="$resource/UserPlugins"
if [ -e "$plugins/reaper_ea_automation.dylib" ] || [ -d "$plugins/EA_Native_Automation" ]; then
  backup="$resource/EA Native Automation Backups/$(/bin/date +%Y%m%d-%H%M%S)-$$"
  /bin/mkdir -p "$backup"
  if [ -e "$plugins/reaper_ea_automation.dylib" ]; then /usr/bin/ditto "$plugins/reaper_ea_automation.dylib" "$backup/reaper_ea_automation.dylib"; fi
  if [ -d "$plugins/EA_Native_Automation" ]; then /usr/bin/ditto "$plugins/EA_Native_Automation" "$backup/EA_Native_Automation"; fi
fi
exit 0
''',encoding='utf-8')
pre.chmod(0o755)
component = work/'component.pkg'
print(run('pkgbuild','--root',str(payload),'--scripts',str(scripts),'--identifier','audio.ea.reaper.nativeautomation.preview','--version',version,'--install-location','/',str(component)))
resources = work/'resources'
resources.mkdir(exist_ok=True)
(resources/'welcome.txt').write_text('''EA Native Automation 2.2.15 — macOS preview

Quit REAPER, then continue. Installs for this user into the standard REAPER resource folder. No compiler, JUCE installation or separate Lua installation is needed.

Universal binary: Intel and Apple Silicon. Ad-hoc signed, not Apple notarized. This is a test build; live REAPER automation and docking on Mac still need testing. Known track volume/pan Manual Write and lane-visibility reports remain under investigation.

Uses existing sends only. Does not change your REAPER preferences or overwrite your configuration. Previous EA extension/engine files are backed up when upgrading.

Portable/custom resource folders: cancel and use the Manual install folder in the download instead.
''',encoding='utf-8')
(resources/'finish.txt').write_text('''Installation complete.

Restart REAPER. Open Actions > Show action list and run:
EA: Native Automation (JUCE) - toggle panel

Search EA: Automation to assign keys to 104 individual commands. No action scripts need importing. Right-click the panel for docking, sizes, themes and visible sections.
''',encoding='utf-8')
distribution = work/'Distribution.xml'
distribution.write_text('''<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>EA Native Automation 2.2.15</title>
  <welcome file="welcome.txt" mime-type="text/plain"/>
  <conclusion file="finish.txt" mime-type="text/plain"/>
  <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
  <domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="false"/>
  <allowed-os-versions><os-version min="10.15"/></allowed-os-versions>
  <choices-outline><line choice="default"/></choices-outline>
  <choice id="default" visible="false"><pkg-ref id="audio.ea.reaper.nativeautomation.preview"/></choice>
  <pkg-ref id="audio.ea.reaper.nativeautomation.preview" version="2.2.15" onConclusion="none">component.pkg</pkg-ref>
</installer-gui-script>
''',encoding='utf-8')
setup = dest/f'EA-Native-Automation-v{version}-macOS.pkg'
print(run('productbuild','--distribution',str(distribution),'--package-path',str(work),'--resources',str(resources),str(setup)))
print(run('pkgutil','--payload-files',str(component)))
expanded = work/'expanded'
run('pkgutil','--expand',str(setup),str(expanded))
assert 'enable_currentUserHome="true"' in (expanded/'Distribution').read_text()
for p in payload.rglob('*'):
    if p.is_file(): assert not p.is_symlink()
manual = dest/'Manual install'
shutil.copytree(stage/'UserPlugins',manual/'UserPlugins',dirs_exist_ok=True)
shutil.copytree(stage/'Scripts',manual/'Scripts',dirs_exist_ok=True)
for name in ('LICENSE.txt','THIRD-PARTY-NOTICES.md','ACTIONS.md'):
    shutil.copy2(source/name,dest/name)
readme = '''EA Native Automation 2.2.15 — Mac preview

EASY INSTALL
1. Quit REAPER.
2. Open EA-Native-Automation-v2.2.15-macOS.pkg and continue through Installer.
3. Restart REAPER. Actions > Show action list:
   EA: Native Automation (JUCE) - toggle panel

Installs for your user to ~/Library/Application Support/REAPER. Intel and Apple Silicon are in one binary. No compilation or separate dependencies needed. Search EA: Automation for all 104 shortcut actions.

This preview is ad-hoc signed, not Developer ID signed or Apple notarized. macOS may block the downloaded installer. After checking that this is the package you intended to open, use System Settings > Privacy & Security > Open Anyway if offered. Do not disable Gatekeeper. Apple guidance: https://support.apple.com/102445

PORTABLE / CUSTOM RESOURCE PATH
In REAPER use Options > Show REAPER resource path in Finder, then quit REAPER. Copy the CONTENTS of Manual install/UserPlugins into that resource folder's UserPlugins. Keep EA_Native_Automation/engine.lua beside the dylib in its subfolder. Optional launcher is in Scripts. Restart REAPER.

TESTING
Compiled as a universal dylib on a hosted Mac. Automated layout, action-catalog, bridge and Lua engine model tests passed on the build host. See BUILD-VALIDATION.txt for actual checks. Live REAPER docking, scaling and automation still need Mac testing; track volume/pan Manual Write and unwanted envelope-lane visibility have known reports. Please try it on a copy of a project.

UPGRADE / REMOVE
The Installer backs up earlier EA binary/engine files under the REAPER resource folder's EA Native Automation Backups. It leaves your other extensions, themes, scripts and preferences alone. To remove, quit REAPER and remove UserPlugins/reaper_ea_automation.dylib and UserPlugins/EA_Native_Automation; the optional Scripts/EA_Compact_Automation.lua may also be removed.

SOURCE / LICENSE
AGPL-3.0-or-later; see LICENSE.txt and THIRD-PARTY-NOTICES.md. Complete corresponding source, build scripts and pinned dependency archives accompany this test build in EA-Native-Automation-v2.2.15-macOS-Source.zip. REAPER and its Inter fonts are not redistributed.
'''
(dest/'READ ME.txt').write_text(readme,encoding='utf-8')
sourcezip = dest/f'EA-Native-Automation-v{version}-macOS-Source.zip'
with zipfile.ZipFile(sourcezip,'w',zipfile.ZIP_DEFLATED) as z:
    for folder in ('Source','BuildSupport','macOS'):
        for p in sorted((root/'snapshot'/folder).rglob('*')):
            if p.is_file() and 'build' not in p.relative_to(root/'snapshot').parts:
                z.write(p,p.relative_to(root/'snapshot').as_posix())
    z.write(Path(__file__),'macOS/mac_package.py')
validation = {'version':version,'architectures':run('lipo','-archs',str(dylib)).strip(),'signing':'ad-hoc, not notarized','macOS':run('sw_vers').strip(),'dylib_sha256':hashlib.sha256(dylib.read_bytes()).hexdigest(),'native_ctest':(root/'build/Testing/Temporary/LastTest.log').read_text(),'live_reaper_tested':False}
(dest/'BUILD-VALIDATION.txt').write_text(json.dumps(validation,indent=2),encoding='utf-8')
# Exercise actual user-domain installation on the disposable CI Mac, never on the user's computer.
print(run('installer','-pkg',str(setup),'-target','CurrentUserHomeDirectory'))
installed = Path.home()/'Library/Application Support/REAPER'
for rel in ('UserPlugins/reaper_ea_automation.dylib','UserPlugins/EA_Native_Automation/engine.lua','Scripts/EA_Compact_Automation.lua'):
    assert (installed/rel).read_bytes()==(resource/rel).read_bytes(), 'Wrong installed content: '+rel
print(run('installer','-pkg',str(setup),'-target','CurrentUserHomeDirectory'))
assert list((installed/'EA Native Automation Backups').glob('*/reaper_ea_automation.dylib'))
(dest/'BUILD-VALIDATION.txt').write_text(json.dumps(validation,indent=2)+'\nPASS: real user-domain installation and upgrade backup on disposable hosted Mac.\n',encoding='utf-8')
checks = []
for p in sorted(dest.rglob('*')):
    if p.is_file(): checks.append(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(dest).as_posix())
(dest/'SHA256SUMS.txt').write_text('\n'.join(checks)+'\n',encoding='ascii')
print('PASS: universal binary, ad-hoc signature, package structure, source archive, real install/upgrade, engine parity')

