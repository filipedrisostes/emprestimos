import 'package:flutter_test/flutter_test.dart';
import 'package:emprestimos/models/transacao.dart';
import 'package:emprestimos/services/ios_configuration.dart';
import 'package:emprestimos/services/notificacao_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
      () => messenger.setMockMethodCallHandler(IOSConfiguration.channel, null));

  test('Google iOS sem ID não chama SDK nativo com configuração inválida',
      () async {
    messenger.setMockMethodCallHandler(
        IOSConfiguration.channel, (_) async => {'clientId': '', 'schemes': []});
    await expectLater(IOSConfiguration.checkGoogleSignIn(), throwsStateError);
  });
  test('Google iOS exige esquema correspondente ao cliente', () async {
    messenger.setMockMethodCallHandler(
        IOSConfiguration.channel,
        (_) async => {
              'clientId': '123-test.apps.googleusercontent.com',
              'schemes': ['outro']
            });
    await expectLater(IOSConfiguration.checkGoogleSignIn(), throwsStateError);
    messenger.setMockMethodCallHandler(
        IOSConfiguration.channel,
        (_) async => {
              'clientId': '123-test.apps.googleusercontent.com',
              'schemes': ['com.googleusercontent.apps.123-test']
            });
    await IOSConfiguration.checkGoogleSignIn();
  });
  test('iOS mantém os 64 vencimentos mais próximos e exclui pagos e passados',
      () {
    final now = DateTime(2026, 10, 15, 10);
    Transacao row(int id, DateTime due, {bool paid = false}) => Transacao(
        id: id,
        idObrigado: 1,
        dataEmprestimo: now,
        dataVencimento: due,
        valorEmprestado: 100,
        percentualJuros: 10,
        retorno: 10,
        dataPagamentoCompleto: paid ? now : null);
    final rows = [
      row(999, now),
      row(998, now.add(const Duration(days: 1)), paid: true),
      for (var i = 80; i >= 1; i--) row(i, now.add(Duration(days: i))),
    ];
    final selected = NotificacaoService.proximas(rows, now, limit: 64);
    expect(selected.length, 64);
    expect(selected.first.id, 1);
    expect(selected.last.id, 64);
    expect(NotificacaoService.proximas(rows, now).length, 80);
  });
}
