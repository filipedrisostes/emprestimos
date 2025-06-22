import 'package:emprestimos/models/emprestimo_detalhado.dart';
import 'package:flutter/material.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/dao/transacao_pai_dao.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:intl/intl.dart';

class DetalhesObrigadoScreen extends StatefulWidget {
  final Obrigado obrigado;

  const DetalhesObrigadoScreen({super.key, required this.obrigado});

  @override
  State<DetalhesObrigadoScreen> createState() => _DetalhesObrigadoScreenState();
}

class _DetalhesObrigadoScreenState extends State<DetalhesObrigadoScreen> {
  final TransacaoPaiDao _transacaoPaiDao = TransacaoPaiDao(DatabaseHelper.instance);
  final TransacaoDao _transacaoDao = TransacaoDao(DatabaseHelper.instance);
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  int _totalEmprestimos = 0;
  int _emprestimosPagos = 0;
  double _totalEmprestado = 0;
  double _totalJurosPagos = 0;
  double _totalPagoIntegralmente = 0;
  double _totalAPagar = 0;
  bool _isLoading = true;

  List<EmprestimoDetalhado> _emprestimosDetalhados = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    
    try {
      final emprestimos = await _transacaoPaiDao.listarTodos();
      final emprestimosObrigado = emprestimos.where((e) => e.idObrigado == widget.obrigado.id).toList();
      
      _emprestimosDetalhados = await Future.wait(
        emprestimosObrigado.map((emprestimo) async {
          final parcelas = await _transacaoDao.getTransacoesByPai(emprestimo.id!);
          final estaPago = parcelas.every((p) => 
            p.dataPagamentoCompleto != null || p.dataPagamentoRetorno != null);
          
          return EmprestimoDetalhado(
            emprestimo: emprestimo,
            parcelas: parcelas,
            estaPago: estaPago,
          );
        }),
      );

      _totalEmprestimos = emprestimosObrigado.length;
      _emprestimosPagos = 0;
      
      for (var emprestimo in emprestimosObrigado) {
        final parcelas = await _transacaoDao.getTransacoesByPai(emprestimo.id!);
        if (parcelas.every((p) => p.dataPagamentoCompleto != null || p.dataPagamentoRetorno != null)) {
          _emprestimosPagos++;
        }
      }

      _totalEmprestado = emprestimosObrigado.fold(0, (sum, e) => sum + e.valorEmprestado);

      final todasTransacoes = await _transacaoDao.getAllTransacoes();
      _totalJurosPagos = todasTransacoes
        .where((t) => 
          t.idTransacaoPai != null &&
          emprestimosObrigado.any((e) => e.id == t.idTransacaoPai) &&
          t.dataPagamentoRetorno != null)
        .fold(0, (sum, t) => sum + t.retorno);

      _totalPagoIntegralmente = 0;
      for (var emprestimo in emprestimosObrigado) {
        final parcelas = await _transacaoDao.getTransacoesByPai(emprestimo.id!);
        if (parcelas.every((p) => p.dataPagamentoCompleto != null)) {
          _totalPagoIntegralmente += emprestimo.valorEmprestado * (1 + emprestimo.percentualJuros/100);
        }
      }

      _totalAPagar = todasTransacoes
        .where((t) => 
          t.idTransacaoPai != null &&
          emprestimosObrigado.any((e) => e.id == t.idTransacaoPai) &&
          t.dataPagamentoCompleto == null &&
          t.dataPagamentoRetorno == null)
        .fold(0, (sum, t) => sum + t.retorno);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: ${e.toString()}')),
      );
    }
  }

  Widget _buildInfoCard(String titulo, String valor) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              valor,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideInfoCard(String titulo, String valor) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.obrigado.nome),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Seção de estatísticas (30% da tela)
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                'Total de Empréstimos',
                                _totalEmprestimos.toString(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInfoCard(
                                'Empréstimos Pagos',
                                '$_emprestimosPagos/$_totalEmprestimos',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildWideInfoCard(
                          'Total Emprestado',
                          _currencyFormat.format(_totalEmprestado),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                'Juros Pagos',
                                _currencyFormat.format(_totalJurosPagos),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInfoCard(
                                'Pago Integralmente',
                                _currencyFormat.format(_totalPagoIntegralmente),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildWideInfoCard(
                          'Total a Pagar',
                          _currencyFormat.format(_totalAPagar),
                        ),
                      ],
                    ),
                  ),
                ),
                
                Container(
                  height: 1,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(vertical: 8),
                ),
                
                // Seção de detalhes dos empréstimos (70% da tela)
                Expanded(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Detalhes dos Empréstimos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _emprestimosDetalhados.length,
                          itemBuilder: (context, index) {
                            final emprestimo = _emprestimosDetalhados[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: ExpansionTile(
                                title: Text(
                                  'Empréstimo ${index + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Valor: ${_currencyFormat.format(emprestimo.emprestimo.valorEmprestado)}',
                                ),
                                trailing: Chip(
                                  label: Text(
                                    emprestimo.estaPago ? 'Pago' : 'Pendente',
                                    style: TextStyle(
                                      color: emprestimo.estaPago 
                                        ? Colors.green 
                                        : Colors.red,
                                    ),
                                  ),
                                  backgroundColor: emprestimo.estaPago 
                                    ? Colors.green[50] 
                                    : Colors.red[50],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        _buildDetailRow('Data:', DateFormat('dd/MM/yyyy').format(emprestimo.emprestimo.dataEmprestimo!)),
                                        _buildDetailRow('Valor:', _currencyFormat.format(emprestimo.emprestimo.valorEmprestado)),
                                        _buildDetailRow('Juros:', '${emprestimo.emprestimo.percentualJuros}%'),
                                        _buildDetailRow('Status:', emprestimo.estaPago ? 'Pago' : 'Pendente'),
                                        const Divider(),
                                        const Text(
                                          'Parcelas',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        ...emprestimo.parcelas.map((parcela) {
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text('Parcela ${parcela.parcela}'),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Vencimento: ${DateFormat('dd/MM/yyyy').format(parcela.dataVencimento!)}'),
                                                Text('Valor: ${_currencyFormat.format(parcela.retorno)}'),
                                                if (parcela.dataPagamentoCompleto != null)
                                                  Text('Pago em: ${DateFormat('dd/MM/yyyy').format(parcela.dataPagamentoCompleto!)}'),
                                                if (parcela.dataPagamentoRetorno != null)
                                                  Text('Juros pagos em: ${DateFormat('dd/MM/yyyy').format(parcela.dataPagamentoRetorno!)}'),
                                              ],
                                            ),
                                            trailing: parcela.dataPagamentoCompleto != null
                                                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                                : parcela.dataPagamentoRetorno != null
                                                    ? const Icon(Icons.percent, color: Colors.blue, size: 20)
                                                    : const Icon(Icons.pending, color: Colors.orange, size: 20),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}