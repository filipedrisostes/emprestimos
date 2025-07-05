import 'dart:convert';

import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/dao/transacao_pai_dao.dart';
import 'package:emprestimos/database_helper.dart';

import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/models/transacao.dart';
import 'package:emprestimos/models/transacao_pai.dart';
import 'package:emprestimos/screens/cadastro_transacao_screen.dart';
import 'package:emprestimos/screens/configuracao_screen.dart';
import 'package:emprestimos/screens/database_explorer_screen.dart';
import 'package:emprestimos/screens/estatisticas_screen.dart';
import 'package:emprestimos/screens/backup_screen.dart';
import 'package:emprestimos/screens/lista_obrigados_screen.dart';
import 'package:emprestimos/services/notificacao_service.dart';
import 'package:emprestimos/services/offline_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  final TransacaoPaiDao _transacaoPaiDao = TransacaoPaiDao(DatabaseHelper.instance);
  double _totalReceber = 0;
  DateTime _currentMonth = DateTime.now();
  List<Obrigado> _obrigados = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _mostrarTodos = true;
  bool _mostrarEmAberto = false;
  bool _mostrarPagoTotal = false;
  bool _mostrarPagoJuros = false;
  bool _mostrarVencido = false;
  int _storageTapCount = 0;
  DateTime? _lastTapTime;

  // Secret tap variables
  int _secretTapCount = 0;
  DateTime? _lastSecretTap;
  
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _carregarDados();
    //_enviarMensagensAutomaticamente();
    checkUpdate();
  }

  void _handleSecretTap() {
    final now = DateTime.now();
    
    // Reseta se passou mais de 3 segundos desde o último toque
    if (_lastSecretTap != null && now.difference(_lastSecretTap!) > Duration(seconds: 3)) {
      _secretTapCount = 0;
    }

    _secretTapCount++;
    _lastSecretTap = now;

    if (_secretTapCount >= 10) {
      _secretTapCount = 0;
      _showCodeInputDialog(context); // Mostra o diálogo após 10 toques
    }
  }
  

  Future<void> _enviarWhatsApp(Obrigado obrigado, double valor) async {
    // Remove caracteres não numéricos do telefone
    String numeroLimpo = obrigado.zap.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeroLimpo.startsWith('0') && numeroLimpo.length > 1) {
      numeroLimpo = numeroLimpo.substring(1);
    }
    String? mensagemPersonalizada = obrigado.mensagemPersonalizada;
    mensagemPersonalizada = mensagemPersonalizada?.replaceAll('#', obrigado.nome); 
    mensagemPersonalizada = mensagemPersonalizada?.replaceAll('%', _currencyFormat.format(valor)); 
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
    
    double total = 0;
    for (var transacao in transacoes) {
      if ((transacao.dataPagamentoCompleto == null && transacao.dataPagamentoRetorno == null)) {
        total += transacao.retorno;
      }
    }
    
    setState(()  {
      _transacoes = transacoes; // Armazena as transações no estado
      _totalReceber = total;
      _obrigados = obrigados;
      _isLoading = false;
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
        title: const Text('Quitar Todas as Parcelas'),
        content: const Text('Isso marcará TODAS as parcelas futuras como pagas. Continuar?'),
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

    if (confirmado != true) return;

    setState(() => _isLoading = true);
    
    try {
      final agora = DateTime.now();
      await _transacaoDao.updateDataPagamentoCompleto(transacao.id!, agora);
      await _transacaoDao.updateParcelasFuturasComoPagas(transacao.idTransacaoPai, agora);
      await _carregarDados();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transação quitada com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _marcarComoPagoJuros(Transacao transacao) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Pagamento de Juros'),
        content: const Text('Confirmar o pagamento dos juros? Se sim, será lançada uma nova cobrança para o próximo mês'),
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

    if (confirmado != true) return;

    setState(() => _isLoading = true);
    
    try {
      // Busca transação pai
      final transacaoPai = await _transacaoPaiDao.buscarPorId(transacao.idTransacaoPai);
      
      if (transacaoPai == null) {
        throw Exception('Transação pai não encontrada');
      }

      // Marca juros como pagos
      await _transacaoDao.updateDataPagamentoRetorno(transacao.id!, DateTime.now());
      
      // Determina o número da próxima parcela
      final proximaParcela = transacaoPai.qtdeParcelas == 1 
          ? 1  // Mantém como parcela 1 se for única
          : transacao.parcela + 1;  // Incrementa normalmente para múltiplas parcelas
      
      // Cria nova cobrança para o próximo mês
      final novaTransacao = Transacao(
        id: null,
        dataVencimento: DateTime(
          transacao.dataVencimento!.year,
          transacao.dataVencimento!.month + 1,
          transacao.dataVencimento!.day,
        ),
        retorno: transacao.retorno,
        dataPagamentoRetorno: null,
        dataPagamentoCompleto: null,
        idTransacaoPai: transacao.idTransacaoPai,
        parcela: proximaParcela,  // Usa o valor calculado acima
      );
      
      await _transacaoDao.insertTransacao(novaTransacao);

      await _carregarDados();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Juros pagos com sucesso! Nova cobrança gerada.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
                 _carregarDados();
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
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row( // colocar os checkboxes para caber dentro da tela
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
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10.0,    // Espaço horizontal entre os itens
                      runSpacing: 8.0,  // Espaço vertical entre linhas quando houver quebra
                      children: [
                        _buildFilterChip(
                          context,
                          label: 'Todos',
                          selected: _mostrarTodos,
                          onSelected: (value) {
                            setState(() {
                              _mostrarTodos = value;
                              if (_mostrarTodos) {
                                _mostrarEmAberto = false;
                                _mostrarPagoTotal = false;
                                _mostrarPagoJuros = false;
                                _mostrarVencido = false;
                              }
                            });
                          },
                        ),
                        _buildFilterChip(
                          context,
                          label: 'Em Aberto',
                          selected: _mostrarEmAberto,
                          onSelected: (value) {
                            setState(() {
                              _mostrarEmAberto = value;
                              _updateTodosStatus();
                            });
                          },
                        ),
                        _buildFilterChip(
                          context,
                          label: 'Pago Total',
                          selected: _mostrarPagoTotal,
                          onSelected: (value) {
                            setState(() {
                              _mostrarPagoTotal = value;
                              _updateTodosStatus();
                            });
                          },
                        ),
                        _buildFilterChip(
                          context,
                          label: 'Pago Juros',
                          selected: _mostrarPagoJuros,
                          onSelected: (value) {
                            setState(() {
                              _mostrarPagoJuros = value;
                              _updateTodosStatus();
                            });
                          },
                        ),
                        _buildFilterChip(
                          context,
                          label: 'Vencido',
                          selected: _mostrarVencido,
                          onSelected: (value) {
                            setState(() {
                              _mostrarVencido = value;
                              _updateTodosStatus();
                            });
                          },
                        ),
                      ],
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
                          final transacoesFiltradas = _filtrarTransacoes(transacoes);

                          if (transacoes.isEmpty) {
                            return const Center(child: Text('Nenhuma transação este mês'));
                          }

                          if (transacoesFiltradas.isEmpty) {
                            return const Center(child: Text('Nenhuma transação com esses filtros'));
                          }

                          return ListView.builder(
                            itemCount: transacoesFiltradas.length,
                            itemBuilder: (context, index) {
                              final transacao = transacoesFiltradas[index];
                              return FutureBuilder(
                                future: _transacaoPaiDao.buscarPorId(transacao.idTransacaoPai),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const ListTile(
                                      title: Text('Carregando...'),
                                    );
                                  }
                                  if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                                    return ListTile(
                                      title: Text('Erro ao carregar transação pai'),
                                    );
                                  }
                                  final transacaoPai = snapshot.data!;
                                  final obrigado = _encontrarObrigado(transacaoPai.idObrigado);

                                  return _buildTransacaoCard(transacao, obrigado);
                                },
                              );
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
  void _updateTodosStatus() {
    setState(() {
      _mostrarTodos = !_mostrarEmAberto && 
                    !_mostrarPagoTotal && 
                    !_mostrarPagoJuros && 
                    !_mostrarVencido;
    });
  }

  Widget _buildFilterChip(BuildContext context, {
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.transparent,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: selected ? Theme.of(context).primaryColor : Colors.grey[700],
        fontSize: 12,
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected 
              ? Theme.of(context).primaryColor 
              : Colors.grey[300]!,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildTransacaoCard(Transacao transacao, Obrigado obrigado) {
  final hoje = DateTime.now();
  var corCard;
  
  if(transacao.dataPagamentoCompleto != null){
    corCard = Colors.green[100];
  }
  else if (transacao.dataPagamentoRetorno != null){
    corCard = Colors.blue[100];
  }
  else if (transacao.dataVencimento != null && transacao.dataVencimento!.isBefore(hoje)){
    corCard = Colors.red[100];
  }
  else{
    corCard = null;
  }
  
  return FutureBuilder<TransacaoPai?>(
    future: _transacaoPaiDao.buscarPorId(transacao.idTransacaoPai),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const CircularProgressIndicator();
      }
      
      if (!snapshot.hasData || snapshot.data == null) {
        return const Text('Transação pai não encontrada');
      }
      
      final transacaoPai = snapshot.data!;
      
      return Card( 
        margin: const EdgeInsets.all(8),
        elevation: 2,
        color: corCard,
        child: ListTile(
          title: Text(obrigado.nome),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Data: ${transacaoPai.dataEmprestimo != null ? DateFormat('dd/MM/yyyy').format(transacaoPai.dataEmprestimo!) : 'Não definida'}'),
              Text('Parcela: ${transacao.parcela} de ${transacaoPai.qtdeParcelas}'),
              Text('Valor: ${_currencyFormat.format(transacaoPai.valorEmprestado)}'),
              Text('Juros: ${transacaoPai.percentualJuros}%'),
              Text('Total: ${_currencyFormat.format(transacao.retorno)}'),
              if (transacao.dataVencimento != null)
                Text('Prazo: ${DateFormat('dd/MM/yyyy').format(transacao.dataVencimento!)}'),
              if (transacao.dataPagamentoCompleto != null)
                Text('Pago em: ${DateFormat('dd/MM/yyyy').format(transacao.dataPagamentoCompleto!)}'),
              if (transacao.dataPagamentoRetorno != null)
                Text('Juros: ${DateFormat('dd/MM/yyyy').format(transacao.dataPagamentoRetorno!)}'),
            ],
          ),
          trailing: Wrap(
            spacing: -20,
            children: [
              // Ícone "Pago Total" (só aparece se NÃO estiver pago)
              if (transacao.dataPagamentoCompleto == null && transacao.dataPagamentoRetorno == null)
                IconButton(
                  icon: const Icon(Icons.attach_money, color: Colors.green),
                  onPressed: () => _marcarComoPagoTotal(transacao),
                ),

              // Ícone "Pago Juros" (só aparece se NÃO estiver pago)
              if (transacao.dataPagamentoCompleto == null && transacao.dataPagamentoRetorno == null)
                IconButton(
                  icon: const Icon(Icons.percent, color: Colors.blue),
                  onPressed: () => _marcarComoPagoJuros(transacao),
                ),

              // Ícone "Editar" (só aparece se NÃO estiver pago)
              if (transacao.dataPagamentoCompleto == null && transacao.dataPagamentoRetorno == null)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CadastroTransacaoScreen(
                          transacao: transacao,
                          transacaoPai: transacaoPai,
                        ),
                      ),
                    ).then((_) => _carregarDados());
                  },
                ),

              // Ícone "Excluir" (só aparece se NÃO estiver pago)
              if (transacao.dataPagamentoCompleto == null && transacao.dataPagamentoRetorno == null)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
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
                      await _transacaoDao.deleteTransacao(transacao.id!);
                      await _carregarDados();
                    }
                  },
                ),

              // Ícone WhatsApp (sempre visível)
              IconButton(
                icon: const Icon(Icons.phone_android, color: Colors.green),
                onPressed: () => _enviarWhatsApp(obrigado, transacao.retorno),
              ),
            ],
          ),
        ),
      );
    },
  );
}// fim _buildTransacaoCard

  Widget _buildTotalReceber() {
    double total = 0;
    final hoje = DateTime.now();
    
     // Obtém as transações filtradas
    final transacoesFiltradas = _filtrarTransacoes(_transacoes);
  
    for (var transacao in transacoesFiltradas) {
      final pagoTotal = transacao.dataPagamentoCompleto != null;
      final pagoJuros = transacao.dataPagamentoRetorno != null;
      
      // Soma apenas as transações não pagas
      if (!pagoTotal && !pagoJuros) {
        total += transacao.retorno;
      }
    }
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
              'Total a receber:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _currencyFormat.format(total),
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
            title: const Text('Clientes'),
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
          Theme(
          data: Theme.of(context).copyWith(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
          ),
          child: ListTile(
            
            onTap: _handleSecretTap,
          ),
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
    final primeiroDiaMes = DateTime(hoje.year, hoje.month, 1);
    final ultimoDiaMes = DateTime(hoje.year, hoje.month + 1, 0);
    
    // Busca transações do mês atual
    final transacoes = await _transacaoDao.getTransacoesByPeriodo(primeiroDiaMes, ultimoDiaMes);
    
    // Filtra transações vencidas e não pagas
    final vencidas = transacoes.where((transacao) {
      return transacao.dataVencimento != null &&
            transacao.dataVencimento!.isBefore(hoje) &&
            transacao.dataPagamentoCompleto == null;
    }).toList();

    for (var transacao in vencidas) {
      final transacaoPai = await _transacaoPaiDao.buscarPorId(transacao.idTransacaoPai);
      if (transacaoPai == null) continue;
      final obrigado = _encontrarObrigado(transacaoPai.idObrigado);

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

  Future<void> checkUpdate() async {
    final response = await http.get(Uri.parse(
      'https://raw.githubusercontent.com/seu-usuario/meu-app-flutter/main/releases/v1.0.0/update.json',
    ));
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newVersion = data['version'];
      final apkUrl = data['url'];

      if (newVersion != currentVersion) {
        if (await canLaunchUrl(Uri.parse(apkUrl))) {
          await launchUrl(Uri.parse(apkUrl));
        }
      }
    }
  }

  List<Transacao> _filtrarTransacoes(List<Transacao> transacoes) {
      final hoje = DateTime.now();
      
      if (_mostrarTodos) {
        return transacoes;
      }

      return transacoes.where((transacao) {
        final vencimento = transacao.dataVencimento;
        final pagoTotal = transacao.dataPagamentoCompleto != null;
        final pagoJuros = transacao.dataPagamentoRetorno != null;
        final emAberto = !pagoTotal && !pagoJuros;
        
        bool mostra = false;
        
        if (_mostrarEmAberto) {
          mostra = mostra || (emAberto && vencimento != null && vencimento.isAfter(hoje));
        }
        
        if (_mostrarPagoTotal) {
          mostra = mostra || pagoTotal;
        }
        
        if (_mostrarPagoJuros) {
          mostra = mostra || pagoJuros;
        }
        
        if (_mostrarVencido) {
          mostra = mostra || (emAberto && vencimento != null && vencimento.isBefore(hoje));
        }
        
        return mostra;
      }).toList();
    }

    Widget _buildFilterCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: value ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Flexible(
                child: Text(label, 
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    void _showCodeInputDialog(BuildContext context) {
      final controller = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de Acesso'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Digite o código'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (controller.text == 'duolingo#@!') { // Substitua por um código mais seguro
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => const DatabaseExplorerScreen(),
                  ));
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
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