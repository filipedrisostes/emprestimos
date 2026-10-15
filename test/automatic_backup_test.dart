import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/models/transacao_pai.dart';
import 'package:emprestimos/services/automatic_backup_service.dart';
import 'package:emprestimos/services/backup_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late DatabaseHelper helper;
  late AutomaticBackupService service;
  late bool online;
  late List<List<String>> uploaded;
  late List<String> messages;
  Future<void> upload(File file) async {
    if (!online) throw const SocketException('offline');
    final db =
        await openDatabase(file.path, readOnly: true, singleInstance: false);
    try {
      expect((await db.rawQuery('PRAGMA integrity_check')).single.values.first,
          'ok');
      uploaded.add((await db.query('obrigados'))
          .map((r) => r['nome'] as String)
          .toList());
    } finally {
      await db.close();
    }
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('automatic_backup_test');
    helper = DatabaseHelper.forPath('${dir.path}/live.db');
    online = false;
    uploaded = [];
    messages = [];
    service = AutomaticBackupService(
        helper, Directory('${dir.path}/queue'), upload, messages.add);
    await service.initialize();
  });
  tearDown(() async {
    await service.dispose();
    await helper.close();
    await dir.delete(recursive: true);
  });

  test(
      'cada alteração tem snapshot distinto; fila sobrevive reinício e envia em ordem',
      () async {
    final dao = ObrigadoDao(helper);
    final id = await dao.insertObrigado(Obrigado(nome: 'Antes', zap: '123'));
    await dao.updateObrigado(Obrigado(id: id, nome: 'Depois', zap: '123'));
    await dao.deleteObrigado(id);
    await service.sendPending();
    expect((await service.pending()).length, 3);
    expect(uploaded, isEmpty);
    await service.dispose();
    service = AutomaticBackupService(
        helper, Directory('${dir.path}/queue'), upload, messages.add);
    await service.initialize();
    online = true;
    await service.sendPending();
    expect(uploaded, [
      ['Antes'],
      ['Depois'],
      <String>[]
    ]);
    expect(await service.pending(), isEmpty);
    expect(messages.last, 'Backup automático em dia.');
  });

  test('rollback, leitura e exclusão inexistente não geram backup', () async {
    final dao = ObrigadoDao(helper);
    await dao.getAllObrigados();
    await dao.deleteObrigado(999);
    await expectLater(helper.write((db) async {
      await db.insert('obrigados', {'nome': 'Não salvar', 'zap': '123'});
      throw StateError('rollback');
    }), throwsStateError);
    expect(await dao.getAllObrigados(), isEmpty);
    expect(await service.pending(), isEmpty);
  });

  test('falha ao criar cópia mantém dados e recupera snapshot antes da próxima alteração', () async {
    service.prepare = (_) async => throw const FileSystemException('sem espaço');
    final dao = ObrigadoDao(helper);
    await dao.insertObrigado(Obrigado(nome: 'Preservado', zap: '123'));
    expect((await dao.getAllObrigados()).single.nome, 'Preservado');
    expect(await service.pending(), isEmpty);
    await expectLater(dao.insertObrigado(Obrigado(nome: 'Bloqueado', zap: '123')), throwsStateError);
    service.prepare = null;
    await dao.insertObrigado(Obrigado(nome: 'Próximo', zap: '123'));
    await service.sendPending();
    online = true;
    await service.sendPending();
    expect(uploaded, [['Preservado'], ['Preservado', 'Próximo']]);
  });

  test('parcelas e pagamentos geram uma cópia por operação confirmada',
      () async {
    final id = await ObrigadoDao(helper)
        .insertObrigado(Obrigado(nome: 'Cliente', zap: '123'));
    final dao = TransacaoDao(helper);
    final pai = await dao.criarEmprestimo(
        TransacaoPai(
            idObrigado: id,
            dataEmprestimo: DateTime(2026, 1, 1),
            valorEmprestado: 1000,
            percentualJuros: 30,
            qtdeParcelas: 3),
        DateTime(2026, 2, 1));
    final rows = await dao.getTransacoesByPai(pai);
    await dao.pagarJuros(rows.first.id!, DateTime(2026, 2, 1));
    await dao.pagarJuros(rows.first.id!, DateTime(2026, 2, 1));
    await dao.quitar(rows.last.id!, DateTime(2026, 3, 1), futuras: true);
    await service.sendPending();
    final files = await service.pending();
    expect(files.length, 4); // client, loan, interest, settlement
    final copy = await openDatabase(files[1].path,
        readOnly: true, singleInstance: false);
    expect((await copy.query('transacoes')).length, 3);
    expect(await copy.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    await copy.close();
  });

  test('alterações concorrentes não misturam os estados dos snapshots',
      () async {
    final dao = ObrigadoDao(helper);
    await Future.wait(List.generate(
        5, (i) => dao.insertObrigado(Obrigado(nome: 'Cliente$i', zap: '123'))));
    await service.sendPending();
    online = true;
    await Future.wait([service.sendPending(), service.sendPending()]);
    expect(uploaded.map((r) => r.length), [1, 2, 3, 4, 5]);
  });

  test('restauração também gera cópia e snapshots não fecham conexão ativa',
      () async {
    final dao = ObrigadoDao(helper);
    await dao.insertObrigado(Obrigado(nome: 'Original', zap: '123'));
    final connection = await helper.database;
    final backup =
        await BackupService(helper).exportar('${dir.path}/manual.db');
    expect(connection.isOpen, true);
    await dao.insertObrigado(Obrigado(nome: 'Temporário', zap: '123'));
    await BackupService(helper).restaurar(backup);
    await service.sendPending();
    online = true;
    await service.sendPending();
    expect(uploaded, [
      ['Original'],
      ['Original', 'Temporário'],
      ['Original']
    ]);
  });
}
