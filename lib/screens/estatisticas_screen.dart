import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/dao/transacao_pai_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/transacao.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/models/transacao_pai.dart';

class EstatisticasScreen extends StatefulWidget {
  const EstatisticasScreen({super.key});

  @override
  _EstatisticasScreenState createState() => _EstatisticasScreenState();
}

class _EstatisticasScreenState extends State<EstatisticasScreen> {
  final TransacaoDao _transacaoDao = TransacaoDao(DatabaseHelper.instance);
  final ObrigadoDao _obrigadoDao = ObrigadoDao(DatabaseHelper.instance);
  final TransacaoPaiDao _transacaoPaiDao = TransacaoPaiDao(DatabaseHelper.instance);
  
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  DateTime? _dataInicial;
  DateTime? _dataFinal;
  List<Transacao> _transacoes = [];
  List<TransacaoPai> _transacoesPai = [];
  List<Obrigado> _obrigados = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    
    try {
      final transacoes = await _transacaoDao.getAllTransacoes();
      final obrigados = await _obrigadoDao.getAllObrigados();
      final transacoesPai = await Future.wait(
        transacoes.map((t) => _transacaoPaiDao.buscarPorId(t.idTransacaoPai))
      );
      
      setState(() {
        _transacoes = transacoes;
        _obrigados = obrigados;
        _transacoesPai = transacoesPai.whereType<TransacaoPai>().toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: ${e.toString()}')),
      );
    }
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

  Map<int, TransacaoPai> get _transacoesPaiMap {
    return {for (var tp in _transacoesPai) tp.id!: tp};
  }

  List<Transacao> get _transacoesFiltradas {
    return _transacoes.where((transacao) {
      final transacaoPai = _transacoesPaiMap[transacao.idTransacaoPai];
      if (transacaoPai == null) return false;
      
      final dentroPeriodoInicial = _dataInicial == null || 
          transacaoPai.dataEmprestimo.isAfter(_dataInicial!.subtract(const Duration(days: 1)));
      final dentroPeriodoFinal = _dataFinal == null || 
          transacaoPai.dataEmprestimo.isBefore(_dataFinal!.add(const Duration(days: 1)));
      return dentroPeriodoInicial && dentroPeriodoFinal;
    }).toList()
      ..sort((a, b) => a.idTransacaoPai.compareTo(b.idTransacaoPai)); // Ordena por id_transacao_pai
  }

  List<Map<String, dynamic>> get _maioresDevedores {
    final Map<int, double> devedores = {};
    
    for (final transacao in _transacoesFiltradas) {
      final transacaoPai = _transacoesPaiMap[transacao.idTransacaoPai];
      if (transacaoPai == null) continue;
      
      if (transacao.dataPagamentoCompleto == null) {
        final valorDevido = transacao.retorno;
        devedores[transacaoPai.idObrigado] = 
            (devedores[transacaoPai.idObrigado] ?? 0) + valorDevido;
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

  List<Map<String, dynamic>> get _clientesFieis {
    final Map<int, int> contagem = {};
    
    for (final transacao in _transacoesFiltradas) {
      final transacaoPai = _transacoesPaiMap[transacao.idTransacaoPai];
      if (transacaoPai == null) continue;
      
      contagem[transacaoPai.idObrigado] = 
          (contagem[transacaoPai.idObrigado] ?? 0) + 1;
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

  Map<String, double> get _dadosGraficoBarras {
    double totalEmprestado = 0;
    double jurosAReceber = 0;
    double jurosPago = 0;
    double totalQuitado = 0;
    
    // Mapa para evitar duplicar cálculos de transações pai
    final Map<int, TransacaoPai> transacoesPaiMap = _transacoesPaiMap;
    String idTransacaoPaiAux = '';
    for (final transacao in _transacoesFiltradas) {
      final transacaoPai = transacoesPaiMap[transacao.idTransacaoPai];
      if (transacaoPai == null) continue;

      // 1. Total Emprestado (soma do valor original)
      totalEmprestado += transacaoPai.valorEmprestado;

      // 2. Juros a Receber (parcelas não pagas)
      if (transacao.dataPagamentoRetorno == null && 
          transacao.dataPagamentoCompleto == null) {
        jurosAReceber += transacao.retorno;
      }

      // 3. Juros Pago (apenas juros pagos)
      if (transacao.dataPagamentoRetorno != null && 
          transacao.dataPagamentoCompleto == null) {
        jurosPago += transacao.retorno;
      }

      // 4. Total Quitado (parcelas quitadas completamente)
      if (transacao.dataPagamentoCompleto != null) {
        if (idTransacaoPaiAux != transacao.idTransacaoPai.toString()) {
          idTransacaoPaiAux = transacao.idTransacaoPai.toString();
          totalQuitado += transacao.retorno + transacaoPai.valorEmprestado;
        }
      }
    }

    // 5. Lucro = (Juros Pago + Total Quitado) - Total Emprestado
    double lucro = (jurosPago + totalQuitado) - totalEmprestado;

    return {
      'Total Emprestado': totalEmprestado,
      'Juros a Receber': jurosAReceber,
      'Juros Pago': jurosPago,
      'Total Quitado': totalQuitado,
      'Lucro': lucro , // Exibe apenas lucro positivo
    };
  }

  List<Map<String, dynamic>> get _previsaoJurosReceber {
  final Map<String, double> jurosPorMes = {};
  
  for (final transacao in _transacoesFiltradas) {
    if (transacao.dataPagamentoCompleto == null && 
        transacao.dataPagamentoRetorno == null &&
        transacao.dataVencimento != null) {
      
      final mesAno = DateFormat('yyyy-MM').format(transacao.dataVencimento!); // Formato ISO para ordenação
      final mesAnoFormatado = DateFormat('MM/yyyy').format(transacao.dataVencimento!); // Formato de exibição
      jurosPorMes[mesAno] = (jurosPorMes[mesAno] ?? 0) + transacao.retorno;
    }
  }
  
  return jurosPorMes.entries.map((entry) {
    final date = DateTime.parse('${entry.key}-01');
    final mesFormatado = DateFormat('MM/yyyy').format(date);
    return {
      'mes': mesFormatado,
      'juros': entry.value,
      'date': date, // Para ordenação
    };
  }).toList()
    ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
}

  List<Map<String, dynamic>> get _historicoJurosPagos {
    final Map<String, double> jurosPorMes = {};
    
    for (final transacao in _transacoesFiltradas) {
      // Considera apenas transações com juros pagos (data_pagamento_retorno != null)
      if (transacao.dataPagamentoRetorno != null) {
        final mesAno = DateFormat('MM/yyyy').format(transacao.dataPagamentoRetorno!);
        jurosPorMes[mesAno] = (jurosPorMes[mesAno] ?? 0) + transacao.retorno;
      }
    }
    
    return jurosPorMes.entries.map((entry) {
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                              primaryXAxis: CategoryAxis(
                                labelStyle: const TextStyle(fontSize: 10),
                                labelRotation: -45, // Rotaciona labels para melhor legibilidade
                              ),
                              primaryYAxis: NumericAxis(
                                isVisible: false,
                                numberFormat: NumberFormat.compactCurrency(symbol: 'R\$'),
                              ),
                              tooltipBehavior: TooltipBehavior(
                                enable: true,
                                format: 'point.x : R\$point.y',
                              ),
                              series: <CartesianSeries>[
                                ColumnSeries<MapEntry<String, double>, String>(
                                  dataSource: _dadosGraficoBarras.entries.toList(),
                                  xValueMapper: (entry, _) => entry.key,
                                  yValueMapper: (entry, _) => entry.value,
                                  color: Colors.blue,
                                  dataLabelSettings: DataLabelSettings(
                                    isVisible: true,
                                    labelAlignment: ChartDataLabelAlignment.top,
                                    textStyle: const TextStyle(color: Colors.black, fontSize: 10),
                                  ),
                                  // Cores personalizadas para cada barra
                                  pointColorMapper: (entry, _) {
                                    switch (entry.key) {
                                      case 'Total Emprestado':
                                        return Colors.blue[800];
                                      case 'Juros a Receber':
                                        return Colors.orange;
                                      case 'Juros Pago':
                                        return Colors.green[600];
                                      case 'Total Quitado':
                                        return Colors.purple;
                                      case 'Lucro':
                                        return Colors.teal;
                                      default:
                                        return Colors.blue;
                                    }
                                  },
                                )
                              ],
                            ),
                          ),
                          // Legenda explicativa
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Wrap(
                              spacing: 10,
                              children: _dadosGraficoBarras.entries.map((entry) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      color: entry.key == 'Total Emprestado' ? Colors.blue[800] :
                                            entry.key == 'Juros a Receber' ? Colors.orange :
                                            entry.key == 'Juros Pago' ? Colors.green[600] :
                                            entry.key == 'Total Quitado' ? Colors.purple :
                                            Colors.teal,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      entry.key,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // 4. Gráfico de linha (previsão de Juros a Receber)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Previsão de Juros a Receber',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 300,
                            child: SfCartesianChart(
                              primaryXAxis: CategoryAxis(
                                labelRotation: -45,
                                labelStyle: const TextStyle(fontSize: 10),
                              ),
                              primaryYAxis: NumericAxis(
                                isVisible: false,
                                numberFormat: NumberFormat.currency(
                                  locale: 'pt_BR', 
                                  symbol: 'R\$',
                                  decimalDigits: 2,
                                ),
                                minimum: 0, // Garante que não mostra valores negativos
                              ),
                              series: <CartesianSeries>[
                                LineSeries<Map<String, dynamic>, String>(
                                  dataSource: _previsaoJurosReceber,
                                  xValueMapper: (data, _) => data['mes'],
                                  yValueMapper: (data, _) => data['juros'],
                                  markerSettings: const MarkerSettings(isVisible: true),
                                  dataLabelSettings: DataLabelSettings(
                                    isVisible: true,
                                    labelAlignment: ChartDataLabelAlignment.top,
                                    textStyle: const TextStyle(fontSize: 10),
                                  ),
                                  color: Colors.green,
                                )
                              ],
                              tooltipBehavior: TooltipBehavior(
                                enable: true,
                                format: 'point.x : R\$point.y',
                              ),
                            ),
                          ),
                          // Total acumulado
                          if (_previsaoJurosReceber.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Total previsto: ${_currencyFormat.format(
                                  _previsaoJurosReceber.fold(0.0, (sum, item) => sum + item['juros'])
                                )}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 5. Gráfico de linha (histórico de Juros Pagos)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Histórico de Juros Pagos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 300,
                            child: SfCartesianChart(
                              primaryXAxis: CategoryAxis(
                                labelRotation: -45,
                                labelStyle: const TextStyle(fontSize: 10),
                              ),
                              primaryYAxis: NumericAxis(
                                isVisible: false,
                                numberFormat: NumberFormat.currency(
                                  locale: 'pt_BR', 
                                  symbol: 'R\$',
                                  decimalDigits: 2,
                                ),
                                minimum: 0, // Garante que não mostra valores negativos
                              ),
                              series: <CartesianSeries>[
                                LineSeries<Map<String, dynamic>, String>(
                                  dataSource: _historicoJurosPagos,
                                  xValueMapper: (data, _) => data['mes'],
                                  yValueMapper: (data, _) => data['juros'],
                                  markerSettings: const MarkerSettings(isVisible: true),
                                  dataLabelSettings: DataLabelSettings(
                                    isVisible: true,
                                    labelAlignment: ChartDataLabelAlignment.top,
                                    textStyle: const TextStyle(fontSize: 10),
                                  ),
                                  color: Colors.blue,
                                )
                              ],
                              tooltipBehavior: TooltipBehavior(
                                enable: true,
                                format: 'point.x : R\$point.y',
                              ),
                            ),
                          ),
                          // Total acumulado
                          if (_historicoJurosPagos.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Total recebido: ${_currencyFormat.format(
                                  _historicoJurosPagos.fold(0.0, (sum, item) => sum + item['juros'])
                                )}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
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