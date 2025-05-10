import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/obrigado.dart';

class ObrigadoDao {
  final DatabaseHelper dbHelper;

  ObrigadoDao(this.dbHelper);

  Future<int> insertObrigado(Obrigado obrigado) async {
    final db = await dbHelper.database;
    return await db.insert('obrigados', obrigado.toMap());
  }

  Future<List<Obrigado>> getAllObrigados() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('obrigados');
    return List.generate(maps.length, (i) {
      return Obrigado.fromMap(maps[i]);
    });
  }

  Future<int> updateObrigado(Obrigado obrigado) async {
    final db = await dbHelper.database;
    return await db.update(
      'obrigados',
      obrigado.toMap(),
      where: 'id = ?',
      whereArgs: [obrigado.id],
    );
  }

  Future<int> deleteObrigado(int id) async {
    final db = await dbHelper.database;
    return await db.delete(
      'obrigados',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Obrigado?> getObrigadoById(int id) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'obrigados',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Obrigado.fromMap(maps.first);
    }
    return null;
  }
}
