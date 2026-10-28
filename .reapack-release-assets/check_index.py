# @noindex
from pathlib import Path
import hashlib,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
package=ET.parse(root/'index.xml').getroot().find("./category/reapack[@name='EA_Native_Automation.ext']")
assert package is not None and package.attrib['type']=='extension'
versions={v.attrib['name']:v for v in package.findall('version')}
assert '2.2.4' in versions and '2.2.15' in versions
assert len(versions['2.2.4'].findall('source'))==8
sources=versions['2.2.15'].findall('source')
assert len(sources)==26,len(sources)
sets={p:set() for p in ('win64','darwin64','darwin-arm64')}
for source in sources:
    platform=source.attrib['platform'];name=source.attrib['file']
    assert platform in sets and name not in sets[platform]
    sets[platform].add(name)
    assert '..' not in name.split('/') and not name.startswith('/')
    assert source.text=='https://raw.githubusercontent.com/Ebinaugustin/REAPER-audio-post-scripts/ea-native-automation-v2.2.15/Extensions/EA_Native_Automation/v2.2.15/'+name
    assert (root/'Extensions/EA_Native_Automation/v2.2.15'/name).is_file()
for platform,names in sets.items():
    assert 'EA_Native_Automation/engine.lua' in names
    assert ('reaper_ea_automation.dll' if platform=='win64' else 'reaper_ea_automation.dylib') in names
assert sets['darwin64']==sets['darwin-arm64']
print('PASS: official index includes 2.2.15 Windows x64 + Intel/ARM Mac sets; old 2.2.4 remains; 26 safe immutable-tag downloads.')
