# Executar no iPhone

O projeto foi adaptado para iOS 13 ou superior, com Flutter 3.41 ou superior (referência usada: 3.44.6). As mudanças incluem CocoaPods, ciclo de vida UIScene, retorno do login Google, permissão de agenda, notificações iOS, seleção de backup no app Arquivos e banco ativo em Application Support. Os backups exportados ficam em Arquivos → No Meu iPhone → Empréstimos → Backups.

## Google Drive

No mesmo projeto Google Cloud usado no Android, crie um cliente OAuth **iOS**, com o Bundle ID do app. O Bundle ID atual é `com.example.emprestimos`; se já existir um identificador Apple para este projeto, utilize-o também no Google. O cliente Android e seu SHA-1 não substituem o cliente iOS.

Configure o ID público recebido (não é necessário client secret):

```sh
python3 tool/configure_ios.py --client-id SEU_ID_IOS.apps.googleusercontent.com
```

Se precisar mudar o Bundle ID, inclua `--bundle-id seu.identificador`. O script ajusta os identificadores do Runner/RunnerTests e o esquema de retorno do Google. Ele não altera o pacote Android. O app continua utilizável localmente sem OAuth; o Drive mostra uma mensagem de configuração pendente, sem chamar o SDK com um ID inválido.

## Compilar no Mac

Instale Xcode com o SDK iOS e CocoaPods. No Mac, execute na pasta do projeto:

```sh
flutter pub get
python3 tool/check_ios.py --require-google
cd ios
pod install
cd ..
flutter build ios --simulator --debug
open ios/Runner.xcworkspace
```

Omitir `--require-google` permite verificar o projeto sem ativar o Drive. Use o workspace, não apenas o xcodeproj. No Xcode, selecione Runner → Signing & Capabilities → sua equipe Apple, confirme o Bundle ID, selecione o iPhone conectado e execute. Em um iPhone físico, a assinatura/provisionamento deve pertencer à sua conta Apple. Para distribuir via TestFlight/App Store, configure o aplicativo no App Store Connect e gere o arquivo com `flutter build ipa` no Mac. Não existem certificado, Team ID ou credenciais Apple inventados no projeto.

Os arquivos Generated.xcconfig e flutter_export_environment.sh são locais: `flutter pub get` no Mac recria os caminhos do ambiente. Não reutilize os caminhos gerados no Windows.

## Compilar pelo GitHub Actions

O workflow `.github/workflows/ios-simulator.yml` usa macOS 15 e Flutter 3.44.6. Executa os testes e a verificação de configuração iOS antes de compilar para simulador, sem certificados Apple. É acionado manualmente ou por alterações relevantes em pushes para master/main e pull requests.

Depois de enviar o commit ao GitHub, abra **Actions → iOS Simulator → Run workflow**. Ao concluir com sucesso, baixe o artefato **emprestimos-ios-simulator**. Extraia o download e depois `emprestimos-ios-simulator.zip` para obter `Runner.app`. O ZIP interno preserva as permissões e os links do aplicativo. Os artefatos ficam disponíveis por 7 dias.

Em um Mac com um simulador aberto, instale com `xcrun simctl install booted /caminho/Runner.app` e abra com `xcrun simctl launch booted com.example.emprestimos`. A arquitetura deve ser compatível com a do simulador de destino. Para serviços online, confira os requisitos de arquitetura e envie o ZIP interno, quando aceito pelo serviço.

Esse arquivo é destinado ao simulador: não é um IPA instalável no iPhone nem oferece uma sessão interativa no GitHub. A execução bem-sucedida confirma testes e compilação, mas o login Google e os fluxos de uso ainda precisam de validação interativa. A compilação para iPhone/TestFlight continua exigindo assinatura e provisionamento Apple.

## Comportamento no iPhone

- A agenda é opcional: o cadastro manual continua disponível. O texto da permissão está no Info.plist.
- Em Configurações, “Ativar lembretes de vencimento” solicita permissão de notificações. São agendados os próximos 64 lembretes; a lista é renovada ao abrir/retomar o app ou alterar pagamentos e empréstimos.
- O banco em uso e a fila automática ficam privados. Apenas os backups exportados intencionalmente ficam no app Arquivos.
- A importação permite selecionar arquivos de dados e valida integridade, tabelas e versão antes de substituir o banco.
- WhatsApp continua usando o link HTTPS externo já existente.
- O backup atual e os históricos diários continuam funcionando. O iOS pode suspender ou encerrar o processo: não é garantido executar/envia-los exatamente à meia-noite. A retomada fecha os dias pendentes antes de aceitar novas alterações. Não foi declarado um modo de segundo plano fictício para contornar essa restrição.

## Validação e pendências

A análise Dart e os testes de lógica podem ser executados no Windows. A verificação estática `python3 tool/check_ios.py` confere os arquivos Apple e a configuração OAuth. Esses checks não substituem compilação Swift, resolução dos pods e teste em simulador/iPhone, que exigem macOS/Xcode e não foram executados neste ambiente Windows.

No iPhone, validar: login/restauração Google, cadastro manual e por agenda com permissão concedida/negada, criação/pagamento/edição, exportação/importação no Arquivos, notificações, retomada offline e fechamento diário. Para publicação, conferir o relatório de privacidade agregado dos plugins e as declarações do App Store Connect conforme o uso efetivo dos dados; o manifesto de APIs não substitui essas declarações.

Referências oficiais: [Flutter iOS](https://docs.flutter.dev/platform-integration/ios/setup), [UIScene](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate), [Google Sign-In iOS](https://developers.google.com/identity/sign-in/ios/start-integrating), [manifestos de privacidade Apple](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest).

## Keychain e login Google no simulador

O Runner declara seu grupo privado de Keychain em `Runner.entitlements`. No
iPhone, o Xcode resolve o prefixo da conta Apple durante a assinatura normal.
No simulador, a identidade `-` usa assinatura local (ad hoc), sem certificado
Apple. O workflow não usa mais `--no-codesign`: o Xcode precisa processar os
entitlements durante a compilação. Depois, verifica a assinatura e o grupo
de Keychain incorporado antes de publicar o ZIP.

Após gerar um novo artefato, envie o ZIP interno como nova versão no Appetize
e abra uma nova sessão dessa versão. Se o erro persistir, capture os logs do
login, especialmente o código OSStatus do Keychain. O serviço pode alterar a
assinatura durante a instalação; o teste no Appetize/iPhone continua necessário.

A verificação de Keychain examina a seção `__TEXT,__entitlements` de cada
arquitetura do executável do simulador. Quando essa seção está ausente, usa
os entitlements da assinatura. O Xcode pode manter apenas permissões de
depuração na assinatura do simulador; por isso, consultar só `codesign` não
é suficiente. Permissões ausentes, grupos incorretos ou variáveis não
resolvidas continuam reprovando a verificação.
