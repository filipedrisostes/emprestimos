import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emprestimos/configuracao_service.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/services/backup_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Directory dir;
  late DatabaseHelper helper;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('config_sqlite_');
    helper = DatabaseHelper.forPath('${dir.path}/live.db');
  });
  tearDown(() async {
    await helper.close();
    await dir.delete(recursive: true);
  });

  test('upgrade v6 preserves legacy values once and loan data', () async {
    final old = await openDatabase(await helper.databasePath);
    await DatabaseHelper.migrate(old);
    await old.execute('DROP TABLE configuracoes');
    await old.insert('obrigados', {'id': 1, 'nome': 'Cliente', 'zap': '123'});
    await old.setVersion(6);
    await old.close();
    var calls = 0;
    helper = DatabaseHelper.forPath('${dir.path}/live.db',
        legacyConfigurationLoader: () async {
      calls++;
      return {
        'email_padrao': 'antigo@example.com',
        'juros_padrao': 12.5,
        'zap_padrao': '11999999999',
        'dias_vencimento_padrao': '45'
      };
    });
    final repo = ConfiguracaoRepository(helper);
    final config = await repo.carregar();
    expect(config['email_padrao'], 'antigo@example.com');
    expect(config['juros_padrao'], 12.5);
    expect(config['zap_padrao'], '11999999999');
    expect(config['dias_vencimento_padrao'], 45);
    expect((await (await helper.database).query('obrigados')).single['nome'],
        'Cliente');
    await repo.salvar({'email_padrao': 'novo@example.com'});
    await helper.close();
    expect((await repo.carregar())['email_padrao'], 'novo@example.com');
    expect(calls, 1);
  });

  test('defaults, atomic save and backup hook without no-op upload', () async {
    final repo = ConfiguracaoRepository(helper);
    expect(await repo.carregar(), DatabaseHelper.configurationDefaults);
    final snapshots = <Map<String, Object?>>[];
    helper.afterChange = (db) async {
      snapshots.add((await db.query('configuracoes')).single);
    };
    final values = {
      'email_padrao': 'teste@example.com',
      'juros_padrao': 8.0,
      'zap_padrao': '123',
      'dias_vencimento_padrao': 10
    };
    await repo.salvar(values);
    await repo.salvar(values);
    expect(snapshots, [
      {'id': 1, ...values}
    ]);
  });

  test('backup restores its settings and next changes use restored database',
      () async {
    final repo = ConfiguracaoRepository(helper);
    final backup = BackupService(helper);
    final values = {
      'email_padrao': 'backup@example.com',
      'juros_padrao': 5.5,
      'zap_padrao': '456',
      'dias_vencimento_padrao': 60
    };
    await repo.salvar(values);
    final file = await backup.exportar('${dir.path}/export.db');
    await repo
        .salvar({'email_padrao': 'outro@example.com', 'juros_padrao': 99.0});
    await backup.restaurar(file);
    expect(await repo.carregar(), {'id': 1, ...values});
    await repo.salvar({'juros_padrao': 7.0});
    expect((await repo.carregar())['juros_padrao'], 7.0);
  });

  test('restoring v6 backup preserves current settings', () async {
    final repo = ConfiguracaoRepository(helper);
    await repo
        .salvar({'email_padrao': 'atual@example.com', 'juros_padrao': 11.0});
    final expected = await repo.carregar();
    final file = await BackupService(helper).exportar('${dir.path}/old.db');
    final old = await openDatabase(file.path);
    await old.execute('DROP TABLE configuracoes');
    await old.setVersion(6);
    await old.close();
    await BackupService(helper).restaurar(file);
    expect(await repo.carregar(), expected);
    expect(await (await helper.database).getVersion(),
        DatabaseHelper.schemaVersion);
  });
}
