import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/models/transacao_pai.dart';
import 'package:emprestimos/services/partial_payment_service.dart';
import 'package:emprestimos/screens/home_screen.dart';

void main() {
  testWidgets(
      'home partial filter shows orange card and remaining balance on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    late Directory dir;
    await tester.runAsync(() async {
      await initializeDateFormatting('pt_BR');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      dir = await Directory.systemTemp.createTemp('partial_home_');
      await databaseFactory.setDatabasesPath(dir.path);
      final dao = TransacaoDao(DatabaseHelper.instance);
      final date = DateTime.now();
      final result = await dao.criarComCliente(
          TransacaoPai(
              idObrigado: 0,
              dataEmprestimo: date,
              valorEmprestado: 1000,
              percentualJuros: 10,
              qtdeParcelas: 1),
          date,
          nome: 'Cliente Parcial');
      final t = (await dao.getTransacoesByPai(result.emprestimoId)).first;
      await PartialPaymentService(DatabaseHelper.instance).pay(t.id!, 30, date);
    });
    addTearDown(() async {
      await DatabaseHelper.instance.close();
      await dir.delete(recursive: true);
    });
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    for (var i = 0;
        i < 20 && find.text('Cliente Parcial').evaluate().isEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parcial'));
    await tester.pumpAndSettle();
    expect(find.text('Cliente Parcial'), findsOneWidget);
    expect(find.text('Situação: Parcial'), findsOneWidget);
    expect(
        tester.widget<Card>(find.byType(Card).first).color, Colors.orange[100]);
    expect(find.textContaining('Saldo a receber:'), findsOneWidget);
    expect(find.byTooltip('Pagamento parcial'), findsOneWidget);
    await tester.tap(find.byTooltip('Pagamento parcial'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Em Aberto'));
    await tester.pumpAndSettle();
    expect(find.text('Cliente Parcial'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
