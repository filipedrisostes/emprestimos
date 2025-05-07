import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/database_helper.dart';

import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/models/transacao.dart';
import 'package:emprestimos/screens/cadastro_obrigado_screen.dart';
import 'package:emprestimos/screens/cadastro_transacao_screen.dart';
import 'package:emprestimos/screens/configuracao_screen.dart';
import 'package:emprestimos/screens/estatisticas_screen.dart';
import 'package:emprestimos/screens/backup_screen.dart';
import 'package:emprestimos/screens/lista_obrigados_screen.dart';
import 'package:emprestimos/services/offline_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TransacaoDao _transacaoDao = TransacaoDao(DatabaseHelper.instance);
  final ObrigadoDao _obrigadoDao = ObrigadoDao(DatabaseHelper.instance);
  List<Transacao> _transacoes = [];
  double _totalReceber = 0;
  DateTime _currentMonth = DateTime.now();
  List<Obrigado> _obrigados = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _enviarMensagensAutomaticamente();
  }


  Future<void> _enviarWhatsApp(Obrigado obrigado, double valor) async {
    // Remove caracteres não numéricos do telefone
    String numeroLimpo = obrigado.zap.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeroLimpo.startsWith('0') && numeroLimpo.length > 1) {
      numeroLimpo = numeroLimpo.substring(1);
    }
    String? mensagemPersonalizada = obrigado.mensagemPersonalizada;
    mensagemPersonalizada = mensagemPersonalizada?.replaceAll('#', obrigado.nome); 
    final mensagem = Uri.encodeFull(
      mensagemPersonalizada != null 
      ? mensagemPersonalizada
      : 'Olá ${obrigado.nome}, tudo bem? Lembrando que o valor de ${_currencyFormat.format(valor)} vence este mês.'
    );

    final url = 'https://wa.me/$numeroLimpo?text=$mensagem';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Força abertura no app externo
        );
      } else {
        // Fallback para abrir no navegador
        final webUrl = 'https://web.whatsapp.com/send?phone=$numeroLimpo&text=$mensagem';
        await launchUrl(
          Uri.parse(webUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir WhatsApp: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }  

  Future<void> _carregarTransacoes() async {
    final primeiroDia = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final ultimoDia = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    final transacoes = await _transacaoDao.getTransacoesByPeriodo(primeiroDia, ultimoDia);
    setState(() {
      _transacoes = transacoes;
    });
  }

  void _proximoMes() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _carregarDados();
    });
  }

  void _mesAnterior() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _carregarDados();
    });
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    
    try {
      final primeiroDia = DateTime(_currentMonth.year, _currentMonth.month, 1);
      final ultimoDia = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
      
      final [transacoes, obrigados] = await Future.wait([
        _transacaoDao.getTransacoesByPeriodo(primeiroDia, ultimoDia),
        _obrigadoDao.getAllObrigados(),
      ] as Iterable<Future>);
      
      for (var t in transacoes) {
        print('Transação carregada: ${t.toMap()}');
      }

      double total = 0;
      for (var transacao in transacoes) {
        if ((transacao.dataPagamentoCompleto == null && transacao.dataPagamentoRetorno == null)) {
          total += transacao.retorno;
        }
      }
      
      setState(()  {
        _totalReceber = total;
        _obrigados = obrigados;
        _isLoading = false;
        // Enfileirar automaticamente ao carregar dados
        /*final payload = {
          'obrigados': _obrigados.map((o) => o.toJson()).toList(),
          'transacoes': _transacoes.map((t) => t.toJson()).toList(),
        };
        await OfflineSyncService().enqueue(
          'https://SEU_BACKEND_AQUI/sync', // ajuste para sua URL real
          payload,
        );*/
        // —————————————————————
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: ${e.toString()}')),
      );
    }
  }

  Future<void> _marcarComoPagoTotal(Transacao transacao) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Pagamento'),
        content: const Text('Deseja marcar esta transação como totalmente paga?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await _transacaoDao.updateDataPagamentoCompleto(transacao.id, DateTime.now());
      await _carregarDados();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagamento registrado com sucesso!')),
      );
    }
  }

  Future<void> _marcarComoPagoJuros(Transacao transacao) async {
    await _transacaoDao.updateDataPagamentoRetorno(transacao.id, DateTime.now());
    
    // Cria nova transação para o próximo mês
    final novaTransacao = Transacao(
      id: transacao.id,
      idObrigado: transacao.idObrigado,
      dataEmprestimo: DateTime(
        transacao.dataEmprestimo.year,
        transacao.dataEmprestimo.month + 1,
        transacao.dataEmprestimo.day,
      ),
      valorEmprestado: transacao.valorEmprestado,
      percentualJuros: transacao.percentualJuros,
      retorno: transacao.retorno,
    );
    
    await _transacaoDao.insertTransacao(novaTransacao);
    await _carregarDados();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Juros pagos e nova transação criada!')),
    );
  }

  Obrigado _encontrarObrigado(int? idObrigado) {
  if (idObrigado == null) {
    return Obrigado(
      id: 0,
      nome: 'ID Obrigado inválido',
      zap: '---',
    );
  }

  return _obrigados.firstWhere(
    (o) => o.id == idObrigado,
    orElse: () => Obrigado(
      id: idObrigado,
      nome: 'Obrigado não encontrado',
      zap: '---',
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empréstimos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CadastroTransacaoScreen()),
              ).then((_) {
                 _carregarTransacoes();
              } );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // Conteúdo visível
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: _mesAnterior,
                    ),
                    Text(
                      _capitalize(DateFormat('MMMM/yyyy').format(_currentMonth)),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: _proximoMes,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FutureBuilder<List<Transacao>>(
                        future: _transacaoDao.getTransacoesByPeriodo(
                          DateTime(_currentMonth.year, _currentMonth.month, 1),
                          DateTime(_currentMonth.year, _currentMonth.month + 1, 0),
                        ),
                        builder: (context, snapshot) {
                                                  if (snapshot.hasError) {
                          print('Erro completo no snapshot: ${snapshot.error}');
                          return const Center(
                            child: Text('Erro ao carregar as transações.'),
                          );
                        }

                          final transacoes = snapshot.data ?? [];

                          if (transacoes.isEmpty) {
                            return const Center(child: Text('Nenhuma transação este mês'));
                          }

                          return ListView.builder(
                            itemCount: transacoes.length,
                            itemBuilder: (context, index) {
                              final transacao = transacoes[index];
                              final obrigado = _encontrarObrigado(transacao.idObrigado);

                              return _buildTransacaoCard(transacao, obrigado);
                            },
                          );
                        },
                      ),
              ),
              _buildTotalReceber(),
            ],
          ),

          // Camada invisível para capturar gestos
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent, // 👈 importante
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! < 0) {
                    _proximoMes();
                  } else if (details.primaryVelocity! > 0) {
                    _mesAnterior();
                  }
                }
              },
            ),
          ),
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 10),
                  Text("Sincronizando..."),
                ],
              ),
            ),

        ],
      ),

    );
  }

  Widget _buildTransacaoCard(Transacao transacao, Obrigado obrigado) {
  final hoje = DateTime.now();
  final bool vencido = transacao.dataVencimento != null && transacao.dataVencimento!.isBefore(hoje);

  return Card(
    margin: const EdgeInsets.all(8),
    elevation: 2,
    color: vencido ? Colors.red[100] : null,
    child: ListTile(
      title: Text(obrigado.nome),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Valor: ${_currencyFormat.format(transacao.valorEmprestado)}'),
          Text('Juros: ${transacao.percentualJuros}%'),
          Text('Total: ${_currencyFormat.format(transacao.retorno)}'),
          if (transacao.dataVencimento != null)
            Text('Vencimento: ${DateFormat('dd/MM/yyyy').format(transacao.dataVencimento!)}'),
          if (transacao.dataPagamentoCompleto != null)
            Text('Pago em: ${DateFormat('dd/MM/yyyy').format(transacao.dataPagamentoCompleto!)}', style: const TextStyle(color: Colors.green)),
          if (transacao.dataPagamentoRetorno != null)
            Text('Juros pagos em: ${DateFormat('dd/MM/yyyy').format(transacao.dataPagamentoRetorno!)}', style: const TextStyle(color: Colors.blue)),
        ],
      ),
      trailing: Wrap(
        spacing: -16,
        children: [
          if (transacao.dataPagamentoCompleto == null)
            IconButton(
              icon: const Icon(Icons.attach_money, color: Colors.green),
              tooltip: 'Marcar como totalmente pago',
              onPressed: () => _marcarComoPagoTotal(transacao),
            ),
          if (transacao.dataPagamentoCompleto == null)
            IconButton(
              icon: const Icon(Icons.percent, color: Colors.blue),
              tooltip: 'Pagar apenas juros',
              onPressed: () => _marcarComoPagoJuros(transacao),
            ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.orange),
            tooltip: 'Editar Transação',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CadastroTransacaoScreen(transacao: transacao),
                ),
              ).then((_) => _carregarDados());
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Excluir Transação',
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Excluir Transação'),
                  content: const Text('Tem certeza que deseja excluir esta transação?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                  ],
                ),
              );
              if (confirmar == true) {
                await _transacaoDao.deleteTransacao(transacao.id);
                await _carregarDados();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.phone_android, color: Colors.green),
            onPressed: () => _enviarWhatsApp(obrigado, transacao.valorEmprestado),
          )
        ],
      ),
    ),
  );
} // fim _buildTransacaoCard

  Widget _buildTotalReceber() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total a receber este mês:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            _currencyFormat.format(_totalReceber),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'Menu',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConfiguracaoScreen(),
                ),
              ).then((_) => _carregarDados());
            },
            //onTap: () => _abrirConfigJuros(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Obrigados'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListaObrigadosScreen(),
                ),
              ).then((_) => _carregarDados());
            },
          ),
          ListTile(
            leading: const Icon(Icons.monetization_on),
            title: const Text('Cadastrar Transação'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CadastroTransacaoScreen(),
                ),
              ).then((_) => _carregarDados());
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Estatísticas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EstatisticasScreen(),
                ),
              ).then((_) => _carregarDados());
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore_page),
            title: const Text('Backup e restauração'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackupScreen(),
                ),
              ).then((_) => _carregarDados());
            },
          ),
        ],
      ),
    );
  }


  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _enviarMensagensAutomaticamente() async {
  final hoje = DateTime.now();
  
  // Filtra transações vencidas e não pagas
  final vencidas = _transacoes.where((transacao) {
    return transacao.dataVencimento != null &&
           transacao.dataVencimento!.isBefore(hoje) &&
           transacao.dataPagamentoCompleto == null;
  }).toList();

  for (var transacao in vencidas) {
    final obrigado = _encontrarObrigado(transacao.idObrigado);

    // Usa a mensagem personalizada se existir, senão a padrão
    final mensagem = Uri.encodeFull(
      obrigado.mensagemPersonalizada != null && obrigado.mensagemPersonalizada!.isNotEmpty
          ? obrigado.mensagemPersonalizada!
          : 'Olá ${obrigado.nome}, tudo bem? Lembrando que o valor de ${_currencyFormat.format(transacao.retorno)} venceu.'
    );

    final numeroLimpo = obrigado.zap.replaceAll(RegExp(r'[^0-9]'), '');
    final url = 'https://wa.me/$numeroLimpo?text=$mensagem';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar mensagem: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}




}

class ConfiguracaoService {
  static const _jurosPadraoKey = 'juros_padrao';

  static Future<double> getJurosPadrao() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_jurosPadraoKey) ?? 5.0;
  }

  static Future<void> setJurosPadrao(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_jurosPadraoKey, valor);
  }
  
  

}