# Pagamento parcial e acordos

Na tela inicial, o ícone laranja Pagamento parcial abre Valor pago e Parcelar.
Sem Parcelar, o pagamento abate os juros da cobrança original, preservando o capital.
Nos acordos já existentes, abate o saldo da parcela. Não aceita valores maiores que
o saldo nessa modalidade. Ao completar os juros, aplica a regra existente de gerar
a próxima cobrança mensal; ao completar uma parcela de acordo, encerra apenas essa
parcela, sem gerar cobrança adicional.

Com Parcelar, Total para quitação é o saldo restante, já descontado o valor pago.
O acordo substitui todas as cobranças em aberto do empréstimo selecionado, inclusive
as vencidas. Parcelas já pagas são preservadas. Não acrescenta juros ao total
informado. Vencimentos mensais começam um mês após o pagamento; dias inexistentes
no mês são ajustados ao último dia. As diferenças de centavos são distribuídas nas
primeiras parcelas, mantendo a soma exata. Permite 1 a 600 parcelas com pelo menos
um centavo cada.

Cobranças com pagamento parcial e cobranças transferidas para um acordo aparecem
como Parcial, em laranja, com filtro próprio. Cobranças transferidas não entram no
total a receber nem geram lembretes. Uma parcela com saldo parcial vencido também
pode ser encontrada em Vencido. Em Aberto mostra cobranças ainda sem pagamento.
O novo acordo começa em aberto e suas parcelas tornam-se parciais conforme recebem
pagamentos menores que o saldo.

O ícone Origem do parcelamento e o histórico mostram o valor/data do empréstimo,
o pagamento recebido, todas as parcelas anteriores e os pagamentos parciais. A
origem é uma cópia do estado na renegociação, inclusive de acordos anteriores.
Também aparece nos detalhes do cliente e no PDF. Acordos não são somados como novo
capital emprestado. Empréstimos com pagamentos parciais ou renegociação não permitem
edição/exclusão pelos controles antigos, evitando apagar pagamentos e vínculos.

Schema SQLite 9: adiciona pagamentos_parciais, acumulado pago, marca de transferência,
tipo de parcela e origem no empréstimo. Migração preserva os dados anteriores.
Pagamento, encerramento das cobranças antigas, novo acordo e histórico são gravados
em uma única transação e acionam o backup automático após a confirmação.
Backups desta versão exigem aplicativo atualizado para restauração.
