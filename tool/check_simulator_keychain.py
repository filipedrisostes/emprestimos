"""Verify the built simulator app, rather than only its source entitlements."""
import plistlib
from pathlib import Path
import subprocess
import sys


def validate(info, entitlements):
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneSimulator']:
        raise ValueError('Expected an iOS Simulator build')
    bundle = info['CFBundleIdentifier']
    groups = entitlements.get('keychain-access-groups', [])
    if not groups or any('$(' in group or '*' in group for group in groups):
        raise ValueError('Keychain groups are absent or unresolved')
    if not any(group == bundle or group.endswith('.' + bundle) for group in groups):
        raise ValueError('No private Keychain group for this app')


def main():
    app = Path(sys.argv[1])
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    signed = subprocess.run(
        ['codesign', '--display', '--entitlements', ':-', str(app)],
        check=True, capture_output=True,
    )
    entitlements = plistlib.loads(signed.stdout)
    validate(info, entitlements)
    print('Simulator signature contains resolved Keychain access: OK')


if __name__ == '__main__':
    main()
