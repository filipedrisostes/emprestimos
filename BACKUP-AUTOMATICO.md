# Backup automático no Google Drive

Cada operação confirmada que altera clientes, empréstimos, parcelas ou pagamentos gera uma cópia SQLite completa, com nome `bkp_auto_<data UTC>_<identificador>.db`. Uma operação com várias parcelas gera uma cópia do resultado completo. Consultas, operações sem linhas afetadas e transações desfeitas não geram cópias. A restauração também gera uma cópia dos dados restaurados.

As cópias ficam na pasta privada do aplicativo até o Google Drive confirmar o envio. São enviadas em ordem, sem bloquear a interface pela rede. Falhas de rede ou autenticação preservam os arquivos locais; há novas tentativas ao voltar a conexão, ao retornar ao app, ao abrir o app e a cada minuto enquanto o processo estiver ativo. Não há garantia de execução com o aplicativo encerrado pelo Android: a fila continua na próxima abertura.

A conta conectada é utilizada silenciosamente. Se for necessário autenticar, abra Backup & Restauração e use “Conectar Google / tentar envios pendentes”. O email digitado nas configurações não substitui a conta autenticada do Google. Uma cópia já vinculada a uma conta não é enviada para outra conta automaticamente.

Os arquivos não substituem os anteriores e não são apagados automaticamente do Drive. O volume ocupado cresce conforme o tamanho do banco e a quantidade de alterações. Cada upload tem ID persistido antes do envio para evitar duplicação em novas tentativas. A data de criação no Drive corresponde à data da cópia, para que envios offline antigos não substituam a prioridade dos backups mais recentes na restauração.

A tela de backup informa pendências ou envio concluído. Se faltar armazenamento para gerar uma cópia depois de salvar, os dados continuam no banco e o app tenta recuperar a cópia antes da próxima alteração; caso ainda não consiga, bloqueia novas alterações para não perder esse estado. Desinstalar o aplicativo ou limpar seus dados remove as cópias que ainda não foram enviadas.

Validação: 14 testes automatizados aprovados, incluindo snapshots distintos, ordem de envio, fila após reinício, alterações concorrentes, rollback, falha de armazenamento e restauração. Teste Android no emulador com dados fictícios. O envio autenticado à conta real do proprietário precisa ser conferido no aparelho; os testes de fila usam um transporte simulado.
