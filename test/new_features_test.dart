import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/models/transacao_pai.dart';
import 'package:emprestimos/services/backup_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late DatabaseHelper helper;
  late TransacaoDao dao;
  final date = DateTime(2026, 10, 15);
  TransacaoPai loan({double value = 1000}) => TransacaoPai(
      idObrigado: 0,
      dataEmprestimo: date,
      valorEmprestado: value,
      percentualJuros: 10,
      qtdeParcelas: 2);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('features_');
    helper = DatabaseHelper.forPath('${dir.path}/live.db');
    dao = TransacaoDao(helper);
  });
  tearDown(() async {
    await helper.close();
    await dir.delete(recursive: true);
  });

  test('new client and loan commit together, reuse normalized existing name',
      () async {
    var snapshots = 0;
    helper.afterChange = (_) async => snapshots++;
    final first =
        await dao.criarComCliente(loan(), date, nome: '  João   Silva ');
    expect(first.novo, true);
    expect(first.cliente.nome, 'João Silva');
    expect(first.cliente.zap, '');
    expect(snapshots, 1);
    final second = await dao.criarComCliente(loan(), date, nome: 'joão silva');
    expect(second.novo, false);
    expect(second.cliente.id, first.cliente.id);
    final db = await helper.database;
    expect(await db.query('obrigados'), hasLength(1));
    expect(await db.query('transacoes'), hasLength(4));
    expect(await db.query('historico_alteracoes'), hasLength(7));
  });

  test('database failure rolls back new client, loan and history', () async {
    final db = await helper.database;
    await db.execute(
        "CREATE TRIGGER reject_loan BEFORE INSERT ON transacao_pai BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(dao.criarComCliente(loan(), date, nome: 'Ana'),
        throwsA(isA<DatabaseException>()));
    expect(await db.query('obrigados'), isEmpty);
    expect(await db.query('historico_alteracoes'), isEmpty);
  });

  test('ambiguous names require explicit selection', () async {
    final db = await helper.database;
    await db.insert('obrigados', {'nome': 'Ana', 'zap': '1'});
    await db.insert('obrigados', {'nome': 'ANA', 'zap': '2'});
    await expectLater(
        dao.criarComCliente(loan(), date, nome: 'ana'), throwsStateError);
    final result =
        await dao.criarComCliente(loan(), date, nome: 'Ana', clienteId: 2);
    expect(result.cliente.id, 2);
    expect(result.novo, false);
  });

  test('history records payment before/after, deletion and survives backup',
      () async {
    final created = await dao.criarComCliente(loan(), date, nome: 'Cliente');
    final first = (await dao.getTransacoesByPai(created.emprestimoId)).first;
    await dao.pagarJuros(first.id!, date);
    final db = await helper.database;
    final changes = await db.query('historico_alteracoes',
        where: "entidade = 'transacoes' AND acao = 'Alterado'");
    expect(
        jsonDecode(changes.single['antes'] as String)['data_pagamento_retorno'],
        isNull);
    expect(
        jsonDecode(
            changes.single['depois'] as String)['data_pagamento_retorno'],
        date.toIso8601String());
    final file = await BackupService(helper).exportar('${dir.path}/backup.db');
    await dao.deleteTransacao(first.id!);
    expect(
        (await db.query('historico_alteracoes', where: "acao = 'Excluído'"))
            .length,
        1);
    await BackupService(helper).restaurar(file);
    final restored = await helper.database;
    expect(
        await restored.query('historico_alteracoes',
            where: "acao = 'Restaurado'"),
        hasLength(1));
    expect(
        await restored.query('historico_alteracoes',
            where: "acao = 'Alterado'"),
        hasLength(1));
    expect(await dao.getTransacaoById(first.id!), isNotNull);
  });
}
