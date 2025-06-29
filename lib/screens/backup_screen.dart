import 'dart:io';
import 'package:emprestimos/database_helper.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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

  Future<void> realizarBackupLocal() async {  // Removi o parâmetro BuildContext
    try {
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);
      
      // 1. Obter diretório de Downloads visível ao usuário
      final downloadsDir = await _getDownloadsDirectory();
      if (downloadsDir == null) {
        if (mounted) _showMessage('Não foi possível acessar a pasta Downloads');
        return;
      }

      // 2. Criar subpasta para os backups (opcional)
      final backupDir = Directory('${downloadsDir.path}/EmprestimosBackups');
      if (!backupDir.existsSync()) {
        await backupDir.create(recursive: true);
      }

      // 3. Nome do arquivo com timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFile = File('${backupDir.path}/backup_emprestimos_$timestamp.db');
      
      // 4. Copiar o arquivo
      await backupFile.writeAsBytes(await dbFile.readAsBytes());
      
      // 5. Mostrar mensagem com localização
      if (mounted) _showMessage('Backup criado em: ${backupFile.path}');
      
      // 6. Opcional: Abrir o gerenciador de arquivos (Android)
      if (Platform.isAndroid) {
        await _openFileManager(backupFile.parent.path);
      }
    } catch (e) {
      if (mounted) _showMessage('Erro ao criar backup local: $e');
    }
  }

  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Para Android, usamos o diretório de Downloads público
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      // Para iOS, usamos o diretório de documentos
      return await getApplicationDocumentsDirectory();
    }
    // Outras plataformas
    return await getDownloadsDirectory();
  }

  Future<void> _openFileManager(String path) async {
    try {
      if (Platform.isAndroid) {
        await const MethodChannel('com.example/file_manager')
            .invokeMethod('openFileManager', {'path': path});
      }
    } catch (e) {
      print('Erro ao abrir gerenciador de arquivos: $e');
    }
  }

  Future<void> restaurarBackupLocal(BuildContext context) async {
    try {
      // Configuração do tipo de arquivo
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Database Files',
        extensions: ['db'],
      );

      // Abre o seletor de arquivos
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      
      if (file == null) return; // Usuário cancelou

      final backupFile = File(file.path);
      
      // Validar o arquivo (opcional)
      try {
        await databaseFactory.openDatabase(backupFile.path);
      } catch (e) {
        _showMessage('Arquivo de backup inválido: $e');
        return;
      }

      await DatabaseHelper.instance.close();

      final dbPath = await _getDatabasePath();
      final backupOld = File('$dbPath.bak');
      
      // Criar backup do banco atual
      if (File(dbPath).existsSync()) {
        await File(dbPath).copy(backupOld.path);
      }

      // Restaurar
      await backupFile.copy(dbPath);

      _showMessage('Backup restaurado com sucesso!');
    } catch (e) {
      _showMessage('Erro ao restaurar backup: $e');
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
    if (!mounted) return;
    final context = this.context;  // Acesso seguro ao contexto
    ScaffoldMessenger.of(context).showSnackBar(
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
                onPressed: realizarBackupLocal,
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