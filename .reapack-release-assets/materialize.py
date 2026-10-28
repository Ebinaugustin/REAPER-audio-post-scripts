# @noindex
"""Materialize only verified 2.2.15 binaries/source; preserve earlier releases."""
from pathlib import Path
import base64,gzip,hashlib,io,json,struct,sys,urllib.request,zipfile

root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'.reapack-release-assets/v2.2.15/assets.json').read_text(encoding='utf-8'))
dest=root/'Extensions/EA_Native_Automation/v2.2.15'

def checked(data,expected,label):
    if hashlib.sha256(data).hexdigest()!=expected:raise SystemExit('SHA256 mismatch: '+label)
    return data

asset=manifest['windows']
target=root/asset['path']
if target.exists():dll=target.read_bytes()
else:
    encoded=''.join((root/p).read_text(encoding='ascii').strip() for p in asset['parts'])
    dll=gzip.decompress(base64.b64decode(encoded,validate=True))
checked(dll,asset['sha256'],'Windows DLL')
assert len(dll)==asset['bytes'] and dll[:2]==b'MZ'
assert struct.unpack_from('<H',dll,struct.unpack_from('<I',dll,0x3c)[0]+4)[0]==0x8664
target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(dll)

archive=Path(sys.argv[1]).read_bytes() if len(sys.argv)>1 else urllib.request.urlopen(manifest['mac_archive']['url'],timeout=120).read()
checked(archive,manifest['mac_archive']['sha256'],'original Mac delivery archive')
with zipfile.ZipFile(io.BytesIO(archive)) as z:
    prefix='EA-Native-Automation-v2.2.15-macOS/'
    dylib=checked(z.read(prefix+'Manual install/UserPlugins/reaper_ea_automation.dylib'),manifest['mac_dylib_sha256'],'Mac universal dylib')
    assert dylib[:4]==bytes.fromhex('cafebabe')
    count=struct.unpack_from('>I',dylib,4)[0]
    assert {struct.unpack_from('>I',dylib,8+i*20)[0] for i in range(count)}=={0x1000007,0x100000c}
    (dest/'reaper_ea_automation.dylib').write_bytes(dylib)
    source=checked(z.read(prefix+'EA-Native-Automation-v2.2.15-macOS-Source.zip'),manifest['source_sha256'],'complete corresponding source')
    (dest/'EA-Native-Automation-2.2.15-Source.zip').write_bytes(source)
    engine=z.read(prefix+'Manual install/UserPlugins/EA_Native_Automation/engine.lua')
    checked(engine,manifest['engine_sha256'],'Mac engine')
    assert (dest/'EA_Native_Automation/engine.lua').read_bytes()==engine
    (dest/'EA_Native_Automation/MAC-BUILD-VALIDATION.txt').write_bytes(z.read(prefix+'BUILD-VALIDATION.txt'))
with zipfile.ZipFile(io.BytesIO(source)) as z:
    assert z.testzip() is None
    assert z.read('Source/runtime/EA_Native_Automation/engine.lua')==engine
    for name in ('Source/vendor/JUCE-8.0.12.zip','Source/vendor/reaper-sdk.zip','Source/vendor/WDL.zip','Source/src/PluginEntry.cpp','Source/CMakeLists.txt'):
        assert name in z.namelist(),name
checks=[]
for p in sorted(dest.rglob('*')):
    if p.is_file() and p.name!='SHA256SUMS.txt':checks.append(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(dest).as_posix())
(dest/'SHA256SUMS.txt').write_text('\n'.join(checks)+'\n',encoding='ascii',newline='\n')
print('PASS: exact Windows x64 DLL, Mac universal dylib, matching engine and complete pinned-dependency source verified.')
