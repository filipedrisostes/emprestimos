import 'dart:async';
import 'services/audit_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static const schemaVersion = 9;
  static final instance = DatabaseHelper._();
  final String? pathOverride;
  Database? _database;
  Future<Database>? _opening;
  final Future<Map<String, Object?>> Function()? legacyConfigurationLoader;
  DatabaseHelper._()
      : pathOverride = null,
        legacyConfigurationLoader = null;
  DatabaseHelper.forPath(this.pathOverride, {this.legacyConfigurationLoader});

  static const configurationDefaults = <String, Object?>{
    'id': 1,
    'email_padrao': 'Sem email definido',
    'juros_padrao': 30.0,
    'zap_padrao': 'Sem celular definido',
    'dias_vencimento_padrao': 30,
  };

  static Future<void> initializeConfiguration(
      DatabaseExecutor db, Map<String, Object?> legacy) async {
    final days = legacy['dias_vencimento_padrao'];
    await db.insert(
        'configuracoes',
        {
          ...configurationDefaults,
          if (legacy['email_padrao'] is String)
            'email_padrao': legacy['email_padrao'],
          if (legacy['zap_padrao'] is String)
            'zap_padrao': legacy['zap_padrao'],
          if (legacy['juros_padrao'] is num)
            'juros_padrao': legacy['juros_padrao'],
          'dias_vencimento_padrao':
              days is int ? days : int.tryParse('$days') ?? 30,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _initializeConfiguration(Database db) async {
    if ((await db.query('configuracoes', where: 'id = 1')).isNotEmpty) return;
    Map<String, Object?> legacy = {};
    if (legacyConfigurationLoader != null) {
      legacy = await legacyConfigurationLoader!();
    } else if (pathOverride == null) {
      final prefs = await SharedPreferences.getInstance();
      legacy = {
        for (final key in configurationDefaults.keys.where((k) => k != 'id'))
          key: prefs.get(key)
      };
    }
    await initializeConfiguration(db, legacy);
  }

  Future<void> Function()? beforeChange;
  Future<void> Function(Database db)? afterChange;
  Future<void> Function()? unchanged;
  Future<void> _operations = Future.value();

  // Serializes writes, snapshots and restore, but never waits for the network.
  Future<T> exclusive<T>(Future<T> Function() action) {
    final result = _operations.then((_) => action());
    _operations =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<T> write<T>(Future<T> Function(Transaction txn) action) =>
      exclusive(() async {
        final db = await database;
        await beforeChange?.call();
        final before =
            (await db.rawQuery('SELECT total_changes()')).single.values.first;
        late T result;
        try {
          result = await db.transaction((txn) async {
            final before = await AuditService.snapshot(txn);
            final result = await action(txn);
            await AuditService.record(txn, before);
            return result;
          });
        } catch (_) {
          await unchanged?.call();
          rethrow;
        }
        final after =
            (await db.rawQuery('SELECT total_changes()')).single.values.first;
        if (after != before) {
          await afterChange?.call(db);
        } else {
          await unchanged?.call();
        }
        return result;
      });

  Future<String> get databasePath async {
    if (pathOverride != null) return pathOverride!;
    if (!Platform.isIOS)
      return join(await getDatabasesPath(), 'emprestimos.db');
    // Documents is visible in Files; keep the active database private.
    final dir = Directory(
        join((await getApplicationSupportDirectory()).path, 'databases'));
    await dir.create(recursive: true);
    final target = join(dir.path, 'emprestimos.db');
    final legacy = join(await getDatabasesPath(), 'emprestimos.db');
    if (!await File(target).exists() && await File(legacy).exists()) {
      final old = await openDatabase(legacy);
      try {
        await old.rawQuery('PRAGMA wal_checkpoint(FULL)');
      } finally {
        await old.close();
      }
      final temporary = await File(legacy).copy('$target.import');
      await temporary.rename(target);
    }
    return target;
  }

  Future<Database> get database async {
    if (_database?.isOpen ?? false) return _database!;
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      _database = await openDatabase(
        await databasePath,
        version: schemaVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => migrate(db),
        onUpgrade: (db, _, __) => migrate(db),
        onOpen: _initializeConfiguration,
      );
      return _database!;
    } finally {
      _opening = null;
    }
  }

  Future<void> close() async {
    if (_opening != null) await _opening;
    await _database?.close();
    _database = null;
  }

  // Additive migration: accepts the old repository schema and both APK variants.
  // Existing IDs, values and payment dates are retained.
  static Future<void> migrate(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS historico_alteracoes (
      id INTEGER PRIMARY KEY AUTOINCREMENT, data TEXT NOT NULL,
      entidade TEXT NOT NULL, registro_id INTEGER, cliente_id INTEGER,
      acao TEXT NOT NULL, antes TEXT, depois TEXT)''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_historico_cliente ON historico_alteracoes(cliente_id, id)');
    await db.execute('''CREATE TABLE IF NOT EXISTS configuracoes (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      email_padrao TEXT NOT NULL, juros_padrao REAL NOT NULL,
      zap_padrao TEXT NOT NULL, dias_vencimento_padrao INTEGER NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS obrigados (
      id INTEGER PRIMARY KEY, nome TEXT NOT NULL, zap TEXT NOT NULL,
      mensagem_personalizada TEXT)''');
    await _add(db, 'obrigados', 'mensagem_personalizada', 'TEXT');
    await db.execute('''CREATE TABLE IF NOT EXISTS transacao_pai (
      id INTEGER PRIMARY KEY AUTOINCREMENT, data_emprestimo TEXT NOT NULL,
      id_obrigado INTEGER NOT NULL, valor_emprestado REAL NOT NULL,
      percentual_juros REAL NOT NULL, qtde_parcelas INTEGER NOT NULL,
      FOREIGN KEY(id_obrigado) REFERENCES obrigados(id))''');
    await db.execute('''CREATE TABLE IF NOT EXISTS transacoes (
      id INTEGER PRIMARY KEY AUTOINCREMENT, id_transacao_pai INTEGER,
      parcela INTEGER NOT NULL DEFAULT 1, id_obrigado INTEGER NOT NULL,
      data_emprestimo TEXT NOT NULL, valor_empresado REAL NOT NULL,
      percentual_juros REAL NOT NULL, retorno REAL NOT NULL,
      data_pagamento_retorno TEXT, data_pagamento_completo TEXT,
      data_vencimento TEXT,
      FOREIGN KEY(id_transacao_pai) REFERENCES transacao_pai(id),
      FOREIGN KEY(id_obrigado) REFERENCES obrigados(id))''');
    for (final entry in {
      'id_transacao_pai': 'INTEGER',
      'parcela': 'INTEGER DEFAULT 1',
      'id_obrigado': 'INTEGER',
      'data_emprestimo': 'TEXT',
      'valor_empresado': 'REAL',
      'percentual_juros': 'REAL',
      'retorno': 'REAL',
      'data_pagamento_retorno': 'TEXT',
      'data_pagamento_completo': 'TEXT',
      'data_vencimento': 'TEXT',
    }.entries) {
      await _add(db, 'transacoes', entry.key, entry.value);
    }
    await _add(db, 'transacao_pai', 'origem_emprestimo_id', 'INTEGER');
    await _add(db, 'transacao_pai', 'origem_historico', 'TEXT');
    await _add(
        db, 'transacoes', 'valor_pago_parcial', 'REAL NOT NULL DEFAULT 0');
    await _add(db, 'transacoes', 'renegociado_em', 'TEXT');
    await _add(db, 'transacoes', 'parcelamento', 'INTEGER NOT NULL DEFAULT 0');
    await db.execute('''CREATE TABLE IF NOT EXISTS pagamentos_parciais (
      id INTEGER PRIMARY KEY AUTOINCREMENT, transacao_id INTEGER NOT NULL,
      id_obrigado INTEGER NOT NULL, data TEXT NOT NULL,
      valor REAL NOT NULL CHECK(valor > 0), tipo TEXT NOT NULL)''');
    final rows = await db.query('transacoes');
    for (final row in rows) {
      int? parentId = row['id_transacao_pai'] as int?;
      Map<String, Object?>? parent;
      if (parentId != null) {
        final parents = await db
            .query('transacao_pai', where: 'id = ?', whereArgs: [parentId]);
        if (parents.isEmpty)
          throw StateError('Empréstimo ausente para a transação ${row['id']}');
        parent = parents.single;
      } else {
        final existing = await db.query('transacao_pai',
            where:
                'id_obrigado = ? AND data_emprestimo = ? AND valor_emprestado = ? AND percentual_juros = ?',
            whereArgs: [
              row['id_obrigado'],
              row['data_emprestimo'],
              row['valor_empresado'],
              row['percentual_juros']
            ]);
        parent = existing.isEmpty
            ? {
                'id_obrigado': row['id_obrigado'],
                'data_emprestimo': row['data_emprestimo'],
                'valor_emprestado': row['valor_empresado'],
                'percentual_juros': row['percentual_juros'],
                'qtde_parcelas': 1,
              }
            : existing.first;
        parentId = existing.isEmpty
            ? await db.insert('transacao_pai', parent)
            : parent['id'] as int;
      }
      final date =
          (row['data_emprestimo'] ?? parent['data_emprestimo']) as String;
      final value =
          (row['valor_empresado'] ?? parent['valor_emprestado']) as num;
      final rate =
          (row['percentual_juros'] ?? parent['percentual_juros']) as num;
      await db.update(
          'transacoes',
          {
            'id_transacao_pai': parentId,
            'parcela': row['parcela'] ?? 1,
            'id_obrigado': row['id_obrigado'] ?? parent['id_obrigado'],
            'data_emprestimo': date,
            'valor_empresado': value,
            'percentual_juros': rate,
            'retorno': row['retorno'] ?? value * (1 + rate / 100),
            'data_vencimento': row['data_vencimento'] ??
                DateTime.parse(date)
                    .add(const Duration(days: 30))
                    .toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [row['id']]);
    }
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transacoes_pai ON transacoes(id_transacao_pai)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transacoes_vencimento ON transacoes(data_vencimento)');
  }

  static Future<void> _add(
      DatabaseExecutor db, String table, String column, String type) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (!columns.any((c) => c['name'] == column))
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }
}
