import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('emprestimos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE obrigado (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        zap TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transacao (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_obrigado INTEGER NOT NULL,
        data_emprestimo TEXT NOT NULL,
        valor_emprestado REAL NOT NULL,
        percentual_juros REAL NOT NULL,
        retorno REAL NOT NULL,
        data_pagamento_retorno TEXT,
        data_pagamento_completo TEXT,
        FOREIGN KEY (id_obrigado) REFERENCES obrigado (id)
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}