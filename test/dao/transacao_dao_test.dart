import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/transacao_pai.dart';
import 'package:emprestimos/services/backup_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late DatabaseHelper helper;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('emprestimos_test_');
    helper = DatabaseHelper.forPath('${dir.path}/test.db');
  });
  tearDown(() async {
    await helper.close();
    await dir.delete(recursive: true);
  });
  Future<void> cliente() async => (await helper.database).execute(
      "INSERT INTO obrigados(id,nome,zap) VALUES(1,'Teste','11999990000')");

  test('banco real do APK v5 preserva parcelas e valores após migração',
      () async {
    await File('test/fixtures/apk-v5-synthetic.db')
        .copy(await helper.databasePath);
    final db = await helper.database;
    final rows = await TransacaoDao(helper).getAllTransacoes();
    expect(await db.getVersion(), DatabaseHelper.schemaVersion);
    expect(rows.length, 3);
    expect(rows.map((t) => t.parcela), [1, 2, 3]);
    expect(rows.map((t) => t.retorno), [300, 300, 300]);
    expect(rows.every((t) => t.idObrigado == 1 && t.valorEmprestado == 1000),
        true);
    expect(rows.map((t) => t.dataVencimento), [
      DateTime(2026, 11, 12),
      DateTime(2026, 12, 12),
      DateTime(2027, 1, 12)
    ]);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
  test('migra banco antigo preservando IDs, pagamentos e mensagem', () async {
    final old = await openDatabase(await helper.databasePath, version: 1,
        onCreate: (db, _) async {
      await db.execute(
          'CREATE TABLE obrigados(id INTEGER PRIMARY KEY,nome TEXT,zap TEXT,mensagem_personalizada TEXT)');
      await db.execute(
          'CREATE TABLE transacoes(id INTEGER PRIMARY KEY,id_obrigado INTEGER,data_emprestimo TEXT,valor_empresado REAL,percentual_juros REAL,retorno REAL,data_pagamento_retorno TEXT,data_pagamento_completo TEXT,data_vencimento TEXT)');
      await db.execute(
          "INSERT INTO obrigados VALUES(1,'Teste','11999990000','Olá #')");
      await db.execute(
          "INSERT INTO transacoes VALUES(42,1,'2025-01-15',1000,30,300,'2025-02-15',NULL,'2025-02-15')");
    });
    await old.close();
    final t = await TransacaoDao(helper).getTransacaoById(42);
    expect(t!.retorno, 300);
    expect(t.valorEmprestado, 1000);
    expect(t.dataPagamentoRetorno, DateTime(2025, 2, 15));
    expect(t.idTransacaoPai, isNotNull);
    expect(
        (await (await helper.database).query('obrigados'))
            .single['mensagem_personalizada'],
        'Olá #');
  });
  test('cria parcelas mensais e reproduz pagamento de juros do APK', () async {
    await cliente();
    final dao = TransacaoDao(helper);
    await dao.criarEmprestimo(
        TransacaoPai(
            idObrigado: 1,
            dataEmprestimo: DateTime(2026, 10, 13),
            valorEmprestado: 1000,
            percentualJuros: 30,
            qtdeParcelas: 3),
        DateTime(2026, 11, 12));
    var rows = await dao.getAllTransacoes();
    expect(rows.length, 3);
    expect(rows.every((t) => t.retorno == 300), true);
    await dao.pagarJuros(rows.first.id!, DateTime(2026, 10, 13));
    await dao.pagarJuros(rows.first.id!,
        DateTime(2026, 10, 13)); // repeat action must not duplicate a payment
    rows = await dao.getAllTransacoes();
    expect(rows.length, 4);
    expect(rows.where((t) => t.dataVencimento == DateTime(2026, 12, 12)).length,
        2);
    await dao.quitar(rows[1].id!, DateTime(2026, 10, 14), futuras: true);
    expect(
        (await dao.getAllTransacoes())
            .every((t) => t.dataPagamentoCompleto != null),
        true);
  });
  test('consulta mensal usa vencimento e inclui o último dia inteiro',
      () async {
    await cliente();
    final dao = TransacaoDao(helper);
    await dao.criarEmprestimo(
        TransacaoPai(
            idObrigado: 1,
            dataEmprestimo: DateTime(2026, 9, 1),
            valorEmprestado: 100,
            percentualJuros: 10,
            qtdeParcelas: 1),
        DateTime(2026, 10, 31));
    expect(
        await dao.getTransacoesByPeriodo(
            DateTime(2026, 9, 1), DateTime(2026, 9, 30)),
        isEmpty);
    expect(
        (await dao.getTransacoesByPeriodo(
                DateTime(2026, 10, 1), DateTime(2026, 10, 31)))
            .length,
        1);
  });
  test('backup válido restaura; arquivo inválido preserva banco ativo',
      () async {
    await cliente();
    final service = BackupService(helper);
    final backup = await service.exportar('${dir.path}/backup.db');
    await (await helper.database).update('obrigados', {'nome': 'Alterado'});
    await service.restaurar(backup);
    expect((await (await helper.database).query('obrigados')).single['nome'],
        'Teste');
    final bad =
        await File('${dir.path}/invalid.db').writeAsString('not a database');
    await expectLater(service.restaurar(bad), throwsA(anything));
    expect((await (await helper.database).query('obrigados')).single['nome'],
        'Teste');
  });
  test('editar empréstimo atualiza quantidade e retorno como no APK', () async {
    await cliente();
    final dao = TransacaoDao(helper);
    final id = await dao.criarEmprestimo(TransacaoPai(idObrigado: 1, dataEmprestimo: DateTime(2026,10,13), valorEmprestado: 1000, percentualJuros: 30, qtdeParcelas: 3), DateTime(2026,11,12));
    final primeira = (await dao.getAllTransacoes()).first;
    await dao.atualizarEmprestimo(TransacaoPai(id:id,idObrigado:1,dataEmprestimo:DateTime(2026,10,13),valorEmprestado:2000,percentualJuros:30,qtdeParcelas:5),primeira);
    final rows = await dao.getAllTransacoes();
    expect(rows.length,5); expect(rows.first.id,primeira.id);
    expect(rows.every((t)=>t.retorno==600),true);
    expect(rows.last.dataVencimento,DateTime(2027,3,12));
  });

}
