import 'dart:convert';
import 'package:sqflite/sqflite.dart';

class AuditService {
  static const tables = [
    'obrigados',
    'transacao_pai',
    'transacoes',
    'configuracoes',
    'pagamentos_parciais'
  ];
  static Future<Map<String, Map<Object?, Map<String, Object?>>>> snapshot(
          DatabaseExecutor db) async =>
      {
        for (final table in tables)
          table: {for (final row in await db.query(table)) row['id']: row}
      };

  static Future<void> record(DatabaseExecutor db,
      Map<String, Map<Object?, Map<String, Object?>>> before) async {
    final after = await snapshot(db);
    final now = DateTime.now().toUtc().toIso8601String();
    for (final table in tables) {
      for (final id in {...before[table]!.keys, ...after[table]!.keys}) {
        final old = before[table]![id];
        final row = after[table]![id];
        if (jsonEncode(old) == jsonEncode(row)) continue;
        final reference = row ?? old!;
        await db.insert('historico_alteracoes', {
          'data': now,
          'entidade': table,
          'registro_id': id,
          'cliente_id': table == 'obrigados' ? id : reference['id_obrigado'],
          'acao': old == null
              ? 'Criado'
              : row == null
                  ? 'Excluído'
                  : 'Alterado',
          'antes': old == null ? null : jsonEncode(old),
          'depois': row == null ? null : jsonEncode(row),
        });
      }
    }
  }
}
