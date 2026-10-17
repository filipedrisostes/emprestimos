import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emprestimos/screens/backup_screen.dart';

void main() {
  testWidgets('backup oferece Drive e arquivo local', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'email_padrao': 'teste@example.com'});
    late Directory dir;
    await tester.runAsync(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      dir = await Directory.systemTemp.createTemp('backup_widget_');
      await databaseFactory.setDatabasesPath(dir.path);
      await DatabaseHelper.instance.database;
    });
    addTearDown(() async {
      await DatabaseHelper.instance.close();
      await dir.delete(recursive: true);
    });
    await tester.pumpWidget(const MaterialApp(home: BackupScreen()));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    for (final text in [
      'Fazer Backup no Google Drive',
      'Restaurar Backup do Google Drive',
      'Fazer Backup Local',
      'Restaurar Backup Local'
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text('Email configurado: teste@example.com'), findsOneWidget);
  });
}
