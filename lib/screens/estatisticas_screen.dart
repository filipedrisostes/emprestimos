import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/transacao.dart';
import 'package:emprestimos/models/obrigado.dart';

class EstatisticasScreen extends StatefulWidget {
  const EstatisticasScreen({super.key});

  @override
  _EstatisticasScreenState createState() => _EstatisticasScreenState();
}

class _EstatisticasScreenState extends State<EstatisticasScreen> {
  final TransacaoDao _transacaoDao = TransacaoDao(DatabaseHelper.instance);
  final ObrigadoDao _obrigadoDao = ObrigadoDao(DatabaseHelper.instance);
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  DateTime? _dataInicial;
  DateTime? _dataFinal;
  List<Transacao> _transacoes = [];
  List<Obrigado> _obrigados = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final transacoes = await _transacaoDao.getAllTransacoes();
    final obrigados = await _obrigadoDao.getAllObrigados();
    
    setState(() {
      _transacoes = transacoes;
      _obrigados = obrigados;
    });
  }

  Future<void> _selecionarData(BuildContext context, bool isInicial) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isInicial ? _dataInicial ?? DateTime.now() : _dataFinal ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    
    if (picked != null) {
      setState(() {
        if (isInicial) {
          _dataInicial = picked;
        } else {
          _dataFinal = picked;
        }
      });
    }
  }

  List<Transacao> get _transacoesFiltradas {
    return _transacoes.where((transacao) {
      final dataTransacao = transacao.dataEmprestimo;
      final dentroPeriodoInicial = _dataInicial == null || 
          dataTransacao.isAfter(_dataInicial!.subtract(const Duration(days: 1)));
      final dentroPeriodoFinal = _dataFinal == null || 
          dataTransacao.isBefore(_dataFinal!.add(const Duration(days: 1)));
      return dentroPeriodoInicial && dentroPeriodoFinal;
    }).toList();
  }

  // 1. Maiores devedores
  List<Map<String, dynamic>> get _maioresDevedores {
    final Map<int, double> devedores = {};
    
    for (final transacao in _transacoesFiltradas) {
      if (transacao.dataPagamentoCompleto == null) {
        final valorDevido = transacao.retorno;
        devedores[transacao.idObrigado] = 
            (devedores[transacao.idObrigado] ?? 0) + valorDevido;
      }
    }
    
    return devedores.entries.map((entry) {
      final obrigado = _obrigados.firstWhere(
        (o) => o.id == entry.key,
        orElse: () => Obrigado(id: -1, nome: 'Desconhecido', zap: ''),
      );
      
      return {
        'obrigado': obrigado,
        'valorDevido': entry.value,
      };
    }).toList()
      ..sort((a, b) => (b['valorDevido'] as num).compareTo(a['valorDevido'] as num));
  }

  // 2. Clientes fiéis (que mais pediram empréstimos)
  List<Map<String, dynamic>> get _clientesFieis {
    final Map<int, int> contagem = {};
    
    for (final transacao in _transacoesFiltradas) {
      contagem[transacao.idObrigado] = 
          (contagem[transacao.idObrigado] ?? 0) + 1;
    }
    
    return contagem.entries.map((entry) {
      final obrigado = _obrigados.firstWhere(
        (o) => o.id == entry.key,
        orElse: () => Obrigado(id: -1, nome: 'Desconhecido', zap: ''),
      );
      
      return {
        'obrigado': obrigado,
        'quantidade': entry.value,
      };
    }).toList()
      ..sort((a, b) => (b['quantidade'] as num).compareTo(a['quantidade'] as num));
  }

  // 3. Dados para gráfico de barras
  Map<String, double> get _dadosGraficoBarras {
    double totalEmprestado = 0;
    double totalJurosReceber = 0;
    double totalJurosPago = 0;
    double totalQuitado = 0;
    
    for (final transacao in _transacoesFiltradas) {
      totalEmprestado += transacao.valorEmprestado;
      
      if (transacao.dataPagamentoCompleto != null) {
        totalQuitado += transacao.retorno;
        totalJurosPago += transacao.retorno - transacao.valorEmprestado;
      } else if (transacao.dataPagamentoRetorno != null) {
        totalJurosPago += transacao.retorno - transacao.valorEmprestado;
      } else {
        totalJurosReceber += transacao.retorno - transacao.valorEmprestado;
      }
    }
    
    return {
      'Total Emprestado': totalEmprestado,
      'Juros a Receber': totalJurosReceber,
      'Juros Pago': totalJurosPago,
      'Total Quitado': totalQuitado,
      'Lucro': (totalQuitado + totalJurosPago) - totalEmprestado,
    };
  }

  // 4. Dados para gráfico de previsão de arrecadação
  List<Map<String, dynamic>> get _previsaoArrecadacao {
    final Map<String, double> arrecadacaoPorMes = {};
    
    for (final transacao in _transacoesFiltradas) {
      if (transacao.dataPagamentoCompleto == null && 
          transacao.dataPagamentoRetorno == null) {
        final mesAno = DateFormat('MM/yyyy').format(transacao.dataEmprestimo);
        final juros = transacao.retorno - transacao.valorEmprestado;
        
        arrecadacaoPorMes[mesAno] = 
            (arrecadacaoPorMes[mesAno] ?? 0) + juros;
      }
    }
    
    return arrecadacaoPorMes.entries.map((entry) {
      return {
        'mes': entry.key,
        'juros': entry.value,
      };
    }).toList()
      ..sort((a, b) => (a['mes'] as String).compareTo(b['mes'] as String));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estatísticas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Filtro de período
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selecionarData(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data Inicial',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _dataInicial != null 
                            ? DateFormat('dd/MM/yyyy').format(_dataInicial!)
                            : 'Selecionar',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _selecionarData(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data Final',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _dataFinal != null 
                            ? DateFormat('dd/MM/yyyy').format(_dataFinal!)
                            : 'Selecionar',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 1. Maiores devedores
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Maiores Devedores',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_maioresDevedores.isEmpty)
                      const Text('Nenhum devedor no período')
                    else
                      Column(
                        children: _maioresDevedores.take(5).map((devedor) {
                          return ListTile(
                            title: Text(devedor['obrigado'].nome),
                            trailing: Text(
                              _currencyFormat.format(devedor['valorDevido']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 2. Clientes fiéis
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clientes Fiéis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_clientesFieis.isEmpty)
                      const Text('Nenhum cliente no período')
                    else
                      Column(
                        children: _clientesFieis.take(5).map((cliente) {
                          return ListTile(
                            title: Text(cliente['obrigado'].nome),
                            trailing: Text(
                              '${cliente['quantidade']} empréstimos',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 3. Gráfico de barras
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumo Financeiro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 300,
                      child: SfCartesianChart(
                        primaryXAxis: const CategoryAxis(),
                        series: <CartesianSeries>[
                          ColumnSeries<MapEntry<String, double>, String>(
                            dataSource: _dadosGraficoBarras.entries.toList(),
                            xValueMapper: (entry, _) => entry.key,
                            yValueMapper: (entry, _) => entry.value,
                            dataLabelSettings: const DataLabelSettings(
                              isVisible: true,
                              labelAlignment: ChartDataLabelAlignment.top,
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 4. Gráfico de linha (previsão de arrecadação)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Previsão de Arrecadação',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 300,
                      child: SfCartesianChart(
                        primaryXAxis: const CategoryAxis(),
                        series: <CartesianSeries>[
                          LineSeries<Map<String, dynamic>, String>(
                            dataSource: _previsaoArrecadacao,
                            xValueMapper: (data, _) => data['mes'],
                            yValueMapper: (data, _) => data['juros'],
                            dataLabelSettings: const DataLabelSettings(
                              isVisible: true,
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}