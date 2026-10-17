# Backup atual e histórico diário

O Google Drive mantém `bkp_atual.db`, sobrescrito após cada operação que altera o banco, e `bkp_dia_AAAA-MM-DD.db`, com o último estado de cada dia no horário local do aparelho. O backup manual no Drive também atualiza `bkp_atual.db`.

À meia-noite, enquanto o processo do aplicativo estiver ativo, é feito o fechamento do dia anterior. Se o Android encerrar ou suspender o app, a próxima abertura/retomada realiza os fechamentos pendentes antes de permitir novas alterações. Não há um serviço Android independente que garanta execução com o app encerrado. Dias sem alterações usam o último estado conhecido, sem incluir alterações posteriores.

A cópia atual permanece no armazenamento privado mesmo depois do envio para permitir o fechamento diário. Sem internet, as mudanças do mesmo dia são consolidadas na cópia atual; os fechamentos de dias anteriores continuam na fila até serem enviados. Há tentativas ao reconectar, abrir/retomar e a cada minuto com o processo ativo.

Cada destino tem um ID estável no Drive. A cópia atual é atualizada pelo mesmo ID; cada histórico é criado uma única vez e protegido contra sobrescrita com conteúdo diferente. A tela de restauração permite escolher a cópia atual ou um histórico, mostrando a cópia atual primeiro, e mantém compatibilidade com backups antigos. Os arquivos antigos já existentes no Drive não são apagados por esta atualização.

A conta autenticada no Google determina o destino. A tela Backup & Restauração mostra o status e permite conectar a conta/tentar envios pendentes. A fila e os históricos locais pendentes são perdidos se os dados do app forem apagados ou ele for desinstalado.

Validação: 20 testes automatizados aprovados, incluindo sobrescrita via PATCH no mesmo ID (API simulada), reenvio sem duplicação, meia-noite, virada de mês/ano, dias sem uso, retomada, fila da versão anterior, alterações concorrentes, restauração e falta de espaço. O envio autenticado à conta real deve ser conferido no aparelho do proprietário.

## Configurações no SQLite (schema 7)

A tabela `configuracoes` possui um único registro (`id = 1`) e os campos
`email_padrao`, `juros_padrao`, `zap_padrao` e `dias_vencimento_padrao`.
Na primeira abertura sem esse registro, o app importa as quatro preferências
antigas do aparelho. Depois disso, SQLite é a fonte dessas configurações;
os valores antigos em SharedPreferences não sobrescrevem o banco.

Salvar a tela grava os quatro valores em uma transação e aciona o backup
automático. Salvar os mesmos valores não gera uma nova captura. Exportações
e backups novos incluem a tabela. Restaurar um backup novo recupera suas
configurações; backups antigos sem a tabela mantêm as configurações atuais.
Versões anteriores do app precisam ser atualizadas para restaurar schema 7.
As credenciais e a identificação da conta Google continuam fora dessa tabela.

## Histórico e status (schema 8)

O schema 8 adiciona `historico_alteracoes`. Backups novos incluem esse histórico e exigem o aplicativo atualizado para restauração. A tela mostra o último envio confirmado, a conta usada e a quantidade de arquivos pendentes. A data do último envio é local ao aparelho; não é uma consulta em tempo real ao Drive.
