import 'dart:io';
import 'package:emprestimos/services/backup_service.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/google_drive_backup.dart';
import '../configuracao_service.dart';
import 'package:permission_handler/permission_handler.dart';

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

  Future<void> realizarBackupLocal(BuildContext context) async {
    try {
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);
      
      final appDocsDir = await getApplicationDocumentsDirectory();
      final backupFile = File(p.join(appDocsDir.path, 'backup_emprestimos.db'));
      
      await backupFile.writeAsBytes(await dbFile.readAsBytes());
      
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Backup local criado com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Erro ao criar backup local: $e')),
      );
    }
  }

  Future<void> restaurarBackupLocal(BuildContext context) async {
    try {
      // 1. Solicita permissão de leitura externa
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão negada para acessar a pasta Downloads.')),
        );
        return;
      }

      // 2. Obter o diretório de downloads
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasta Downloads não encontrada.')),
        );
        return;
      }

      // 3. Lista todos os arquivos .db
      final List<FileSystemEntity> entries = downloadsDir.listSync();
      final backupFiles = entries.whereType<File>().where((file) {
        final name = p.basename(file.path);
        return name.endsWith('.db') && name.contains('backup_emprestimos');
      }).toList();

      if (backupFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum backup encontrado na pasta Downloads.')),
        );
        return;
      }

      // 4. Ordena por data de modificação
      backupFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final File backupFile = backupFiles.first;

      // 5. Caminho do banco de dados
      final dbPath = p.join(await getDatabasesPath(), 'emprestimos.db');

      // 6. Cópia de segurança
      final backupOld = File('$dbPath.bak');
      if (File(dbPath).existsSync()) {
        await File(dbPath).copy(backupOld.path);
      }

      // 7. Restaurar backup
      await backupFile.copy(dbPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup restaurado com sucesso: ${p.basename(backupFile.path)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao restaurar backup: $e')),
      );
    }
  }

  // Função auxiliar para listar arquivos recursivamente
  Future<List<File>> _listFilesRecursive(Directory dir) async {
    final files = <File>[];
    try {
      await for (final file in dir.list()) {
        if (file is File) {
          files.add(file);
        } else if (file is Directory) {
          files.addAll(await _listFilesRecursive(file));
        }
      }
    } catch (e) {
      print('Erro ao listar arquivos: $e');
    }
    return files;
  }

  Future<String> _getDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    return join(databasesPath, 'emprestimos.db');
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context as BuildContext).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restauração')),
      body: Center(
        child: Padding(
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
                child: const Text('Restaurar Backup do Google Drive'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => realizarBackupLocal(context),
                child: const Text('Fazer Backup Local'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => restaurarBackupLocal(context),
                child: const Text('Restaurar Backup Local'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}