import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/screens/cadastro_transacao_screen.dart';

void main() {
  testWidgets('typing new client saves loan and opens Editar Cliente',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    late Directory dir;
    await tester.runAsync(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      dir = await Directory.systemTemp.createTemp('loan_form_');
      await databaseFactory.setDatabasesPath(dir.path);
      await DatabaseHelper.instance.database;
    });
    addTearDown(() async {
      await DatabaseHelper.instance.close();
      await dir.delete(recursive: true);
    });
    await tester.pumpWidget(const MaterialApp(home: CadastroTransacaoScreen()));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar Empréstimo'), findsOneWidget);
    final client = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Cliente');
    final value = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Valor Emprestado');
    await tester.enterText(client, 'Maria Nova');
    await tester.enterText(value, '100000');
    final save = find.text('Salvar Empréstimo');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });
    await tester.pumpAndSettle();
    for (var i = 0;
        i < 20 && find.text('Editar Cliente').evaluate().isEmpty;
        i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
    }
    expect(find.text('Editar Cliente'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '));
    await tester.runAsync(() async {
      final db = await DatabaseHelper.instance.database;
      final clients = await db.query('obrigados');
      final loans = await db.query('transacao_pai');
      expect(clients.single['nome'], 'Maria Nova');
      expect(clients.single['zap'], '');
      expect(loans.single['id_obrigado'], clients.single['id']);
    });
  });
}
