import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/transacao.dart';

/// Readable immutable snapshot, also reused in history and the PDF statement.
List<String> loanOriginLines(String encoded) {
  final money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  String date(Object? value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null
        ? '—'
        : DateFormat('dd/MM/yyyy').format(parsed.toLocal());
  }

  final lines = <String>[];
  var current = encoded;
  while (true) {
    final info = jsonDecode(current) as Map<String, dynamic>;
    final loan = info['emprestimo'] as Map<String, dynamic>;
    lines.addAll([
      'Origem: empréstimo #${loan['id']}',
      'Valor emprestado/acordado: ${money.format(loan['valor_emprestado'])}',
      'Data do empréstimo: ${date(loan['data_emprestimo'])}',
      'Valor pago na renegociação: ${money.format(info['valor_pago'])} em ${date(info['data_pagamento'])}',
      'Saldo para quitação: ${money.format(info['total_quitacao'])} em ${info['quantidade_parcelas']} parcelas',
      'Parcelas anteriores ao acordo:',
    ]);
    for (final row in (info['parcelas'] as List)) {
      final t = Transacao.fromMap(Map<String, dynamic>.from(row as Map));
      lines.add(
          'Parcela ${t.parcela} (#${t.id}): ${money.format(t.retorno)}; vencimento ${date(row['data_vencimento'])}; ${t.situacao}; pagamentos parciais ${money.format(t.valorPagoParcial)}; saldo ${money.format(t.saldo)}${t.dataPagamentoCompleto != null ? '; quitada em ${date(row['data_pagamento_completo'])}' : t.dataPagamentoRetorno != null ? '; juros pagos em ${date(row['data_pagamento_retorno'])}' : ''}');
    }
    for (final payment in (info['pagamentos'] as List? ?? [])) {
      lines.add(
          'Pagamento registrado #${payment['id']}: ${money.format(payment['valor'])} em ${date(payment['data'])} (${payment['tipo']}, parcela #${payment['transacao_id']})');
    }
    final previous = loan['origem_historico'];
    if (previous is! String || previous.isEmpty) break;
    lines.add('Histórico do acordo anterior:');
    current = previous;
  }
  return lines;
}
