import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const schemaVersion = 6;
  static final instance = DatabaseHelper._();
  final String? pathOverride;
  Database? _database;
  Future<Database>? _opening;
  DatabaseHelper._() : pathOverride = null;
  DatabaseHelper.forPath(this.pathOverride);

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
          result = await db.transaction(action);
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

  Future<String> get databasePath async =>
      pathOverride ?? join(await getDatabasesPath(), 'emprestimos.db');
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
