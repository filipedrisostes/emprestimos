import 'loan_origin.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/obrigado.dart';
import '../models/emprestimo_detalhado.dart';

Future<Uint8List> buildClientStatementPdf(Obrigado cliente,
    List<EmprestimoDetalhado> items, DateTime generated) async {
  final _money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  final _date = DateFormat('dd/MM/yyyy');
  List<List<String>> _rows(EmprestimoDetalhado item) => [
        for (final t in item.parcelas)
          [
            '${t.parcela}',
            _date.format(t.dataVencimento ?? t.dataEmprestimo),
            _money.format(t.retorno),
            t.situacao,
            t.dataPagamentoCompleto != null
                ? _date.format(t.dataPagamentoCompleto!)
                : t.dataPagamentoRetorno != null
                    ? _date.format(t.dataPagamentoRetorno!)
                    : '-',
            _money.format(t.valorPagoParcial),
            _money.format(t.saldo),
          ]
      ];
  final regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/roboto-regular.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/roboto-bold.ttf'));
  final doc =
      pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  doc.addPage(pw.MultiPage(
      maxPages: 200,
      build: (_) => [
            pw.Header(level: 0, text: 'Extrato de empréstimos'),
            pw.Text('Cliente: ${cliente.nome}'),
            pw.Text('WhatsApp: ${cliente.zap}'),
            pw.Text('Emitido em ${_date.format(generated)}'),
            pw.Text(
                'Total originalmente emprestado: ${_money.format(items.where((e) => !e.emprestimo.parcelamento).fold<double>(0, (s, e) => s + e.emprestimo.valorEmprestado))}'),
            pw.Paragraph(
                text:
                    'As cobranças originais representam juros; parcelas de acordos representam o saldo renegociado, sem novo desembolso. A quitação reproduz o registro do aplicativo; este extrato não é comprovante bancário.'),
            for (final item in items) ...[
              pw.Header(level: 1, text: 'Empréstimo #${item.emprestimo.id}'),
              pw.Text(
                  'Data: ${_date.format(item.emprestimo.dataEmprestimo)} | Capital: ${_money.format(item.emprestimo.valorEmprestado)} | Juros: ${item.emprestimo.percentualJuros}%'),
              pw.TableHelper.fromTextArray(headers: [
                'Parcela',
                'Vencimento',
                'Valor',
                'Situação',
                'Pagamento',
                'Parciais',
                'Saldo'
              ], data: _rows(item)),
              if (item.emprestimo.origemHistorico != null) ...[
                pw.Header(level: 2, text: 'Origem do parcelamento'),
                for (final line
                    in loanOriginLines(item.emprestimo.origemHistorico!))
                  pw.Paragraph(text: line)
              ],
            ],
          ]));
  return doc.save();
}
