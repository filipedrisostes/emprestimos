import '../database_helper.dart';
import '../models/transacao_pai.dart';

class TransacaoPaiDao {
  final DatabaseHelper dbHelper;
  TransacaoPaiDao(this.dbHelper);
  Future<TransacaoPai?> getById(int id) async {
    final rows = await (await dbHelper.database)
        .query('transacao_pai', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : TransacaoPai.fromMap(rows.first);
  }

  Future<List<TransacaoPai>> getByObrigado(int id) async =>
      (await (await dbHelper.database).query('transacao_pai',
              where: 'id_obrigado = ?',
              whereArgs: [id],
              orderBy: 'data_emprestimo DESC'))
          .map(TransacaoPai.fromMap)
          .toList();
}
