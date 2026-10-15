"""Configure public OAuth identifiers; no client secret is needed for iOS."""
import argparse
from pathlib import Path
import re


def configure(root, client_id, bundle_id=None):
    if not re.fullmatch(r'[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com', client_id):
        raise ValueError('Informe o ID completo de um cliente OAuth do tipo iOS')
    if bundle_id and not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)+', bundle_id):
        raise ValueError('Bundle ID inválido')
    project = root / 'ios/Runner.xcodeproj/project.pbxproj'
    text = project.read_text(encoding='utf-8')
    if bundle_id:
        def replace(match):
            suffix = '.RunnerTests' if match[1].endswith('.RunnerTests') else ''
            return f'PRODUCT_BUNDLE_IDENTIFIER = {bundle_id}{suffix};'
        text = re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);', replace, text)
        project.write_text(text, encoding='utf-8')
    reversed_id = '.'.join(reversed(client_id.split('.')))
    (root / 'ios/Flutter/GoogleSignIn.xcconfig').write_text(
        '// Identificadores públicos do cliente OAuth iOS.\n'
        f'GOOGLE_IOS_CLIENT_ID = {client_id}\n'
        f'GOOGLE_IOS_REVERSED_CLIENT_ID = {reversed_id}\n', encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client-id', required=True)
    parser.add_argument('--bundle-id', help='Opcional: Bundle ID cadastrado na Apple e no cliente OAuth iOS')
    args = parser.parse_args()
    try:
        configure(Path(__file__).resolve().parent.parent, args.client_id, args.bundle_id)
    except ValueError as error:
        parser.error(str(error))
    print('Cliente OAuth iOS e esquema de retorno configurados. Gere novamente o aplicativo no Mac.')
