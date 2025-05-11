import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<void> realizarBackupLocal(BuildContext context) async {
  try {
    // Solicita permissão (necessário no Android 10+)
    if (await Permission.storage.request().isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão negada para salvar o backup.')),
      );
      return;
    }

    // Caminho do banco
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'emprestimos.db');

    // Caminho do destino do backup
    final dirDestino = await getExternalStorageDirectory();
    final backupPath = p.join(dirDestino!.path, 'backup_emprestimos.db');

    // Copia o arquivo
    final dbFile = File(dbPath);
    final backupFile = File(backupPath);
    await backupFile.writeAsBytes(await dbFile.readAsBytes());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup salvo em: ${backupFile.path}')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao fazer backup: $e')),
    );
  }
}
