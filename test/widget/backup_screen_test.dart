// test/widget/backup_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emprestimos/screens/backup_screen.dart';

void main() {
  testWidgets('BackupScreen mostra email e botões', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BackupScreen()));
    expect(find.text('Backup & Restauração'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNWidgets(2));
  });
}
