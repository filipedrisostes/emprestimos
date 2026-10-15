import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models/obrigado.dart';
import '../models/emprestimo_detalhado.dart';
import '../services/obrigado_service.dart';

class DetalhesObrigadoScreen extends StatefulWidget {
  final Obrigado obrigado;
  const DetalhesObrigadoScreen({super.key, required this.obrigado});
  @override
  State<DetalhesObrigadoScreen> createState() => _DetalhesObrigadoScreenState();
}

class _DetalhesObrigadoScreenState extends State<DetalhesObrigadoScreen> {
  late final _future =
      ObrigadoService(DatabaseHelper.instance).detalhes(widget.obrigado.id!);
  final _money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  final _date = DateFormat('dd/MM/yyyy');
  Widget _stat(String name, String value) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(name, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ])));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.obrigado.nome), centerTitle: true),
      body: FutureBuilder<List<EmprestimoDetalhado>>(
          future: _future,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('Erro: ${s.error}'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            final items = s.data!;
            final total = items.fold<double>(
                0, (v, e) => v + e.emprestimo.valorEmprestado);
            final juros = items.fold<double>(0, (v, e) => v + e.jurosPagos);
            final pago = items.where((e) => e.pago).fold<double>(
                0,
                (v, e) =>
                    v +
                    e.emprestimo.valorEmprestado *
                        (1 + e.emprestimo.percentualJuros / 100));
            return ListView(padding: const EdgeInsets.all(4), children: [
              Row(children: [
                Expanded(
                    child: _stat('Total de Empréstimos', '${items.length}')),
                Expanded(
                    child: _stat('Empréstimos Pagos',
                        '${items.where((e) => e.pago).length}/${items.length}'))
              ]),
              _stat('Total Emprestado', _money.format(total)),
              Row(children: [
                Expanded(child: _stat('Juros Pagos', _money.format(juros))),
                Expanded(
                    child: _stat('Pago Integralmente', _money.format(pago)))
              ]),
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                      child: Text('Detalhes dos Empréstimos',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)))),
              for (final e in items)
                Card(
                    child: ExpansionTile(
                        title: Text('Empréstimo ${e.emprestimo.id}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'Valor: ${_money.format(e.emprestimo.valorEmprestado)}'),
                        trailing: Chip(
                            label: Text(e.pago ? 'Pago' : 'Em Aberto'),
                            backgroundColor: e.pago ? Colors.green[50] : null),
                        children: [
                      Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Data: ${_date.format(e.emprestimo.dataEmprestimo)}'),
                                Text(
                                    'Valor: ${_money.format(e.emprestimo.valorEmprestado)}'),
                                Text('Juros: ${e.emprestimo.percentualJuros}%'),
                                Text(
                                    'Status: ${e.pago ? 'Pago' : 'Em Aberto'}'),
                                const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('Parcelas',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                for (final t in e.parcelas)
                                  ListTile(
                                      title: Text('Parcela ${t.parcela}'),
                                      subtitle: Text([
                                        if (t.dataVencimento != null)
                                          'Vencimento: ${_date.format(t.dataVencimento!)}',
                                        'Valor: ${_money.format(t.retorno)}',
                                        if (t.dataPagamentoCompleto != null)
                                          'Pago em: ${_date.format(t.dataPagamentoCompleto!)}',
                                        if (t.dataPagamentoRetorno != null)
                                          'Juros pagos em: ${_date.format(t.dataPagamentoRetorno!)}',
                                      ].join('\n'))),
                              ]))
                    ])),
            ]);
          }));
}
