import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emprestimos/models/transacao.dart';
import 'package:emprestimos/widgets/partial_payment_dialog.dart';

void main() {
  testWidgets('checkbox reveals agreement fields and returns remaining total',
      (tester) async {
    PartialPaymentInput? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showDialog<PartialPaymentInput>(
                          context: context,
                          builder: (_) => PartialPaymentDialog(
                              transaction: Transacao(
                                  id: 1,
                                  idObrigado: 1,
                                  dataEmprestimo: DateTime(2026),
                                  valorEmprestado: 1000,
                                  percentualJuros: 10,
                                  retorno: 100)));
                    },
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('partial-total')), findsNothing);
    await tester.enterText(find.byKey(const Key('partial-amount')), '2000');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.text('Total para quitação'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('partial-total')), '50000');
    await tester.enterText(find.byKey(const Key('partial-count')), '3');
    await tester.tap(find.text('Salvar pagamento'));
    await tester.pumpAndSettle();
    expect(result!.amount, 20);
    expect(result!.total, 500);
    expect(result!.installments, 3);
    expect(tester.takeException(), isNull);
  });
}
