import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:emprestimos/database_helper.dart';
import 'package:sqflite/sqflite.dart'; // ajuste o caminho se necessário

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _status;
  final String dbFileName = 'emprestimos.db';

  Future<void> _selectFile() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: 'Todos os Arquivos', mimeTypes: ['*/*']),
      ],
    );

    if (file == null) {
      setState(() => _status = 'Nenhum arquivo selecionado.');
      return;
    }

    try {
      // Fecha a conexão atual
      await DatabaseHelper.instance.closeDatabase();

      // Copia o novo banco para o local padrão
      final dbDir = await getDatabasesPath();
      final targetPath = join(dbDir, dbFileName);
      final sourceFile = File(file.path);
      await sourceFile.copy(targetPath);

      // Força reabertura (opcional, se quiser testar na mesma tela)
      await DatabaseHelper.instance.database;

      setState(() => _status = 'Banco restaurado com sucesso!');
    } catch (e) {
      setState(() => _status = 'Erro ao restaurar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup e Restauração')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _selectFile,
              child: const Text('Selecionar Arquivo para Restauração'),
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _status!,
                  style: TextStyle(
                    color: _status!.contains('sucesso') ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
