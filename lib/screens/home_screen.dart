import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/screens/cadastro_obrigado_screen.dart';
import 'package:emprestimos/screens/lista_obrigados_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/models/transacao.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/screens/cadastro_transacao_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TransacaoDao _transacaoDao = TransacaoDao(DatabaseHelper.instance);
  final ObrigadoDao _obrigadoDao = ObrigadoDao(DatabaseHelper.instance);
  List<Transacao> _transacoes = [];
  DateTime _currentMonth = DateTime.now();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _carregarTransacoes();
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
      _carregarTransacoes();
    });
  }

  void _mesAnterior() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _carregarTransacoes();
    });
  }

  Future<void> _enviarWhatsApp(Obrigado obrigado, double valor) async {
    // Remove caracteres não numéricos do telefone
    final numeroLimpo = obrigado.zap.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Formata a mensagem
    final mensagem = Uri.encodeFull(
      'Olá ${obrigado.nome}, tudo bem? Lembrando que o valor de ${_currencyFormat.format(valor)} vence este mês.'
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
        String androidUrl = "whatsapp://send?phone=$numeroLimpo&text=$mensagem";
        String iosUrl = "https://wa.me/$numeroLimpo?text=${Uri.parse(mensagem)}";
        await launchUrl(
          Uri.parse(androidUrl),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciador de Empréstimos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CadastroTransacaoScreen(),
                ),
              ).then((_) => _carregarTransacoes());
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text('Menu', 
                style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Obrigados'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ListaObrigadosScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Cadastrar Obrigado'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CadastroObrigadoScreen(),
                  ),
                );
              },
            ),
            // Adicione outros itens de menu aqui conforme necessário
          ],
        ),
      ),
      body: Column(
        children: [
          // Controles de navegação por mês
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
                  DateFormat('MMMM/yyyy').format(_currentMonth),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios),
                  onPressed: _proximoMes,
                ),
              ],
            ),
          ),
          // Lista de transações
          Expanded(
            child: _transacoes.isEmpty
                ? const Center(child: Text('Nenhuma transação este mês'))
                : ListView.builder(
                    itemCount: _transacoes.length,
                    itemBuilder: (context, index) {
                      final transacao = _transacoes[index];
                      return FutureBuilder<Obrigado?>(
                        future: _obrigadoDao.getObrigadoById(transacao.idObrigado),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('Carregando...'),
                            );
                          }
                          
                          final obrigado = snapshot.data;
                          if (obrigado == null) {
                            return const ListTile(
                              title: Text('Obrigado não encontrado'),
                            );
                          }
                          
                          final valorMensal = transacao.retorno; // Exemplo: dividindo por 12 meses
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              title: Text(obrigado.nome),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Emprestado: ${_currencyFormat.format(transacao.valorEmprestado)}'),
                                  Text('A receber este mês: ${_currencyFormat.format(valorMensal)}'),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.phone_android, color: Colors.green),
                                onPressed: () => _enviarWhatsApp(obrigado, valorMensal),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}