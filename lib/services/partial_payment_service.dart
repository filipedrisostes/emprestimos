import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/transacao.dart';

class PartialPaymentService {
  final DatabaseHelper helper;
  PartialPaymentService(this.helper);

  static int cents(double value) {
    if (!value.isFinite || value <= 0 || value > 90000000000) {
      throw ArgumentError('Informe um valor positivo válido.');
    }
    final result = (value * 100).round();
    if (result < 1 || (value * 100 - result).abs() > 0.0001) {
      throw ArgumentError('Use no máximo duas casas decimais.');
    }
    return result;
  }

  // Clamp month ends: January 31 -> February 28, then March 31.
  static DateTime dueDate(DateTime date, int month) {
    final last = DateTime(date.year, date.month + month + 1, 0).day;
    return DateTime(
        date.year, date.month + month, date.day > last ? last : date.day);
  }

  static Future<void> settleInterest(
      Transaction txn, Transacao t, DateTime date) async {
    if (!t.emAberto || t.parcelamento) {
      throw StateError('Esta parcela não permite pagamento de juros.');
    }
    await txn.update(
        'transacoes', {'data_pagamento_retorno': date.toIso8601String()},
        where: 'id = ?', whereArgs: [t.id]);
    await txn.insert(
        'transacoes',
        Transacao(
          idTransacaoPai: t.idTransacaoPai,
          parcela: t.parcela + 1,
          idObrigado: t.idObrigado,
          dataEmprestimo: t.dataEmprestimo,
          dataVencimento: DateTime(
              (t.dataVencimento ?? t.dataEmprestimo).year,
              (t.dataVencimento ?? t.dataEmprestimo).month + 1,
              (t.dataVencimento ?? t.dataEmprestimo).day),
          valorEmprestado: t.valorEmprestado,
          percentualJuros: t.percentualJuros,
          retorno: t.retorno,
        ).toMap());
  }

  /// The optional total is the remaining debt, after the payment already received.
  /// Returns the new agreement id, or null for an interest/installment deduction.
  Future<int?> pay(int id, double amount, DateTime date,
      {double? total, int? installments, double? expectedPaid}) async {
    final paid = cents(amount);
    final balance = total == null ? null : cents(total);
    if (balance != null &&
        (installments == null ||
            installments < 1 ||
            installments > 600 ||
            installments > balance)) {
      throw ArgumentError(
          'Informe de 1 a 600 parcelas, de pelo menos R\$ 0,01 cada.');
    }
    return helper.write((txn) async {
      final rows =
          await txn.query('transacoes', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('Parcela não encontrada.');
      final t = Transacao.fromMap(rows.single);
      if (!t.emAberto ||
          (expectedPaid != null && expectedPaid != t.valorPagoParcial)) {
        throw StateError(
            'A parcela foi alterada. Atualize a tela antes de pagar.');
      }
      if (balance == null && paid > (t.saldo * 100).round()) {
        throw ArgumentError(
            'O pagamento supera o saldo de ${t.parcelamento ? 'esta parcela' : 'juros'}. Use Parcelar para registrar um novo acordo.');
      }
      final siblings = await txn.query('transacoes',
          where: 'id_transacao_pai = ?',
          whereArgs: [t.idTransacaoPai],
          orderBy: 'parcela, id');
      final parents = await txn.query('transacao_pai',
          where: 'id = ?', whereArgs: [t.idTransacaoPai]);
      if (parents.isEmpty) throw StateError('Empréstimo não encontrado.');
      await txn.insert('pagamentos_parciais', {
        'transacao_id': id,
        'id_obrigado': t.idObrigado,
        'data': date.toIso8601String(),
        'valor': paid / 100,
        'tipo': balance != null
            ? 'entrada'
            : t.parcelamento
                ? 'parcela'
                : 'juros',
      });
      if (balance == null) {
        final accumulated = (t.valorPagoParcial * 100).round() + paid;
        await txn.update(
            'transacoes', {'valor_pago_parcial': accumulated / 100},
            where: 'id = ?', whereArgs: [id]);
        if (accumulated == (t.retorno * 100).round()) {
          if (t.parcelamento) {
            await txn.update('transacoes',
                {'data_pagamento_completo': date.toIso8601String()},
                where: 'id = ?', whereArgs: [id]);
          } else {
            await settleInterest(txn, t, date);
          }
        }
        return null;
      }
      final ids = siblings.map((r) => r['id']).toList();
      final payments = await txn.query('pagamentos_parciais',
          where: 'transacao_id IN (${List.filled(ids.length, '?').join(',')})',
          whereArgs: ids,
          orderBy: 'id');
      final origin = jsonEncode({
        'emprestimo': parents.single,
        'parcelas': siblings,
        'pagamentos': payments,
        'valor_pago': paid / 100,
        'data_pagamento': date.toIso8601String(),
        'total_quitacao': balance / 100,
        'quantidade_parcelas': installments,
      });
      final parent = await txn.insert('transacao_pai', {
        'id_obrigado': t.idObrigado,
        'data_emprestimo': date.toIso8601String(),
        'valor_emprestado': balance / 100,
        'percentual_juros': 0,
        'qtde_parcelas': installments,
        'origem_emprestimo_id': t.idTransacaoPai,
        'origem_historico': origin,
      });
      await txn.update('transacoes', {'renegociado_em': date.toIso8601String()},
          where:
              'id_transacao_pai = ? AND data_pagamento_completo IS NULL AND data_pagamento_retorno IS NULL AND renegociado_em IS NULL',
          whereArgs: [t.idTransacaoPai]);
      final count = installments!;
      for (var i = 0; i < count; i++) {
        final value = balance ~/ count + (i < balance % count ? 1 : 0);
        await txn.insert(
            'transacoes',
            Transacao(
              idTransacaoPai: parent,
              idObrigado: t.idObrigado,
              parcela: i + 1,
              dataEmprestimo: date,
              dataVencimento: dueDate(date, i + 1),
              valorEmprestado: balance / 100,
              percentualJuros: 0,
              retorno: value / 100,
              parcelamento: true,
            ).toMap());
      }
      return parent;
    });
  }
}
