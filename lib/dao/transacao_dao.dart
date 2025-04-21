import 'package:sqflite/sqflite.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/transacao.dart';

class TransacaoDao {
  final DatabaseHelper dbHelper;

  TransacaoDao(this.dbHelper);

  // Cria uma nova transação
  Future<int> insertTransacao(Transacao transacao) async {
    final db = await dbHelper.database;
    return await db.insert(
      'transacao',
      transacao.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Atualiza uma transação existente
  Future<int> updateTransacao(Transacao transacao) async {
    final db = await dbHelper.database;
    return await db.update(
      'transacao',
      transacao.toMap(),
      where: 'id = ?',
      whereArgs: [transacao.id],
    );
  }

  // Remove uma transação
  Future<int> deleteTransacao(int id) async {
    final db = await dbHelper.database;
    return await db.delete(
      'transacao',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Busca uma transação pelo ID
  Future<Transacao?> getTransacaoById(int id) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transacao',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Transacao.fromMap(maps.first);
    }
    return null;
  }

  // Lista todas as transações
  Future<List<Transacao>> getAllTransacoes() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('transacao');
    return List.generate(maps.length, (i) => Transacao.fromMap(maps[i]));
  }

  // Lista transações de um obrigado específico
  Future<List<Transacao>> getTransacoesByObrigado(int idObrigado) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transacao',
      where: 'id_obrigado = ?',
      whereArgs: [idObrigado],
    );
    return List.generate(maps.length, (i) => Transacao.fromMap(maps[i]));
  }

  // Atualiza a data de pagamento do retorno
  Future<int> updateDataPagamentoRetorno(int idTransacao, DateTime data) async {
    final db = await dbHelper.database;
    return await db.update(
      'transacao',
      {'data_pagamento_retorno': data.toIso8601String()},
      where: 'id = ?',
      whereArgs: [idTransacao],
    );
  }

  // Atualiza a data de pagamento completo
  Future<int> updateDataPagamentoCompleto(int idTransacao, DateTime data) async {
    final db = await dbHelper.database;
    return await db.update(
      'transacao',
      {'data_pagamento_completo': data.toIso8601String()},
      where: 'id = ?',
      whereArgs: [idTransacao],
    );
  }

  // Busca transações por período
  Future<List<Transacao>> getTransacoesByPeriodo(DateTime inicio, DateTime fim) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transacao',
      where: 'data_emprestimo BETWEEN ? AND ?',
      whereArgs: [
        inicio.toIso8601String(),
        fim.toIso8601String(),
      ],
    );
    return List.generate(maps.length, (i) => Transacao.fromMap(maps[i]));
  }

  

  
}