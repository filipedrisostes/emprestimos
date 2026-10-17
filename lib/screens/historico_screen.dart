import '../services/loan_origin.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class HistoricoScreen extends StatefulWidget {
  final int? clienteId;
  const HistoricoScreen({super.key, this.clienteId});
  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final _rows = <Map<String, Object?>>[];
  bool _loading = false, _more = true;
  String? _error;
  static const labels = {
    'obrigados': 'Cliente',
    'transacao_pai': 'Empréstimo',
    'transacoes': 'Parcela',
    'configuracoes': 'Configurações',
    'backup': 'Backup',
    'pagamentos_parciais': 'Pagamento parcial'
  };
  static const fields = {
    'valor_pago_parcial': 'Pagamentos parciais acumulados',
    'renegociado_em': 'Transferência para novo acordo',
    'parcelamento': 'Parcela de acordo',
    'origem_emprestimo_id': 'Empréstimo de origem',
    'origem_historico': 'Origem do parcelamento',
    'transacao_id': 'Parcela de origem',
    'valor': 'Valor pago',
    'tipo': 'Tipo do pagamento',
    'data': 'Data do pagamento',
    'nome': 'Nome',
    'zap': 'WhatsApp',
    'id_obrigado': 'Cliente',
    'valor_empresado': 'Valor emprestado',
    'valor_emprestado': 'Valor emprestado',
    'percentual_juros': 'Juros (%)',
    'retorno': 'Juros da parcela',
    'data_pagamento_retorno': 'Pagamento dos juros',
    'data_pagamento_completo': 'Quitação',
    'data_vencimento': 'Vencimento',
    'data_emprestimo': 'Data do empréstimo',
    'qtde_parcelas': 'Quantidade de parcelas',
    'parcela': 'Parcela',
    'email_padrao': 'E-mail',
    'juros_padrao': 'Juros padrão',
    'zap_padrao': 'Celular',
    'dias_vencimento_padrao': 'Dias para vencimento',
    'mensagem_personalizada': 'Mensagem'
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await (await DatabaseHelper.instance.database).query(
          'historico_alteracoes',
          where: widget.clienteId == null ? null : 'cliente_id = ?',
          whereArgs: widget.clienteId == null ? null : [widget.clienteId],
          orderBy: 'id DESC',
          limit: 50,
          offset: _rows.length);
      if (mounted)
        setState(() {
          _rows.addAll(rows);
          _more = rows.length == 50;
        });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _entry(Map<String, Object?> row) {
    final old = row['antes'] == null
        ? <String, dynamic>{}
        : jsonDecode(row['antes'] as String) as Map<String, dynamic>;
    final next = row['depois'] == null
        ? <String, dynamic>{}
        : jsonDecode(row['depois'] as String) as Map<String, dynamic>;
    final keys = {...old.keys, ...next.keys}.where((k) => old[k] != next[k]);
    return ExpansionTile(
        title: Text(
            '${labels[row['entidade']] ?? row['entidade']} #${row['registro_id'] ?? ''} · ${row['acao']}'),
        subtitle: Text(DateFormat('dd/MM/yyyy HH:mm:ss')
            .format(DateTime.parse(row['data'] as String).toLocal())),
        children: [
          for (final key in keys)
            ListTile(
                dense: true,
                title: Text(fields[key] ?? key),
                subtitle: Text(key == 'origem_historico' && next[key] is String
                    ? loanOriginLines(next[key] as String).join('\n')
                    : '${old[key] ?? '—'} → ${next[key] ?? '—'}'))
        ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Histórico de alterações')),
      body: ListView(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                'Alterações registradas a partir desta versão. Ao restaurar, o histórico acompanha o backup escolhido.')),
        ..._rows.map(_entry),
        if (_rows.isEmpty && !_loading && _error == null)
          const ListTile(title: Text('Nenhuma alteração registrada.')),
        if (_error != null) ListTile(title: Text(_error!)),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_more && !_loading)
          TextButton(onPressed: _load, child: const Text('Carregar mais')),
      ]));
}
