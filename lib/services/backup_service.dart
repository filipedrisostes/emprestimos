import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<void> realizarBackupLocal(BuildContext context) async {
  try {
    // Caminho do banco original
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'emprestimos.db');
    final dbFile = File(dbPath);

    // Salva no diretório interno do app
    final internalDir = await getApplicationDocumentsDirectory();
    final internalBackup = File(p.join(internalDir.path, 'backup_emprestimos.db'));
    await internalBackup.writeAsBytes(await dbFile.readAsBytes());

    // Salva também na pasta Downloads
    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync(recursive: true);
    }
    final downloadsBackup = File(p.join(downloadsDir.path, 'backup_emprestimos.db'));
    await downloadsBackup.writeAsBytes(await dbFile.readAsBytes());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup salvo em:\n${internalBackup.path}\n${downloadsBackup.path}')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao salvar backup: $e')),
    );
  }
}
