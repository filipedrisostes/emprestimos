import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emprestimos/screens/backup_screen.dart';

void main() {
  testWidgets('backup oferece Drive e arquivo local', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'email_padrao': 'teste@example.com'});
    await tester.pumpWidget(const MaterialApp(home: BackupScreen()));
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
