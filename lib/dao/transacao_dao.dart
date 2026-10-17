import '../services/partial_payment_service.dart';
import 'package:sqflite/sqflite.dart';
import '../models/obrigado.dart';
import '../database_helper.dart';
import '../models/transacao.dart';
import '../models/transacao_pai.dart';

class TransacaoDao {
  final DatabaseHelper dbHelper;
  TransacaoDao(this.dbHelper);
  // The reference app advances calendar months (rather than adding 30 days).
  static DateTime nextMonth(DateTime date, int offset) =>
      DateTime(date.year, date.month + offset, date.day);

  Future<int> criarEmprestimo(TransacaoPai pai, DateTime vencimento) async {
    if (pai.qtdeParcelas < 1 ||
        !pai.valorEmprestado.isFinite ||
        pai.valorEmprestado <= 0 ||
        !pai.percentualJuros.isFinite ||
        pai.percentualJuros < 0) {
      throw ArgumentError('Valor, juros ou quantidade de parcelas inválidos');
    }
    return dbHelper.write((txn) => _insert(txn, pai, vencimento));
  }

  Future<int> _insert(
      Transaction txn, TransacaoPai pai, DateTime vencimento) async {
    final id = await txn.insert('transacao_pai', pai.toMap());
    for (var i = 0; i < pai.qtdeParcelas; i++) {
      await txn.insert(
          'transacoes',
          Transacao(
            idTransacaoPai: id,
            parcela: i + 1,
            idObrigado: pai.idObrigado,
            dataEmprestimo: pai.dataEmprestimo,
            dataVencimento: nextMonth(vencimento, i),
            valorEmprestado: pai.valorEmprestado,
            percentualJuros: pai.percentualJuros,
            retorno: pai.valorEmprestado * pai.percentualJuros / 100,
          ).toMap());
    }
    return id;
  }

  static String normalizeName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Future<({int emprestimoId, Obrigado cliente, bool novo})> criarComCliente(
      TransacaoPai pai, DateTime vencimento,
      {required String nome, int? clienteId}) async {
    if (nome.trim().isEmpty ||
        pai.qtdeParcelas < 1 ||
        !pai.valorEmprestado.isFinite ||
        pai.valorEmprestado <= 0 ||
        !pai.percentualJuros.isFinite ||
        pai.percentualJuros < 0) {
      throw ArgumentError('Confira cliente, valor, juros e parcelas');
    }
    return dbHelper.write((txn) async {
      final rows = await txn.query('obrigados');
      final matches = rows
          .where((r) => clienteId != null
              ? r['id'] == clienteId
              : normalizeName(r['nome'] as String) == normalizeName(nome))
          .toList();
      if (matches.length > 1)
        throw StateError('Há clientes com esse nome. Selecione um na lista.');
      if (clienteId != null && matches.isEmpty)
        throw StateError('Cliente não encontrado');
      final novo = matches.isEmpty;
      final cliente = novo
          ? Obrigado(
              id: await txn.insert('obrigados', {
                'nome': nome.trim().replaceAll(RegExp(r'\s+'), ' '),
                'zap': ''
              }),
              nome: nome.trim().replaceAll(RegExp(r'\s+'), ' '),
              zap: '')
          : Obrigado.fromMap(matches.single);
      final actual = TransacaoPai(
          idObrigado: cliente.id!,
          dataEmprestimo: pai.dataEmprestimo,
          valorEmprestado: pai.valorEmprestado,
          percentualJuros: pai.percentualJuros,
          qtdeParcelas: pai.qtdeParcelas);
      final id = await _insert(txn, actual, vencimento);
      return (emprestimoId: id, cliente: cliente, novo: novo);
    });
  }

  Future<int> insertTransacao(Transacao t) async {
    return dbHelper.write((txn) async {
      final map = t.toMap();
      if (t.idTransacaoPai == null) {
        map['id_transacao_pai'] = await txn.insert(
            'transacao_pai',
            TransacaoPai(
                    idObrigado: t.idObrigado,
                    dataEmprestimo: t.dataEmprestimo,
                    valorEmprestado: t.valorEmprestado,
                    percentualJuros: t.percentualJuros,
                    qtdeParcelas: 1)
                .toMap());
      }
      return txn.insert('transacoes', map);
    });
  }

  Future<int> updateTransacao(Transacao t) async {
    return dbHelper.write((txn) async {
      final old =
          await txn.query('transacoes', where: 'id = ?', whereArgs: [t.id]);
      if (old.isEmpty) throw StateError('Transação não encontrada');
      await _assertEditable(txn, old.single['id_transacao_pai'] as int?);
      final map = t.toMap();
      map['id_transacao_pai'] ??= old.single['id_transacao_pai'];
      return txn.update('transacoes', map, where: 'id = ?', whereArgs: [t.id]);
    });
  }

