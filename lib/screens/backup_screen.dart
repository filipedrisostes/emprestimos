import 'dart:io';
import 'package:emprestimos/services/backup_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../services/google_drive_backup.dart';
import '../configuracao_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({Key? key}) : super(key: key);

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String email = '';

  @override
  void initState() {
    super.initState();
    _carregarEmailConfigurado();
  }

  Future<void> _carregarEmailConfigurado() async {
    final configurado = await ConfiguracaoService.getEmailPadrao();
    setState(() {
      email = configurado;
    });
  }

  Future<void> _fazerBackup() async {
    final dbPath = await _getDatabasePath();
    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      _showMessage('Arquivo de banco de dados não encontrado.');
      return;
    }

    try {
      await GoogleDriveBackup().uploadBackup(dbFile, email);
      _showMessage('Backup enviado com sucesso!');
    } catch (e) {
      _showMessage('Erro ao fazer backup: $e');
    }
  }

  Future<void> _restaurarBackup() async {
    try {
      final success = await GoogleDriveBackup().restoreBackup(email);
      if (success) {
        _showMessage('Backup restaurado com sucesso!');
      } else {
        _showMessage('Nenhum backup encontrado no Drive.');
      }
    } catch (e) {
      _showMessage('Erro ao restaurar backup: $e');
    }
  }

  Future<String> _getDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, 'emprestimos.db');
  }

  void _showMessage(String msg) {
    print(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restauração')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Email configurado: $email'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fazerBackup,
              child: const Text('Fazer Backup no Google Drive'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _restaurarBackup,
              child: const Text('Restaurar Backup'),
            ),
            ElevatedButton(
              onPressed: () => realizarBackupLocal(context),
              child: const Text('Fazer Backup Local'),
            ),
          ],
        ),
      ),
    );
  }
}
