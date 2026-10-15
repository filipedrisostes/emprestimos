"""Verify the built simulator app, rather than only its source entitlements."""
import plistlib
from pathlib import Path
import subprocess
import struct
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


def embedded_entitlements(data):
    """Read each Mach-O slice's simulator entitlements, including universal apps."""
    magic = data[:4]
    if magic in (b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
        wide = magic == b'\xca\xfe\xba\xbf'
        count = struct.unpack_from('>I', data, 4)[0]
        entries = []
        for index in range(count):
            pos = 8 + index * (32 if wide else 20)
            offset, size = struct.unpack_from('>QQ' if wide else '>II', data, pos + 8)
            if offset + size > len(data):
                raise ValueError('Truncated universal executable')
            entries.extend(embedded_entitlements(data[offset:offset + size]))
        return entries
    if magic != b'\xcf\xfa\xed\xfe':
        raise ValueError('Expected a 64-bit iOS Simulator executable')
    count = struct.unpack_from('<I', data, 16)[0]
    pos = 32
    for _ in range(count):
        command, size = struct.unpack_from('<II', data, pos)
        if size < 8 or pos + size > len(data):
            raise ValueError('Invalid Mach-O load command')
        if command == 0x19:  # LC_SEGMENT_64
            sections = struct.unpack_from('<I', data, pos + 64)[0]
            for index in range(sections):
                section = pos + 72 + index * 80
                if section + 80 > pos + size:
                    raise ValueError('Invalid Mach-O section table')
                name = data[section:section + 16].rstrip(b'\0')
                segment = data[section + 16:section + 32].rstrip(b'\0')
                if name == b'__entitlements' and segment == b'__TEXT':
                    length = struct.unpack_from('<Q', data, section + 40)[0]
                    offset = struct.unpack_from('<I', data, section + 48)[0]
                    if offset + length > len(data):
                        raise ValueError('Truncated simulator entitlements')
                    return [plistlib.loads(data[offset:offset + length].rstrip(b'\0'))]
        pos += size
    return [None]


def main():
    app = Path(sys.argv[1])
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    signed = subprocess.run(
        ['codesign', '--display', '--entitlements', ':-', str(app)],
        check=True, capture_output=True,
    )
    signature = plistlib.loads(signed.stdout) if signed.stdout.strip() else {}
    executable = app / info['CFBundleExecutable']
    slices = embedded_entitlements(executable.read_bytes())
    if not slices:
        raise ValueError('No executable architectures found')
    for index, entitlements in enumerate(slices):
        source = '__TEXT,__entitlements' if entitlements is not None else 'signature'
        selected = entitlements if entitlements is not None else signature
        print(f'Architecture {index + 1}: {source}: {selected}', flush=True)
        validate(info, selected)
    print('Built simulator app contains resolved Keychain access: OK')


if __name__ == '__main__':
    main()
