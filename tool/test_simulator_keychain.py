import plistlib
import struct
import unittest

from check_simulator_keychain import embedded_entitlements, validate


def macho(entitlements):
    xml = plistlib.dumps(entitlements)
    data = bytearray(184)
    struct.pack_into('<IIIIIIII', data, 0, 0xfeedfacf, 0x100000c, 0, 2, 1, 152, 0, 0)
    struct.pack_into('<II', data, 32, 0x19, 152)
    struct.pack_into('<I', data, 96, 1)
    data[104:120] = b'__entitlements'.ljust(16, b'\0')
    data[120:136] = b'__TEXT'.ljust(16, b'\0')
    struct.pack_into('<QI', data, 144, len(xml), 184)
    return bytes(data) + xml


class KeychainTests(unittest.TestCase):
    info = {'CFBundleSupportedPlatforms': ['iPhoneSimulator'],
            'CFBundleIdentifier': 'com.example.emprestimos'}
    valid = {'keychain-access-groups': ['com.example.emprestimos']}

    def test_embedded_permissions(self):
        parsed = embedded_entitlements(macho(self.valid))
        self.assertEqual(parsed, [self.valid])
        validate(self.info, parsed[0])

    def test_universal_checks_both_slices(self):
        one, two = macho(self.valid), macho({'keychain-access-groups': []})
        header = struct.pack('>II', 0xcafebabe, 2)
        header += struct.pack('>IIIII', 0x100000c, 0, 48, len(one), 0)
        header += struct.pack('>IIIII', 0x1000007, 0, 48 + len(one), len(two), 0)
        parsed = embedded_entitlements(header + one + two)
        self.assertEqual(len(parsed), 2)
        with self.assertRaises(ValueError):
            validate(self.info, parsed[1])

    def test_missing_section(self):
        data = bytearray(macho(self.valid))
        struct.pack_into('<I', data, 16, 0)
        self.assertEqual(embedded_entitlements(data), [None])

    def test_invalid_permissions_rejected(self):
        for group in ('$(AppIdentifierPrefix)com.example.emprestimos', '*', 'another.app'):
            with self.subTest(group=group), self.assertRaises(ValueError):
                validate(self.info, {'keychain-access-groups': [group]})
        with self.assertRaises(ValueError):
            validate(self.info, {})

    def test_truncated_binary_rejected(self):
        with self.assertRaises(ValueError):
            embedded_entitlements(macho(self.valid)[:-20])


if __name__ == '__main__':
    unittest.main()
