// lib/background_backup.dart

import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:workmanager/workmanager.dart';
import 'services/google_drive_backup.dart';
import 'configuracao_service.dart';

const _backupTask = "periodicBackup";

void callbackDispatcher() {
  /*Workmanager().executeTask((task, inputData) async {
    if (task == _backupTask) {
      try {
        // Recupera o e-mail configurado
        final email = await ConfiguracaoService.getEmailPadrao();

        // Encontra o arquivo db
        final databasesPath = await getDatabasesPath();
        final dbFile = File(join(databasesPath, 'emprestimos.db'));
        if (await dbFile.exists()) {
          // Envia o backup
          await GoogleDriveBackup().uploadBackup(dbFile, email);
        }
      } catch (e) {
        // Silent fail; será tentado no próximo ciclo
        print("Erro no backup periódico: $e");
      }
    }
    return Future.value(true);
  });*/
}
