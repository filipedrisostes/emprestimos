import '../services/loan_origin.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/statement_pdf.dart';
import 'package:printing/printing.dart';
import '../database_helper.dart';
import '../models/obrigado.dart';
import '../models/emprestimo_detalhado.dart';
import '../models/transacao.dart';
import '../services/obrigado_service.dart';

String situacaoParcela(Transacao t) => t.situacao;

class ExtratoClienteScreen extends StatefulWidget {
  final Obrigado cliente;
  const ExtratoClienteScreen({super.key, required this.cliente});
  @override
  State<ExtratoClienteScreen> createState() => _ExtratoClienteScreenState();
}

class _ExtratoClienteScreenState extends State<ExtratoClienteScreen> {
  late final _future =
      ObrigadoService(DatabaseHelper.instance).detalhes(widget.cliente.id!);
  final _money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  final _date = DateFormat('dd/MM/yyyy');
  final _generated = DateTime.now();
  bool _exporting = false;
  List<List<String>> _rows(EmprestimoDetalhado item) => [
        for (final t in item.parcelas)
          [
            '${t.parcela}',
            _date.format(t.dataVencimento ?? t.dataEmprestimo),
            _money.format(t.retorno),
            situacaoParcela(t),
            t.dataPagamentoCompleto != null
                ? _date.format(t.dataPagamentoCompleto!)
                : t.dataPagamentoRetorno != null
                    ? _date.format(t.dataPagamentoRetorno!)
                    : '—',
            _money.format(t.valorPagoParcial),
            _money.format(t.saldo),
          ]
      ];
  Future<void> _share(List<EmprestimoDetalhado> items) async {
    setState(() => _exporting = true);
    try {
      await Printing.sharePdf(
          bytes:
              await buildClientStatementPdf(widget.cliente, items, _generated),
          filename: 'extrato_cliente_${widget.cliente.id}.pdf');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<EmprestimoDetalhado>>(
      future: _future,
      builder: (context, snapshot) => Scaffold(
          appBar: AppBar(title: const Text('Extrato por cliente'), actions: [
            IconButton(
                tooltip: 'Compartilhar PDF',
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: !snapshot.hasData || _exporting
                    ? null
                    : () => _share(snapshot.data!))
          ]),
          body: snapshot.hasError
              ? Center(child: Text('Erro: ${snapshot.error}'))
              : !snapshot.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(padding: const EdgeInsets.all(16), children: [
                      Text(widget.cliente.nome,
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text('Emitido em ${_date.format(_generated)}'),
                      Text(
                          'Total originalmente emprestado: ${_money.format(snapshot.data!.where((e) => !e.emprestimo.parcelamento).fold<double>(0, (s, e) => s + e.emprestimo.valorEmprestado))}'),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                              'As cobranças originais representam juros. Nos acordos, as parcelas representam o saldo renegociado. O total emprestado não soma novamente os acordos.')),
                      if (snapshot.data!.isEmpty)
                        const Text('Nenhum empréstimo cadastrado.'),
                      for (final item in snapshot.data!)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Empréstimo #${item.emprestimo.id} · ${_date.format(item.emprestimo.dataEmprestimo)}'),
                                      Text(
                                          'Capital: ${_money.format(item.emprestimo.valorEmprestado)} · Juros: ${item.emprestimo.percentualJuros}%'),
                                      if (item.emprestimo.origemHistorico !=
                                          null)
                                        ExpansionTile(
                                            title: const Text(
                                                'Origem do parcelamento'),
                                            children: [
                                              for (final line
                                                  in loanOriginLines(item
                                                      .emprestimo
                                                      .origemHistorico!))
                                                ListTile(title: Text(line))
                                            ]),
                                      for (final row in _rows(item))
                                        ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                                'Parcela ${row[0]} · ${row[3]}'),
                                            subtitle: Text(
                                                'Vence: ${row[1]} · Valor: ${row[2]}\nPagamento: ${row[4]}\nParciais: ${row[5]} · Saldo: ${row[6]}')),
                                    ]))),
                    ])));
}
