import 'package:sqflite/sqflite.dart';
import 'package:emprestimos/database_helper.dart';
import '../models/transacao_pai.dart';

class TransacaoPaiDao {
  final DatabaseHelper dbHelper;

  TransacaoPaiDao(this.dbHelper);

  Future<int> inserir(TransacaoPai transacaoPai) async {
    final db = await dbHelper.database;
    return await db.insert('transacao_pai', transacaoPai.toMap());
  }

  Future<int> atualizar(TransacaoPai transacaoPai) async {
    final db = await dbHelper.database;
    return await db.update(
      'transacao_pai',
      transacaoPai.toMap(),
      where: 'id = ?',
      whereArgs: [transacaoPai.id],
    );
  }

  Future<int> deletar(int id) async {
    final db = await dbHelper.database;
    return await db.delete(
      'transacao_pai',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<TransacaoPai?> buscarPorId(int id) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'transacao_pai',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return TransacaoPai.fromMap(maps.first);
    }
    return null;
  }

  Future<List<TransacaoPai>> listarTodos() async {
    final db = await dbHelper.database;
    final maps = await db.query('transacao_pai');
    return maps.map((map) => TransacaoPai.fromMap(map)).toList();
  }
  
}
