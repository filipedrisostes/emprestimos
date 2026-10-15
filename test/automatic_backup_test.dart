import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/services/automatic_backup_service.dart';
import 'package:emprestimos/services/backup_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late DatabaseHelper helper;
  late AutomaticBackupService service;
  late DateTime now;
  late bool online;
  late Map<String, List<String>> remote;
  late List<String> messages;
  Completer<void>? gate;
  Completer<void>? started;
  Future<void> upload(File file) async {
    if (!online) throw const SocketException('offline');
    if (gate != null) {
      started?.complete();
      final wait = gate!;
      gate = null;
      await wait.future;
    }
    final metadata = jsonDecode(await File('${file.path}.json').readAsString());
    final db =
        await openDatabase(file.path, readOnly: true, singleInstance: false);
    try {
      expect((await db.rawQuery('PRAGMA integrity_check')).single.values.first,
          'ok');
      remote[metadata['remoteName'] as String] =
          (await db.query('obrigados', orderBy: 'id'))
              .map((r) => r['nome'] as String)
              .toList();
    } finally {
      await db.close();
    }
  }

  AutomaticBackupService create() => AutomaticBackupService(
      helper, Directory('${dir.path}/queue'), upload, messages.add,
      now: () => now);
  setUp(() async {
    now = DateTime(2026, 10, 14, 22, 54);
    dir = await Directory.systemTemp.createTemp('daily_backup_test');
    helper = DatabaseHelper.forPath('${dir.path}/live.db');
    online = false;
    remote = {};
    messages = [];
    gate = null;
    started = null;
    service = create();
    await service.initialize();
  });
  tearDown(() async {
    await service.dispose();
    await helper.close();
    await dir.delete(recursive: true);
  });
  Future<int> insert(String name) =>
      ObrigadoDao(helper).insertObrigado(Obrigado(nome: name, zap: '123'));

  test('substitui o atual a cada alteração e consolida fila offline', () async {
    final id = await insert('Antes');
    online = true;
    await service.sendPending();
    expect(remote, {
      'bkp_atual.db': ['Antes']
    });
    online = false;
    await ObrigadoDao(helper)
        .updateObrigado(Obrigado(id: id, nome: 'Depois', zap: '123'));
    await insert('Outro');
    await service.sendPending();
    expect((await service.pending()).length, 1);
    online = true;
    await service.sendPending();
    expect(remote, {
      'bkp_atual.db': ['Depois', 'Outro']
    });
  });

  test('meia-noite congela ontem e alterações de hoje não mudam histórico',
      () async {
    await insert('Ontem');
    now = DateTime(2026, 10, 15, 0, 0);
    online = true;
    await service.retry();
    expect(remote['bkp_dia_2026-10-14.db'], ['Ontem']);
    await insert('Hoje');
    await service.sendPending();
    expect(remote['bkp_atual.db'], ['Ontem', 'Hoje']);
    expect(remote['bkp_dia_2026-10-14.db'], ['Ontem']);
    await service.retry();
    expect(remote.length, 2);
  });

  test('primeira alteração após meia-noite arquiva antes de modificar banco',
      () async {
    await insert('Ontem');
    now = DateTime(2026, 10, 15, 1, 5);
    await insert('Hoje');
    online = true;
    await service.sendPending();
    expect(remote['bkp_dia_2026-10-14.db'], ['Ontem']);
    expect(remote['bkp_atual.db'], ['Ontem', 'Hoje']);
  });

  test('reinício recupera dias sem uso inclusive virada de mês e ano',
      () async {
    now = DateTime(2026, 12, 31, 23, 59);
    // Start this scenario with its own initial calendar baseline.
    await service.dispose();
    await Directory('${dir.path}/queue').delete(recursive: true);
    service = create();
    await service.initialize();
    await insert('Fechamento');
    await service.dispose();
    now = DateTime(2027, 1, 3, 8);
    service = create();
    await service.initialize();
    online = true;
    await service.sendPending();
    expect(remote.keys.toSet(), {
      'bkp_atual.db',
      'bkp_dia_2026-12-31.db',
      'bkp_dia_2027-01-01.db',
      'bkp_dia_2027-01-02.db'
    });
    expect(remote.values.every((rows) => rows.single == 'Fechamento'), true);
    await service.retry();
    expect(await service.pending(), isEmpty);
  });

  test('confirmação de upload antigo não descarta versão nova concorrente',
      () async {
    await insert('Versão1');
    await service.sendPending();
    online = true;
    final finish = Completer<void>();
    gate = finish;
    started = Completer<void>();
    final sending = service.sendPending();
    await started!.future;
    await insert('Versão2');
    now = DateTime(2026, 10, 15, 0, 1);
    await insert('Hoje');
    finish.complete();
    await sending;
    expect(remote['bkp_dia_2026-10-14.db'], ['Versão1', 'Versão2']);
    expect(remote['bkp_atual.db'], ['Versão1', 'Versão2', 'Hoje']);
    expect(await service.pending(), isEmpty);
  });

  test('rollback, leitura e exclusão inexistente não alteram backup', () async {
    online = true;
    await service.sendPending();
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

  test('falha de snapshot recupera estado anterior antes de nova alteração',
      () async {
    service.prepare =
        (_) async => throw const FileSystemException('sem espaço');
    await insert('Preservado');
    await expectLater(insert('Bloqueado'), throwsStateError);
    now = DateTime(2026, 10, 15, 0, 1);
    service.prepare = null;
    await insert('Hoje');
    online = true;
    await service.sendPending();
    expect(remote['bkp_dia_2026-10-14.db'], ['Preservado']);
    expect(remote['bkp_atual.db'], ['Preservado', 'Hoje']);
  });

  test('restaurar hoje não modifica fechamento de ontem', () async {
    await insert('Original');
    final backup =
        await BackupService(helper).exportar('${dir.path}/manual.db');
    await insert('Final de ontem');
    now = DateTime(2026, 10, 15, 1);
    await BackupService(helper).restaurar(backup);
    online = true;
    await service.sendPending();
    expect(remote['bkp_dia_2026-10-14.db'], ['Original', 'Final de ontem']);
    expect(remote['bkp_atual.db'], ['Original']);
  });

  test('fila da versão antiga preserva último estado de cada dia', () async {
    await service.dispose();
    await Directory('${dir.path}/queue').delete(recursive: true);
    await insert('Primeiro');
    final first =
        await BackupService(helper).exportar('${dir.path}/queue/bkp_auto_1.db');
    await first.setLastModified(DateTime(2026, 10, 13, 18));
    await insert('Último');
    final last =
        await BackupService(helper).exportar('${dir.path}/queue/bkp_auto_2.db');
    await last.setLastModified(DateTime(2026, 10, 13, 23));
    service = create();
    await service.initialize();
    online = true;
    await service.sendPending();
    expect(remote['bkp_dia_2026-10-13.db'], ['Primeiro', 'Último']);
    expect(remote['bkp_atual.db'], ['Primeiro', 'Último']);
    expect(remote.length, 2);
  });
}
