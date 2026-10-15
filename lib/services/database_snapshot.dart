import 'dart:io';
import 'package:sqflite/sqflite.dart';

// A consistent SQLite snapshot, including WAL data, without closing the live DB.
// Works on older Android SQLite versions that do not support VACUUM INTO.
Future<File> databaseSnapshot(Database db, String destination) async {
  final temp = File('$destination.partial');
  await temp.parent.create(recursive: true);
  if (await temp.exists()) await temp.delete();
  final copy = await openDatabase(temp.path, singleInstance: false);
  var complete = false;
  try {
    await db.transaction((source) async {
      final schema = await source.rawQuery(
          "SELECT type,name,sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata' ORDER BY type='table' DESC");
      await copy.transaction((target) async {
        for (final table in schema.where((s) => s['type'] == 'table')) {
          await target.execute(table['sql'] as String);
          final name = table['name'] as String;
          final quoted = '"${name.replaceAll('"', '""')}"';
          for (final row in await source.rawQuery('SELECT * FROM $quoted')) {
            await target.insert(quoted, row);
          }
        }
        // Preserve AUTOINCREMENT high-water marks even after deletions.
        final hasSequence = await source.rawQuery(
            "SELECT name FROM sqlite_master WHERE name='sqlite_sequence'");
        if (hasSequence.isNotEmpty) {
          await target.delete('sqlite_sequence');
          for (final row in await source.query('sqlite_sequence')) {
            await target.insert('sqlite_sequence', row);
          }
        }
        for (final item in schema.where((s) => s['type'] != 'table')) {
          await target.execute(item['sql'] as String);
        }
        final version =
            (await source.rawQuery('PRAGMA user_version')).single.values.first;
        await target.execute('PRAGMA user_version = $version');
      });
    });
    complete = true;
  } finally {
    await copy.close();
    if (!complete && await temp.exists()) await temp.delete();
  }
  return temp.rename(destination);
}
