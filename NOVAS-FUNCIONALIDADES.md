# Novas funcionalidades

- **Histórico de alterações:** menu principal; também acessível nos detalhes do cliente. Registra criação, edição e exclusão de clientes, empréstimos, parcelas e configurações, com valores anteriores e posteriores. Começa nesta versão, sem reconstruir eventos antigos. Os registros acompanham o banco restaurado; uma restauração adiciona um evento próprio.
- **Extrato por cliente:** abra Clientes, selecione o cliente e toque no ícone de extrato. Consulte empréstimos e parcelas ou compartilhe o PDF. O capital aparece por empréstimo; valores das parcelas representam juros conforme o funcionamento atual do app. O extrato não é comprovante bancário.
- **Bloqueio por biometria:** ative em Configurações após cadastrar biometria no aparelho. O app exige autenticação ao abrir e voltar do segundo plano. O sistema pode oferecer o código do aparelho como alternativa. Essa preferência é própria do dispositivo e não acompanha o backup. O bloqueio protege a interface, sem criptografar o SQLite ou arquivos exportados.
- **Situação do backup:** Backup & Restauração mostra último envio confirmado, conta, arquivo e pendências. Ao restaurar, escolha a cópia atual ou um histórico diário. A confirmação informa que a restauração substitui os dados locais, inclusive configurações e histórico.
- **Cadastrar Empréstimo:** digite ou selecione o Cliente. Um nome novo cria cliente e empréstimo na mesma transação e abre Editar Cliente para adicionar WhatsApp. Se cancelar essa edição, o empréstimo permanece salvo e o telefone pode ser preenchido depois. Nomes iguais desconsideram maiúsculas e espaços extras; nomes duplicados exigem seleção explícita.

## Validação

36 testes Flutter aprovados, incluindo migração de configurações, cadastro atômico, rollback, histórico, autenticação simulada, PDF e navegação para editar o cliente novo. APK de depuração compilado. Configuração estática iOS verificada. Biometria nativa, compartilhamento do PDF e acesso real ao Google Drive precisam ser conferidos nos aparelhos; a compilação iOS depende de macOS/GitHub Actions.
