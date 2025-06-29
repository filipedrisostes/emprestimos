import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _dbName = 'emprestimos.db';
  static const _dbVersion = 5; // Incrementado para 4 para nova migração
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
      onUpgrade: _onUpgradeWithCheck,
      onOpen: (db) async {
        await _onUpgradeWithCheck(db, _dbVersion, _dbVersion);
      },
    );
  }

  // Método para fechar a conexão com o banco de dados
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      // Tabela obrigados
      await txn.execute('''
        CREATE TABLE obrigados (
          id INTEGER PRIMARY KEY,
          nome TEXT NOT NULL,
          zap TEXT NOT NULL,
          mensagem_personalizada TEXT
        );
      ''');

      // Tabela transacao_pai (deve ser criada primeiro)
      await txn.execute('''
        CREATE TABLE transacao_pai (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          data_emprestimo TEXT NOT NULL,
          id_obrigado INTEGER NOT NULL,
          valor_emprestado REAL NOT NULL,
          percentual_juros REAL NOT NULL,
          qtde_parcelas INTEGER NOT NULL,
          FOREIGN KEY (id_obrigado) REFERENCES obrigados(id)
        );
      ''');

      // Tabela transacoes com FK já definida e todas colunas necessárias
      await txn.execute('''
        CREATE TABLE transacoes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          id_transacao_pai INTEGER NOT NULL,
          parcela INTEGER NOT NULL,
          retorno REAL NOT NULL,
          data_pagamento_retorno TEXT,
          data_pagamento_completo TEXT,
          data_vencimento TEXT,
          FOREIGN KEY (id_transacao_pai) REFERENCES transacao_pai(id)
        );
      ''');
    });
  }

  FutureOr<void> _onUpgradeWithCheck(Database db, int oldVersion, int newVersion) async {
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='obrigados'");
    if (tables.isEmpty) {
      await _onCreate(db, newVersion);
      return;
    }

    await db.transaction((txn) async {
      if (oldVersion < 2) {
        // Migração para versão 2
        if (!(await txn.rawQuery("PRAGMA table_info(obrigados)")).any((c) => c['name'] == 'mensagem_personalizada')) {
          await txn.execute('ALTER TABLE obrigados ADD COLUMN mensagem_personalizada TEXT;');
        }
        
        if (!(await txn.rawQuery("PRAGMA table_info(transacoes)")).any((c) => c['name'] == 'data_vencimento')) {
          await txn.execute('ALTER TABLE transacoes ADD COLUMN data_vencimento TEXT;');
          await txn.execute("UPDATE transacoes SET data_vencimento = DATE(data_emprestimo, '+30 days') WHERE data_vencimento IS NULL;");
        }
      }

      if (oldVersion < 3) {
        // Migração para versão 3 - Adicionar sistema de parcelas
        final hasTransacaoPai = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='transacao_pai'"
        );

        if (hasTransacaoPai.isEmpty) {
          // 1. Criar tabela transacao_pai
          await txn.execute('''
            CREATE TABLE transacao_pai (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              data_emprestimo TEXT NOT NULL,
              id_obrigado INTEGER NOT NULL,
              valor_emprestado REAL NOT NULL,
              percentual_juros REAL NOT NULL,
              qtde_parcelas INTEGER NOT NULL,
              FOREIGN KEY (id_obrigado) REFERENCES obrigados(id)
            );
          ''');

          // 2. Adicionar colunas temporárias
          await txn.execute('ALTER TABLE transacoes ADD COLUMN id_transacao_pai INTEGER;');
          await txn.execute('ALTER TABLE transacoes ADD COLUMN parcela INTEGER;');

          // 3. Popular transacao_pai
          await txn.execute('''
            INSERT INTO transacao_pai (
              data_emprestimo, id_obrigado, valor_emprestado, percentual_juros, qtde_parcelas
            )
            SELECT 
              data_emprestimo, id_obrigado, valor_empresado, percentual_juros, 1
            FROM transacoes
            GROUP BY id_obrigado, data_emprestimo, valor_empresado, percentual_juros;
          ''');

          // 4. Atualizar referências
          await txn.execute('''
            UPDATE transacoes 
            SET 
              id_transacao_pai = (
                SELECT id FROM transacao_pai 
                WHERE transacao_pai.data_emprestimo = transacoes.data_emprestimo
                AND transacao_pai.id_obrigado = transacoes.id_obrigado
                AND transacao_pai.valor_emprestado = transacoes.valor_empresado
                AND transacao_pai.percentual_juros = transacoes.percentual_juros
              ),
              parcela = 1;
          ''');
        }
      }

      if (oldVersion < 4) {
        // Migração para versão 4 - Corrigir problema de NOT NULL constraint
        // Verificar se a tabela já tem a coluna retorno
        final hasRetorno = (await txn.rawQuery(
          "PRAGMA table_info(transacoes)"
        )).any((column) => column['name'] == 'retorno');

        if (hasRetorno) {
          // 1. Criar nova tabela com estrutura correta
          await txn.execute('''
            CREATE TABLE transacoes_nova (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_obrigado INTEGER NOT NULL,
              id_transacao_pai INTEGER,
              parcela INTEGER,
              data_emprestimo TEXT NOT NULL,
              valor_empresado REAL NOT NULL,
              percentual_juros REAL NOT NULL,
              retorno REAL NOT NULL DEFAULT 0,
              data_pagamento_retorno TEXT,
              data_pagamento_completo TEXT,
              data_vencimento TEXT,
              FOREIGN KEY (id_obrigado) REFERENCES obrigados(id),
              FOREIGN KEY (id_transacao_pai) REFERENCES transacao_pai(id)
            );
          ''');

          // 2. Copiar dados garantindo que retorno tenha valor padrão
          await txn.execute('''
            INSERT INTO transacoes_nova (
              id, id_obrigado, id_transacao_pai, parcela, data_emprestimo, 
              valor_empresado, percentual_juros, retorno, 
              data_pagamento_retorno, data_pagamento_completo, data_vencimento
            )
            SELECT 
              id, id_obrigado, id_transacao_pai, parcela, data_emprestimo, 
              valor_empresado, percentual_juros, 
              CASE WHEN retorno IS NULL THEN valor_empresado * (1 + percentual_juros/100) ELSE retorno END,
              data_pagamento_retorno, data_pagamento_completo, data_vencimento
            FROM transacoes;
          ''');

          // 3. Trocar tabelas
          await txn.execute('DROP TABLE transacoes;');
          await txn.execute('ALTER TABLE transacoes_nova RENAME TO transacoes;');
        }
      }

      // Adicione esta migração após a versão 4
      if (oldVersion < 5) {
        // Migração para versão 5 - Simplificar estrutura da tabela transacoes
        await txn.execute('''
          CREATE TABLE transacoes_nova (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_transacao_pai INTEGER NOT NULL,
            parcela INTEGER NOT NULL,
            retorno REAL NOT NULL,
            data_pagamento_retorno TEXT,
            data_pagamento_completo TEXT,
            data_vencimento TEXT,
            FOREIGN KEY (id_transacao_pai) REFERENCES transacao_pai(id)
          );
        ''');

        // Copiar dados relevantes
        await txn.execute('''
          INSERT INTO transacoes_nova (
            id, id_transacao_pai, parcela, retorno, 
            data_pagamento_retorno, data_pagamento_completo, data_vencimento
          )
          SELECT 
            id, id_transacao_pai, parcela, retorno,
            data_pagamento_retorno, data_pagamento_completo, data_vencimento
          FROM transacoes;
        ''');

        // Trocar tabelas
        await txn.execute('DROP TABLE transacoes;');
        await txn.execute('ALTER TABLE transacoes_nova RENAME TO transacoes;');
      }
    });
  }
}