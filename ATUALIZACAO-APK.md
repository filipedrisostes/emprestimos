# Atualização baseada na APK

O projeto foi reconstruído a partir do código existente, dos recursos extraídos e dos fluxos observados na APK fornecida. O Dart compilado da APK não permite recuperar fielmente o código-fonte original. Esta entrega não certifica equivalência integral de todas as telas e comportamentos.

## Implementado

- Empréstimos com parcelas, pagamento de juros, quitação e edição do empréstimo.
- Migração aditiva dos bancos do projeto antigo e da APK (versão 5) para a versão 6, preservando identificadores e pagamentos.
- Filtros mensais, detalhes por cliente, estatísticas e mensagens personalizadas.
- Backup local e integração de backup com Google Drive; validação do banco antes da restauração.
- Agendamento de notificações Android e permissões correspondentes.

## Verificação

- Oito testes automatizados aprovados: migrações, parcelas, pagamentos, edição, limites mensais, backup/restauração e interface de backup.
- APK Android de depuração compilada e instalada no emulador Android 15.
- Banco com dados fictícios criado pela APK original aberto na nova versão; cliente, primeira parcela de três, valor de R$ 1.000 e juros de R$ 300 preservados na tela.
- Análise Dart sem erros; aviso de código legado não utilizado em background_backup.dart.

## Limites da validação

- Login e backup reais no Google Drive precisam ser verificados com a conta e configuração OAuth do proprietário.
- Entrega de notificações em segundo plano e seus horários precisam ser verificados em aparelho físico.
- Aparência e fluxos foram reconstruídos; não houve comparação exaustiva de todas as combinações de dados e telas.
- A assinatura da APK de teste difere da APK original. Para atualizar uma instalação existente mantendo seus dados é necessária a chave original de assinatura. Não desinstale a versão de uso sem antes exportar e conferir seu backup.
- A adaptação e compilação para iOS ficam para a próxima etapa solicitada pelo proprietário.

O snapshot anterior e os registros de validação estão em `C:\Users\caram\OneDrive\Documents\ChatGPT\emprestimos\apk-analysis`.