  Future<void> atualizarEmprestimo(TransacaoPai pai, Transacao parcela) async {
    await dbHelper.write((txn) async {
      await _assertEditable(txn, pai.id);
      await txn.update('transacao_pai', pai.toMap(),
          where: 'id = ?', whereArgs: [pai.id]);
      final rows = await txn.query('transacoes',
          where: 'id_transacao_pai = ?', whereArgs: [pai.id]);
      final firstDue = nextMonth(
          parcela.dataVencimento ?? parcela.dataEmprestimo,
          1 - parcela.parcela);
      final numbers = <int>{};
      for (final row in rows) {
        final number = row['parcela'] as int;
        final paid = row['data_pagamento_completo'] != null ||
            row['data_pagamento_retorno'] != null;
        if (number > pai.qtdeParcelas && !paid) {
          await txn
              .delete('transacoes', where: 'id = ?', whereArgs: [row['id']]);
          continue;
        }
        numbers.add(number);
        await txn.update(
            'transacoes',
            {
              'id_obrigado': pai.idObrigado,
              'data_emprestimo': pai.dataEmprestimo.toIso8601String(),
              'valor_empresado': pai.valorEmprestado,
              'percentual_juros': pai.percentualJuros,
              if (!paid)
                'retorno': pai.valorEmprestado * pai.percentualJuros / 100,
              if (!paid)
                'data_vencimento':
                    nextMonth(firstDue, number - 1).toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [row['id']]);
      }
      for (var number = 1; number <= pai.qtdeParcelas; number++) {
        if (numbers.contains(number)) continue;
        await txn.insert(
            'transacoes',
            Transacao(
                    idTransacaoPai: pai.id,
                    parcela: number,
                    idObrigado: pai.idObrigado,
                    dataEmprestimo: pai.dataEmprestimo,
                    valorEmprestado: pai.valorEmprestado,
                    percentualJuros: pai.percentualJuros,
                    retorno: pai.valorEmprestado * pai.percentualJuros / 100,
                    dataVencimento: nextMonth(firstDue, number - 1))
                .toMap());
      }
    });
  }

  Future<void> _assertEditable(Transaction txn, int? parent) async {
    final protected = await txn.query('transacoes',
        where:
            'id_transacao_pai = ? AND (valor_pago_parcial > 0 OR renegociado_em IS NOT NULL OR parcelamento = 1)',
        whereArgs: [parent],
        limit: 1);
    if (protected.isNotEmpty)
      throw StateError(
          'Este empréstimo possui pagamentos parciais ou um acordo. Seus valores e histórico devem ser preservados.');
  }

  Future<int> deleteTransacao(int id) => dbHelper.write((txn) async {
        final rows =
            await txn.query('transacoes', where: 'id = ?', whereArgs: [id]);
        if (rows.isEmpty) return 0;
        await _assertEditable(txn, rows.single['id_transacao_pai'] as int?);
        return txn.delete('transacoes', where: 'id = ?', whereArgs: [id]);
      });
  Future<Transacao?> getTransacaoById(int id) async {
    final rows = await (await dbHelper.database)
        .query('transacoes', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Transacao.fromMap(rows.single);
  }

  Future<List<Transacao>> _query({String? where, List<Object?>? args}) async =>
      (await (await dbHelper.database).query('transacoes',
              where: where,
              whereArgs: args,
              orderBy: 'data_vencimento ASC, parcela ASC, id ASC'))
          .map(Transacao.fromMap)
          .toList();
  Future<List<Transacao>> getAllTransacoes() => _query();
  Future<List<Transacao>> getTransacoesByObrigado(int id) =>
      _query(where: 'id_obrigado = ?', args: [id]);
  Future<List<Transacao>> getTransacoesByPai(int id) =>
      _query(where: 'id_transacao_pai = ?', args: [id]);
  Future<List<Transacao>> getTransacoesByPeriodo(
          DateTime inicio, DateTime fim) =>
      _query(where: 'data_vencimento >= ? AND data_vencimento < ?', args: [
        DateTime(inicio.year, inicio.month, inicio.day).toIso8601String(),
        DateTime(fim.year, fim.month, fim.day + 1).toIso8601String()
      ]);
  Future<int> updateDataPagamentoRetorno(int id, DateTime data) async =>
      dbHelper.write((db) => db.update(
          'transacoes', {'data_pagamento_retorno': data.toIso8601String()},
          where: 'id = ?', whereArgs: [id]));
  Future<int> updateDataPagamentoCompleto(int id, DateTime data) async =>
      dbHelper.write((db) => db.update(
          'transacoes', {'data_pagamento_completo': data.toIso8601String()},
          where: 'id = ?', whereArgs: [id]));
  Future<void> pagarJuros(int id, DateTime data) async {
    await dbHelper.write((txn) async {
      final row =
          (await txn.query('transacoes', where: 'id = ?', whereArgs: [id]))
              .single;
      if (row['data_pagamento_retorno'] != null ||
          row['data_pagamento_completo'] != null) return;
      final t = Transacao.fromMap(row);
      await PartialPaymentService.settleInterest(txn, t, data);
    });
  }

  Future<int> updateParcelasFuturasComoPagas(
          int pai, DateTime vencimento, DateTime data) async =>
      dbHelper.write((db) => db.update(
          'transacoes', {'data_pagamento_completo': data.toIso8601String()},
          where:
              'id_transacao_pai = ? AND data_vencimento > ? AND data_pagamento_completo IS NULL AND renegociado_em IS NULL',
          whereArgs: [pai, vencimento.toIso8601String()]));
  Future<void> quitar(int id, DateTime data, {bool futuras = false}) async {
    await dbHelper.write((txn) async {
      final row =
          (await txn.query('transacoes', where: 'id = ?', whereArgs: [id]))
              .single;
      final selected = Transacao.fromMap(row);
      if (!selected.emAberto)
        throw StateError('Esta parcela não está em aberto.');
      await txn.update(
          'transacoes', {'data_pagamento_completo': data.toIso8601String()},
          where: 'id = ?', whereArgs: [id]);
      if (futuras && !selected.parcelamento)
        await txn.update(
            'transacoes', {'data_pagamento_completo': data.toIso8601String()},
            where:
                'id_transacao_pai = ? AND data_vencimento > ? AND data_pagamento_completo IS NULL AND renegociado_em IS NULL',
            whereArgs: [row['id_transacao_pai'], data.toIso8601String()]);
    });
  }
}
