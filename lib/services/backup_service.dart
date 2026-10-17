import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'database_snapshot.dart';

class BackupService {
  final DatabaseHelper helper;
  BackupService(this.helper);
  static bool _busy = false;
  Future<File> exportar(String destination) => helper.exclusive(() async {
        final source = await helper.databasePath;
        if (p.equals(p.absolute(source), p.absolute(destination))) {
          throw ArgumentError('Destino igual ao banco ativo');
        }
        return databaseSnapshot(await helper.database, destination);
      });

  Future<void> restaurar(File source) => helper.exclusive(() async {
        await helper.beforeChange?.call();
        try {
          await _restaurar(source);
        } catch (_) {
          await helper.unchanged?.call();
          rethrow;
        }
        await helper.afterChange?.call(await helper.database);
      });

  Future<void> _restaurar(File source) async {
    if (_busy) throw StateError('Já existe um backup em andamento');
    _busy = true;
    String? candidate;
    String? safety;
    bool replaced = false;
    final target = await helper.databasePath;
    try {
      if (p.equals(p.absolute(source.path), p.absolute(target)))
        throw ArgumentError('Selecione um arquivo de backup');
      final stamp = DateTime.now().microsecondsSinceEpoch;
      candidate = '$target.import-$stamp';
      await File(target).parent.create(recursive: true);
      await source.copy(candidate);
      final check =
          await openDatabase(candidate, readOnly: true, singleInstance: false);
      try {
        final integrity = await check.rawQuery('PRAGMA integrity_check');
        if (integrity.length != 1 || integrity.single.values.first != 'ok')
          throw const FormatException('Arquivo de backup inválido');
        final names = (await check
                .rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
            .map((r) => r['name'])
            .toSet();
        if (!names.containsAll({'obrigados', 'transacoes'}))
          throw const FormatException(
              'O arquivo não é um backup de Empréstimos');
        if (await check.getVersion() > DatabaseHelper.schemaVersion)
          throw const FormatException('Backup de uma versão mais recente');
      } finally {
        await check.close();
      }
      // Old backups have no configuration row: retain the current settings.
      // New backups retain their own row without consulting device preferences.
      final currentConfiguration = (await (await helper.database)
              .query('configuracoes', where: 'id = 1'))
          .single;
      final probe = DatabaseHelper.forPath(candidate,
          legacyConfigurationLoader: () async => currentConfiguration);
      try {
        final db = await probe.database;
        // Even files already at this version must have a valid schema.
        await db.transaction((txn) => DatabaseHelper.migrate(txn));
        if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty)
          throw const FormatException('Backup contém referências inválidas');
        await db.query('obrigados', columns: ['id', 'nome', 'zap']);
        await db.query('transacoes',
            columns: ['id', 'id_transacao_pai', 'parcela', 'retorno']);
        await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      } finally {
        await probe.close();
      }
      final active = await helper.database;
      await active.rawQuery('PRAGMA wal_checkpoint(FULL)');
      await helper.close();
      safety = '$target.before-restore-$stamp';
      await File(target).rename(safety);
      await File(candidate).rename(target);
      replaced = true;
      final restored = await helper.database;
      await restored.insert('historico_alteracoes', {
        'data': DateTime.now().toUtc().toIso8601String(),
        'entidade': 'backup',
        'acao': 'Restaurado',
        'depois': '{"operacao":"Restauração de backup"}'
      });
    } catch (_) {
      await helper.close();
      if (safety != null && await File(safety).exists()) {
        if (replaced && await File(target).exists())
          await File(target).delete();
        await File(safety).rename(target);
      }
      rethrow;
    } finally {
      if (candidate != null && await File(candidate).exists())
        await File(candidate).delete();
      _busy = false;
    }
  }
}
