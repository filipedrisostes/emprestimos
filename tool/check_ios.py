"""Static iOS checks runnable on Windows or macOS; not an Xcode build."""
from pathlib import Path
import plistlib
import re
import argparse

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--require-google', action='store_true')
args = parser.parse_args()
info = plistlib.loads((root / 'ios/Runner/Info.plist').read_bytes())
privacy = plistlib.loads((root / 'ios/Runner/PrivacyInfo.xcprivacy').read_bytes())
framework = plistlib.loads((root / 'ios/Flutter/AppFrameworkInfo.plist').read_bytes())
project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
entitlements = plistlib.loads((root / 'ios/Runner/Runner.entitlements').read_bytes())
assert entitlements['keychain-access-groups'] == ['$(AppIdentifierPrefix)$(CFBundleIdentifier)']
assert project.count('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;') == 3
assert info['NSContactsUsageDescription']
assert info['UIFileSharingEnabled'] and info['LSSupportsOpeningDocumentsInPlace']
assert info['UIApplicationSceneManifest']['UISceneConfigurations']
assert framework['MinimumOSVersion'] == '13.0'
assert set(re.findall(r'IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);', project)) == {'13.0'}
assert project.count('A87000000000000000000002 /* PrivacyInfo.xcprivacy */') == 3
assert privacy['NSPrivacyTracking'] is False
for mode in ('Debug', 'Release'):
    config = (root / f'ios/Flutter/{mode}.xcconfig').read_text()
    assert 'Pods/Target Support Files/' in config and 'GoogleSignIn.xcconfig' in config
config = (root / 'ios/Flutter/GoogleSignIn.xcconfig').read_text()
client = re.search(r'^GOOGLE_IOS_CLIENT_ID\s*=\s*([^\r\n]*)', config, re.M)[1].strip()
valid = bool(re.fullmatch(r'[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com', client))
if valid:
    assert '.'.join(reversed(client.split('.'))) in config
elif args.require_google:
    raise SystemExit('PENDENTE: configurar cliente OAuth iOS com tool/configure_ios.py')
print('Estrutura iOS, permissões, CocoaPods, deployment target e manifesto: OK')
print('Google OAuth iOS: ' + ('configurado (validar no aparelho)' if valid else 'PENDENTE: ID do cliente iOS'))
print('Compilação Swift/CocoaPods e assinatura: validar no Mac com Xcode.')
