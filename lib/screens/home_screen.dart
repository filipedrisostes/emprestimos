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
      final transacaoDao = TransacaoDao(DatabaseHelper.instance);

      // 1. Marca a parcela atual como paga
      if (transacao.id != null) {
        await transacaoDao.updateDataPagamentoCompleto(transacao.id!, agora);
      }

      // 2. Marca TODAS as parcelas futuras como pagas
      final parcelasAtualizadas = await transacaoDao.updateParcelasFuturasComoPagas(
        transacao.idTransacaoPai,
        agora,
      );

      // 3. Feedback para o usuário
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$parcelasAtualizadas parcelas marcadas como pagas!'),
          duration: const Duration(seconds: 2),
        ),
      );

      // 4. Atualiza a lista
      await _carregarDados();

      // 5. Cancela notificações
      await NotificationService.cancelarNotificacoes(transacao.idTransacaoPai);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _marcarComoPagoJuros(Transacao transacao) async {
    try {
      if (transacao.id != null) {
        // Busca transação pai
        final transacaoPai = await _transacaoPaiDao.buscarPorId(transacao.idTransacaoPai);
        
        if (transacaoPai == null) {
          throw Exception('Transação pai não encontrada');
        }

        // Verifica se é a última parcela
        final todasParcelas = await _transacaoDao.getTransacoesByPai(transacao.idTransacaoPai);
        final ultimaParcela = todasParcelas.fold(0, (max, t) => t.parcela > max ? t.parcela : max);

        await _transacaoDao.updateDataPagamentoRetorno(transacao.id!, DateTime.now());
        
        if (transacao.parcela >= ultimaParcela) {
          // Cria nova transação apenas se não for a última parcela
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
            parcela: transacao.parcela + 1,
          );
          
          await _transacaoDao.insertTransacao(novaTransacao);
        }

        await _carregarDados();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Juros pagos com sucesso!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${e.toString()}')),
      );
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
                    Row(
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
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFilterCheckbox('Todos', _mostrarTodos, (value) {
                            setState(() {
                              _mostrarTodos = value ?? false;
                              // Quando "Todos" é marcado, desmarca os outros
                              if (_mostrarTodos) {
                                _mostrarEmAberto = false;
                                _mostrarPagoTotal = false;
                                _mostrarPagoJuros = false;
                                _mostrarVencido = false;
                              }
                            });
                          }),
                          _buildFilterCheckbox('Em Aberto', _mostrarEmAberto, (value) {
                            setState(() {
                              _mostrarEmAberto = value ?? false;
                              // Se nenhum filtro específico está marcado, ativa "Todos"
                              if (!_mostrarEmAberto && 
                                  !_mostrarPagoTotal && 
                                  !_mostrarPagoJuros && 
                                  !_mostrarVencido) {
                                _mostrarTodos = true;
                              } else {
                                _mostrarTodos = false;
                              }
                            });
                          }),
                          _buildFilterCheckbox('Pago Total', _mostrarPagoTotal, (value) {
                            setState(() {
                              _mostrarPagoTotal = value!;
                              _mostrarTodos = !value && 
                                !_mostrarEmAberto && 
                                !_mostrarPagoJuros && 
                                !_mostrarVencido;
                            });
                          }),
                          _buildFilterCheckbox('Pago Juros', _mostrarPagoJuros, (value) {
                            setState(() {
                              _mostrarPagoJuros = value!;
                              _mostrarTodos = !value && 
                                !_mostrarEmAberto && 
                                !_mostrarPagoTotal && 
                                !_mostrarVencido;
                            });
                          }),
                          _buildFilterCheckbox('Vencido', _mostrarVencido, (value) {
                            setState(() {
                              _mostrarVencido = value!;
                              _mostrarTodos = !value && 
                                !_mostrarEmAberto && 
                                !_mostrarPagoTotal && 
                                !_mostrarPagoJuros;
                            });
                          }),
                        ],
                      ),
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
                      builder: (context) => CadastroTransacaoScreen(
                        transacao: transacao,
                        transacaoPai: transacaoPai,
                      ),
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
                    if (transacao.id != null) {
                      await _transacaoDao.deleteTransacao(transacao.id!);
                    } else {
                      throw Exception('Transação ID não pode ser nulo');
                    }
                    await _carregarDados();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.phone_android, color: Colors.green),
                onPressed: () => _enviarWhatsApp(obrigado, transacaoPai.valorEmprestado),
              )
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
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