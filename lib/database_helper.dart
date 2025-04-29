import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const int _databaseVersion = 3; 

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('emprestimos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: _databaseVersion, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade, // ✅ Adiciona suporte a upgrades
    );
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
  // ✅ Novo método para atualização de estrutura de banco
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Atualizações para versão 2
      await db.execute('ALTER TABLE obrigado ADD COLUMN mensagemPersonalizada TEXT;');
      await db.execute('ALTER TABLE transacao ADD COLUMN dataVencimento TEXT;');
    }

    if (oldVersion < 3) {
      // Atualizações para versão 3
      await db.execute('UPDATE transacao SET dataVencimento = datetime(data_emprestimo, \'+30 days\') WHERE dataVencimento IS NULL;');
    }

    // Se no futuro subir para 3, 4, 5... adiciona novos if aqui
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}