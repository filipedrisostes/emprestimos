import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/models/transacao_pai.dart';
import 'package:emprestimos/services/partial_payment_service.dart';
import 'package:emprestimos/services/backup_service.dart';
import 'package:emprestimos/services/loan_origin.dart';
import 'package:emprestimos/services/notificacao_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late DatabaseHelper helper;
  late TransacaoDao dao;
  late PartialPaymentService service;
  late int parent, first;
  final date = DateTime(2026, 1, 31);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('partial_pay_');
    helper = DatabaseHelper.forPath('${dir.path}/live.db');
    dao = TransacaoDao(helper);
    service = PartialPaymentService(helper);
    final result = await dao.criarComCliente(
        TransacaoPai(
            idObrigado: 0,
            dataEmprestimo: date,
            valorEmprestado: 1000,
            percentualJuros: 10,
            qtdeParcelas: 3),
        date,
        nome: 'Cliente');
    parent = result.emprestimoId;
    first = (await dao.getTransacoesByPai(parent)).first.id!;
  });
  tearDown(() async {
    await helper.close();
    await dir.delete(recursive: true);
  });

  test(
      'deducts only interest, accumulates and completes without reducing next charge',
      () async {
    await service.pay(first, 30, date);
    final partial = (await dao.getTransacaoById(first))!;
    expect(partial.saldo, 70);
    expect(partial.parcial, true);
    expect(partial.valorEmprestado, 1000);
    expect(partial.retorno, 100);
    await service.pay(first, 70, date, expectedPaid: 30);
    final paid = (await dao.getTransacaoById(first))!;
    expect(paid.dataPagamentoRetorno, date);
    expect(paid.parcial, false);
    final all = await dao.getTransacoesByPai(parent);
    expect(all, hasLength(4));
    expect(all.where((t) => t.emAberto).every((t) => t.saldo == 100), true);
  });

  test(
      'refinances all open charges with exact cents and immutable prior installments',
      () async {
    await service.pay(first, 20, date);
    final id =
        await service.pay(first, 150, date, total: 1000, installments: 3);
    final previous = await dao.getTransacoesByPai(parent);
    expect(
        previous.every((t) => t.parcial && !t.emAberto && t.saldo == 0), true);
    expect(previous.every((t) => t.dataPagamentoCompleto == null), true);
    final next = await dao.getTransacoesByPai(id!);
    expect(next.map((t) => t.retorno), [333.34, 333.33, 333.33]);
    expect(next.map((t) => t.dataVencimento),
        [DateTime(2026, 2, 28), DateTime(2026, 3, 31), DateTime(2026, 4, 30)]);
    expect(next.every((t) => t.parcelamento && t.percentualJuros == 0), true);
    final db = await helper.database;
    final loan =
        (await db.query('transacao_pai', where: 'id = ?', whereArgs: [id]))
            .single;
    final origin = jsonDecode(loan['origem_historico'] as String);
    expect(origin['valor_pago'], 150);
    expect(origin['emprestimo']['valor_emprestado'], 1000);
    expect(origin['emprestimo']['data_emprestimo'], date.toIso8601String());
    expect(origin['parcelas'], hasLength(3));
    expect(origin['parcelas'][0]['valor_pago_parcial'], 20);
    expect(origin['pagamentos'], hasLength(2));
    expect(loanOriginLines(loan['origem_historico'] as String).join('\n'),
        contains('Parcelas anteriores'));
    expect(
        NotificacaoService.proximas(await dao.getAllTransacoes(), date)
            .map((t) => t.id),
        next.map((t) => t.id));
    await expectLater(dao.quitar(first, date), throwsStateError);
    await expectLater(dao.deleteTransacao(first), throwsStateError);
  });

  test(
      'paying agreement installment does not settle others or create new interest',
      () async {
    final id =
        (await service.pay(first, 10, date, total: 100, installments: 2))!;
    final installments = await dao.getTransacoesByPai(id);
    await service.pay(installments.first.id!, 20, date);
    expect((await dao.getTransacaoById(installments.first.id!))!.saldo, 30);
    await dao.quitar(installments.first.id!, date, futuras: true);
    final after = await dao.getTransacoesByPai(id);
    expect(after, hasLength(2));
    expect(after.first.emAberto, false);
    expect(after.last.saldo, 50);
    await expectLater(dao.pagarJuros(after.last.id!, date), throwsStateError);
  });

  test(
      'rejects invalid amounts and stale repeated payment without extra audit or backup',
      () async {
    var snapshots = 0;
    helper.afterChange = (_) async => snapshots++;
    for (final amount in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      1.001,
      101.0
    ]) {
      await expectLater(service.pay(first, amount, date), throwsArgumentError);
    }
    await expectLater(
        service.pay(first, 10, date, total: 0.01, installments: 2),
        throwsArgumentError);
    expect(snapshots, 0);
    await service.pay(first, 10, date, expectedPaid: 0);
    await expectLater(
        service.pay(first, 10, date, expectedPaid: 0), throwsStateError);
    expect(snapshots, 1);
    expect(await (await helper.database).query('pagamentos_parciais'),
        hasLength(1));
  });

  test(
      'database failure rolls back the payment, agreement, history and transfer',
      () async {
    final db = await helper.database;
    final audit = await db.query('historico_alteracoes');
    await db.execute(
        "CREATE TRIGGER reject_agreement BEFORE INSERT ON transacoes WHEN NEW.parcelamento = 1 BEGIN SELECT RAISE(ABORT, 'test'); END");
    await expectLater(service.pay(first, 20, date, total: 500, installments: 2),
        throwsA(isA<DatabaseException>()));
    expect(await db.query('transacao_pai'), hasLength(1));
    expect(await db.query('pagamentos_parciais'), isEmpty);
    expect(await db.query('historico_alteracoes'), audit);
    expect((await dao.getTransacaoById(first))!.emAberto, true);
  });

  test('nested origins and payments survive backup restoration', () async {
    final id =
        (await service.pay(first, 20, date, total: 500, installments: 2))!;
    final installment = (await dao.getTransacoesByPai(id)).first;
    final nextId = (await service.pay(installment.id!, 50, date,
        total: 450, installments: 3))!;
    final file = await BackupService(helper).exportar('${dir.path}/backup.db');
    await BackupService(helper).restaurar(file);
    final db = await helper.database;
    final next =
        (await db.query('transacao_pai', where: 'id = ?', whereArgs: [nextId]))
            .single;
    final lines =
        loanOriginLines(next['origem_historico'] as String).join('\n');
    expect(lines, contains('Origem: empréstimo #$parent'));
    expect(lines, contains('Histórico do acordo anterior'));
    expect(await db.query('pagamentos_parciais'), hasLength(2));
    expect(
        (await dao.getTransacoesByPai(nextId))
            .fold<double>(0, (sum, t) => sum + t.saldo),
        450);
  });

  test('migrates schema 8 without changing amounts or payment dates', () async {
    final db = await helper.database;
    await db.execute('DROP TABLE pagamentos_parciais');
    await db.execute('ALTER TABLE transacoes DROP COLUMN valor_pago_parcial');
    await db.execute('ALTER TABLE transacoes DROP COLUMN renegociado_em');
    await db.execute('ALTER TABLE transacoes DROP COLUMN parcelamento');
    await db
        .execute('ALTER TABLE transacao_pai DROP COLUMN origem_emprestimo_id');
    await db.execute('ALTER TABLE transacao_pai DROP COLUMN origem_historico');
    await db.setVersion(8);
    await helper.close();
    final migrated = await helper.database;
    expect(await migrated.getVersion(), 9);
    final t = (await dao.getTransacaoById(first))!;
    expect(t.retorno, 100);
    expect(t.valorPagoParcial, 0);
    expect(t.dataEmprestimo, date);
  });
}
