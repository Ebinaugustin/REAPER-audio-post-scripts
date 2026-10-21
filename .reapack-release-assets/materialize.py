# @noindex
"""Reassemble release upload parts, verify SHA256, and retain the original bytes."""
from pathlib import Path
import base64, hashlib, json

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root/'.reapack-release-assets/v2.2.4/assets.json').read_text())
for asset in manifest:
    target = root/asset['path']
    if target.exists():
        content = target.read_bytes()
    else:
        encoded = ''.join((root/part).read_text().strip() for part in asset['parts'])
        content = base64.b64decode(encoded, validate=True)
    if len(content) != asset['bytes'] or hashlib.sha256(content).hexdigest() != asset['sha256']:
        raise SystemExit('Release asset integrity check failed: '+asset['path'])
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(content)
    print('Verified: '+asset['path'])
