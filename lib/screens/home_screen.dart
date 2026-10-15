import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../dao/transacao_dao.dart';
import '../dao/obrigado_dao.dart';
import '../database_helper.dart';
import '../models/obrigado.dart';
import '../models/transacao.dart';
import '../services/notificacao_service.dart';
import 'cadastro_transacao_screen.dart';
import 'configuracao_screen.dart';
import 'estatisticas_screen.dart';
import 'backup_screen.dart';
import 'lista_obrigados_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _dao = TransacaoDao(DatabaseHelper.instance);
  final _money = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
  final _date = DateFormat('dd/MM/yyyy');
  DateTime _month = DateTime.now();
  List<Transacao> _items = [];
  Map<int, Obrigado> _clientes = {};
  Map<int, int> _parcelas = {};
  bool _loading = true;
  String? _filter;
  String? _error;
  int _loadGeneration = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _dao.getTransacoesByPeriodo(
          DateTime(_month.year, _month.month, 1),
          DateTime(_month.year, _month.month + 1, 0));
      final clients =
          await ObrigadoDao(DatabaseHelper.instance).getAllObrigados();
      final parents =
          await (await DatabaseHelper.instance.database).query('transacao_pai');
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _items = items;
        _clientes = {for (final c in clients) c.id!: c};
        _parcelas = {
          for (final p in parents) p['id'] as int: p['qtde_parcelas'] as int
        };
        _loading = false;
      });
    } catch (e) {
      if (mounted && generation == _loadGeneration)
        setState(() {
          _loading = false;
          _error = '$e';
        });
    }
  }

  bool _open(Transacao t) =>
      t.dataPagamentoCompleto == null && t.dataPagamentoRetorno == null;
  bool _matches(Transacao t) => switch (_filter) {
        'Em Aberto' => _open(t),
        'Pago Total' => t.dataPagamentoCompleto != null,
        'Pago Juros' => t.dataPagamentoRetorno != null,
        'Vencido' =>
          _open(t) && (t.dataVencimento?.isBefore(DateTime.now()) ?? false),
        _ => true,
      };
  void _move(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  Future<void> _page(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  Future<bool> _confirm(String title, String text) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) =>
              AlertDialog(title: Text(title), content: Text(text), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Confirmar')),
              ])) ??
      false;
  Future<void> _action(Transacao t, String action) async {
    final title = action == 'juros'
        ? 'Confirmar Pagamento de Juros'
        : action == 'quitar'
            ? 'Quitar Todas as Parcelas'
            : 'Excluir Transação';
    final text = action == 'juros'
        ? 'Confirmar o pagamento dos juros? Se sim, será lançada uma nova cobrança para o próximo mês'
        : action == 'quitar'
            ? 'Isso marcará TODAS as parcelas futuras como pagas. Continuar?'
            : 'Tem certeza que deseja excluir esta transação?';
    if (!await _confirm(title, text)) return;
    try {
      if (action == 'juros') {
        await _dao.pagarJuros(t.id!, DateTime.now());
      } else if (action == 'quitar') {
        await _dao.quitar(t.id!, DateTime.now(), futuras: true);
      } else {
        await _dao.deleteTransacao(t.id!);
      }
      await NotificacaoService.instance.atualizar();
      if (!mounted) return;
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(action == 'juros'
                ? 'Juros pagos com sucesso! Nova cobrança gerada.'
                : action == 'quitar'
                    ? 'Transação quitada com sucesso!'
                    : 'Transação excluída!')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _whatsapp(Transacao t, Obrigado c) async {
    final number =
        c.zap.replaceAll(RegExp(r'[^0-9]'), '').replaceFirst(RegExp(r'^0'), '');
    final message = (c.mensagemPersonalizada?.isNotEmpty ?? false)
        ? c.mensagemPersonalizada!.replaceAll('#', c.nome)
        : 'Olá ${c.nome}, tudo bem? Lembrando que o valor de ${_money.format(t.retorno)} vence este mês.';
    try {
      if (!await launchUrl(Uri.https('wa.me', '/$number', {'text': message}),
          mode: LaunchMode.externalApplication)) {
        throw StateError('Não foi possível abrir o WhatsApp');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao abrir WhatsApp: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where(_matches).toList();
    final total =
        _items.where(_open).fold<double>(0, (sum, t) => sum + t.retorno);
    final label = DateFormat('MMMM/yyyy', 'pt_BR').format(_month);
    return Scaffold(
        appBar: AppBar(title: const Text('Empréstimos'), actions: [
          IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _load),
          IconButton(
              tooltip: 'Cadastrar Transação',
              icon: const Icon(Icons.add),
              onPressed: () => _page(const CadastroTransacaoScreen())),
        ]),
        drawer: Drawer(
            child: ListView(padding: EdgeInsets.zero, children: [
          const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24))),
          for (final entry in <(IconData, String, Widget)>[
            (Icons.settings, 'Configurações', const ConfiguracaoScreen()),
            (Icons.person_add, 'Clientes', const ListaObrigadosScreen()),
            (
              Icons.monetization_on,
              'Cadastrar Transação',
              const CadastroTransacaoScreen()
            ),
            (Icons.bar_chart, 'Estatísticas', const EstatisticasScreen()),
            (Icons.restore_page, 'Backup e restauração', const BackupScreen()),
          ])
            ListTile(
                leading: Icon(entry.$1),
                title: Text(entry.$2),
                onTap: () {
                  Navigator.pop(context);
                  _page(entry.$3);
                }),
        ])),
        body: GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v.abs() > 100) _move(v < 0 ? 1 : -1);
            },
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                            onPressed: () => _move(-1),
                            icon: const Icon(Icons.arrow_back_ios)),
                        Text('${label[0].toUpperCase()}${label.substring(1)}',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(
                            onPressed: () => _move(1),
                            icon: const Icon(Icons.arrow_forward_ios)),
                      ])),
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Wrap(spacing: 10, children: [
                    for (final filter in [
                      'Em Aberto',
                      'Pago Total',
                      'Pago Juros',
                      'Vencido'
                    ])
                      OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              backgroundColor:
                                  _filter == filter ? Colors.blue[100] : null,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              textStyle: const TextStyle(fontSize: 9)),
                          onPressed: () => setState(() =>
                              _filter = _filter == filter ? null : filter),
                          child: Text(filter)),
                  ])),
              Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text('Erro ao carregar: $_error'))
                          : visible.isEmpty
                              ? const Center(
                                  child: Text('Nenhuma transação este mês'))
                              : ListView.builder(
                                  itemCount: visible.length,
                                  itemBuilder: (_, i) => _card(visible[i]))),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8))),
                  child: SafeArea(
                      top: false,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total a receber:',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(_money.format(total),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ]))),
            ])));
  }

  Widget _card(Transacao t) {
    final c = _clientes[t.idObrigado] ??
        Obrigado(id: t.idObrigado, nome: 'Obrigado não encontrado', zap: '');
    final color = t.dataPagamentoCompleto != null
        ? Colors.green[100]
        : t.dataPagamentoRetorno != null
            ? Colors.blue[100]
            : (t.dataVencimento?.isBefore(DateTime.now()) ?? false)
                ? Colors.red[100]
                : null;
    return Card(
        margin: const EdgeInsets.all(8),
        elevation: 2,
        color: color,
        child: ListTile(
            title: Text(c.nome),
            subtitle:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Data: ${_date.format(t.dataEmprestimo)}'),
              Text(
                  'Parcela: ${t.parcela} de ${_parcelas[t.idTransacaoPai] ?? 1}'),
              Text('Valor: ${_money.format(t.valorEmprestado)}'),
              Text('Juros: ${t.percentualJuros}%'),
              Text('Total: ${_money.format(t.retorno)}'),
              if (t.dataVencimento != null)
                Text('Prazo: ${_date.format(t.dataVencimento!)}'),
              if (t.dataPagamentoCompleto != null)
                Text('Pago em: ${_date.format(t.dataPagamentoCompleto!)}'),
              if (t.dataPagamentoRetorno != null)
                Text('Juros: ${_date.format(t.dataPagamentoRetorno!)}'),
            ]),
            trailing: Wrap(spacing: -20, children: [
              if (_open(t)) ...[
                IconButton(
                    tooltip: 'Marcar como totalmente pago',
                    icon: const Icon(Icons.attach_money, color: Colors.green),
                    onPressed: () => _action(t, 'quitar')),
                IconButton(
                    tooltip: 'Pagar apenas juros',
                    icon: const Icon(Icons.percent, color: Colors.blue),
                    onPressed: () => _action(t, 'juros')),
                IconButton(
                    tooltip: 'Editar Transação',
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () =>
                        _page(CadastroTransacaoScreen(transacao: t))),
                IconButton(
                    tooltip: 'Excluir Transação',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _action(t, 'excluir')),
              ],
              IconButton(
                  tooltip: 'WhatsApp',
                  icon: const Icon(Icons.phone_android, color: Colors.green),
                  onPressed: () => _whatsapp(t, c)),
            ])));
  }
}
