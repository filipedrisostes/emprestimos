import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _dbName = 'emprestimos.db';
  static const _dbVersion = 1; // Incrementado de 1 para 2
  static Database? _database;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgradeWithCheck, // alterado para chamar método com verificação
      onOpen: (db) async {
        await _onUpgradeWithCheck(db, _dbVersion, _dbVersion);
      },
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE obrigados (
        id INTEGER PRIMARY KEY,
        nome TEXT NOT NULL,
        zap TEXT NOT NULL,
        mensagem_personalizada TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE transacoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_obrigado INTEGER NOT NULL,
        data_emprestimo TEXT NOT NULL,
        valor_empresado REAL NOT NULL,
        percentual_juros REAL NOT NULL,
        retorno REAL NOT NULL,
        data_pagamento_retorno TEXT,
        data_pagamento_completo TEXT,
        data_vencimento TEXT,
        FOREIGN KEY (id_obrigado) REFERENCES obrigados (id)
      );
    ''');
  }

  FutureOr<void> _onUpgradeWithCheck(Database db, int oldVersion, int newVersion) async {
    // Verifica se tabelas essenciais existem, caso contrário executa onCreate manualmente
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='obrigados'");
    if (tables.isEmpty) {
      await _onCreate(db, newVersion); // força criação das tabelas
      return;
    }

    // Executa atualizações de versão se necessário
    if (oldVersion < 2) {
      final obrigadosColumns = await db.rawQuery("PRAGMA table_info(obrigados)");
      final transacoesColumns = await db.rawQuery("PRAGMA table_info(transacoes)");

      final temMensagem = obrigadosColumns.any((c) => c['name'] == 'mensagem_personalizada');
      final temVencimento = transacoesColumns.any((c) => c['name'] == 'data_vencimento');

      if (!temMensagem) {
        await db.execute('ALTER TABLE obrigados ADD COLUMN mensagem_personalizada TEXT;');
      }
      if (!temVencimento) {
        await db.execute('ALTER TABLE transacoes ADD COLUMN data_vencimento TEXT;');
      }
    }
  }
}
