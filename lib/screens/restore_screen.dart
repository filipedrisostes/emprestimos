import 'package:flutter/material.dart';

class RestoreScreen extends StatelessWidget {
  const RestoreScreen({Key? key}) : super(key: key);

  Future<void> restoreBackup() async {
    // Implemente a lógica para listar e restaurar backups do Google Drive
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurar Backup'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: restoreBackup,
          child: const Text('Restaurar Backup'),
        ),
      ),
    );
  }
}
