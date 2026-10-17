import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/models/transacao.dart';
import 'package:emprestimos/models/transacao_pai.dart';
import 'package:emprestimos/models/emprestimo_detalhado.dart';
import 'package:emprestimos/services/statement_pdf.dart';
import 'package:emprestimos/services/backup_status_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PDF supports accented names and multiple pages of installments',
      () async {
    final date = DateTime(2026, 10, 15);
    final loan = TransacaoPai(
        id: 1,
        idObrigado: 1,
        dataEmprestimo: date,
        valorEmprestado: 1000,
        percentualJuros: 10,
        qtdeParcelas: 100);
    final rows = List.generate(
        100,
        (i) => Transacao(
            id: i + 1,
            idTransacaoPai: 1,
            parcela: i + 1,
            idObrigado: 1,
            dataEmprestimo: date,
            valorEmprestado: 1000,
            percentualJuros: 10,
            retorno: 100));
    final bytes = await buildClientStatementPdf(
        Obrigado(id: 1, nome: 'João André', zap: '123'),
        [EmprestimoDetalhado(loan, rows)],
        date);
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(2000));
  });
  test('backup status persists confirmed upload and updates pending count',
      () async {
    SharedPreferences.setMockInitialValues({});
    final status = BackupStatusService();
    await status.initialize();
    expect(status.lastUpload, isNull);
    status.updatePending(3);
    expect(status.pending, 3);
    await status.uploaded('bkp_atual.db', 'teste@example.com');
    final restored = BackupStatusService();
    await restored.initialize();
    expect(restored.lastUpload!.isAtSameMomentAs(status.lastUpload!), true);
    expect(restored.account, 'teste@example.com');
    expect(restored.file, 'bkp_atual.db');
  });
}
