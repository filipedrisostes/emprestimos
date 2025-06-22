import 'package:emprestimos/configuracao_service.dart';
import 'package:emprestimos/currency_input_formatter.dart';
import 'package:emprestimos/models/transacao_pai.dart';
import 'package:emprestimos/services/notificacao_service.dart';
import 'package:emprestimos/services/obrigado_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/dao/transacao_pai_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/models/transacao.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CadastroTransacaoScreen extends StatefulWidget {
  final TransacaoPai? transacaoPai;

  const CadastroTransacaoScreen({super.key, this.transacaoPai, Transacao? transacao});

  @override
  _CadastroTransacaoScreenState createState() => _CadastroTransacaoScreenState();
}

class _CadastroTransacaoScreenState extends State<CadastroTransacaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _jurosController = TextEditingController();
  final _retornoController = TextEditingController();
  final _parcelasController = TextEditingController(text: '1');
  final _dbHelper = DatabaseHelper.instance;

  late TransacaoDao _transacaoDao;
  late ObrigadoDao _obrigadoDao;
  late TransacaoPaiDao _transacaoPaiDao;

  final _obrigadoService = ObrigadoService();

  DateTime? _dataVencimento;
  int _diasVencimentoPadrao = 30;

  List<Obrigado> _obrigados = [];
  Obrigado? _selectedObrigado;
  DateTime _dataEmprestimo = DateTime.now();
  bool _isEditing = false;

  final _jurosMask = MaskTextInputFormatter(
    mask: '##,##%',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _transacaoDao = TransacaoDao(_dbHelper);
    _obrigadoDao = ObrigadoDao(_dbHelper);
    _transacaoPaiDao = TransacaoPaiDao(_dbHelper);

    _carregarObrigados();
    _carregarDiasVencimentoPadrao();
    _carregarJurosPadrao();

    if (widget.transacaoPai != null) {
      _isEditing = true;
      _preencherCamposEdicao();
    } else {
      _jurosController.text = '0,00%';
    }
  }

  Future<void> _carregarDiasVencimentoPadrao() async {
    _diasVencimentoPadrao = await ConfiguracaoService.getDiasVencimentoPadrao();
    setState(() {
      _dataVencimento = _dataEmprestimo.add(Duration(days: _diasVencimentoPadrao));
    });
  }

  Future<void> _carregarObrigados() async {
    final lista = await _obrigadoDao.getAllObrigados();
    setState(() {
      _obrigados = lista;
    });

    if (_isEditing) {
      _selectedObrigado = _obrigados.firstWhere(
        (o) => o.id == widget.transacaoPai!.idObrigado,
        orElse: () => _obrigados.first,
      );
    }
  }

  void _preencherCamposEdicao() {
    final transacao = widget.transacaoPai!;
    _dataEmprestimo = transacao.dataEmprestimo;
    _dataVencimento = transacao.dataEmprestimo.add(Duration(days: _diasVencimentoPadrao));
    _valorController.text = _formatarMoeda(transacao.valorEmprestado);
    _jurosController.text = '${transacao.percentualJuros.toStringAsFixed(2).replaceAll('.', ',')}%';
    _parcelasController.text = transacao.qtdeParcelas.toString();
    _calcularRetorno();
  }

  String _formatarMoeda(double valor) {
    return NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    ).format(valor);
  }

  void _calcularRetorno() {
    try {
      final valor = _extrairValorNumerico(_valorController.text);
      double juros = _extrairValorNumerico(_jurosController.text) / 100;
      final retorno = valor * juros;
      _retornoController.text = _formatarMoeda(retorno);
    } catch (_) {
      _retornoController.text = 'R\$ 0,00';
    }
  }

  double _extrairValorNumerico(String valorFormatado) {
    return double.tryParse(
          valorFormatado
              .replaceAll('R\$', '')
              .replaceAll('%', '')
              .replaceAll('.', '')
              .replaceAll(',', '.')
              .trim(),
        ) ??
        0.0;
  }

  Future<void> _salvarNovoCliente(String nome) async {
    final novoCliente = Obrigado(nome: nome, zap: '');
    final id = await _obrigadoService.saveManualContact(novoCliente);
    final clienteComId = Obrigado(id: id, nome: nome, zap: '');
    await _carregarObrigados();
    setState(() {
      _selectedObrigado = clienteComId;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cliente "$nome" cadastrado. Clique novamente em "Salvar".')),
    );
  }

  Future<void> _salvarTransacao() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedObrigado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um cliente válido!')),
      );
      return;
    }

    double valorEmprestado = _extrairValorNumerico(_valorController.text);
    double percentualJuros = _extrairValorNumerico(_jurosController.text);
    int qtdeParcelas = int.tryParse(_parcelasController.text) ?? 1;

    int idTransacaoPai;
    List<Transacao> parcelasExistentes = [];

    if (_isEditing) {
      final transacaoPai = widget.transacaoPai!;
      transacaoPai.dataEmprestimo = _dataEmprestimo;
      transacaoPai.valorEmprestado = valorEmprestado;
      transacaoPai.percentualJuros = percentualJuros;
      transacaoPai.qtdeParcelas = qtdeParcelas;
      transacaoPai.idObrigado = _selectedObrigado!.id!;
      await _transacaoPaiDao.atualizar(transacaoPai);
      idTransacaoPai = transacaoPai.id!;
      
      // Obter parcelas existentes ordenadas por número de parcela
      parcelasExistentes = await _transacaoDao.getTransacoesByPai(idTransacaoPai);
      parcelasExistentes.sort((a, b) => a.parcela.compareTo(b.parcela));
    } else {
      final transacaoPai = TransacaoPai(
        dataEmprestimo: _dataEmprestimo,
        idObrigado: _selectedObrigado!.id!,
        valorEmprestado: valorEmprestado,
        percentualJuros: percentualJuros,
        qtdeParcelas: qtdeParcelas,
      );
      idTransacaoPai = await _transacaoPaiDao.inserir(transacaoPai);
    }

    // Processar parcelas
    for (int i = 0; i < qtdeParcelas; i++) {
      final numeroParcela = i + 1;
      final dataParcela = DateTime(
        _dataVencimento!.year,
        _dataVencimento!.month + i,
        _dataVencimento!.day,
      );

      // Verificar se já existe uma parcela com este número
      final parcelaExistente = parcelasExistentes.firstWhere(
        (p) => p.parcela == numeroParcela,
        orElse: () => Transacao(
          id: null,
          parcela: -1, // Valor inválido para indicar que não existe
          retorno: 0,
          idTransacaoPai: idTransacaoPai,
        ),
      );

      if (parcelaExistente.id == null) {
        // Criar nova parcela apenas se não existir
        final novaTransacao = Transacao(
          dataVencimento: dataParcela,
          dataPagamentoRetorno: null,
          dataPagamentoCompleto: null,
          retorno: valorEmprestado * (percentualJuros / 100),
          idTransacaoPai: idTransacaoPai,
          parcela: numeroParcela,
        );
        await _transacaoDao.insertTransacao(novaTransacao);
      } else {
        // Atualizar parcela existente se necessário
        final transacaoAtualizada = Transacao(
          id: parcelaExistente.id,
          dataVencimento: dataParcela,
          dataPagamentoRetorno: parcelaExistente.dataPagamentoRetorno,
          dataPagamentoCompleto: parcelaExistente.dataPagamentoCompleto,
          retorno: valorEmprestado * (percentualJuros / 100),
          idTransacaoPai: idTransacaoPai,
          parcela: numeroParcela,
        );
        await _transacaoDao.updateTransacao(transacaoAtualizada);
      }
    }

    // Remover parcelas extras se o número de parcelas foi reduzido
    if (parcelasExistentes.isNotEmpty) {
      for (var parcela in parcelasExistentes) {
        if (parcela.parcela > qtdeParcelas) {
          await _transacaoDao.deleteTransacao(parcela.id!);
        }
      }
    }

    final List<DateTime> datasVencimento = [];
    for (int i = 0; i < qtdeParcelas; i++) {
      datasVencimento.add(DateTime(
        _dataVencimento!.year,
        _dataVencimento!.month + i,
        _dataVencimento!.day,
      ));
    }

    // Dentro do método _salvarTransacao, substitua a chamada de agendamento por:
    await NotificationService.agendarNotificacoesVencimento(
      idTransacaoPai: idTransacaoPai,
      nomeObrigado: _selectedObrigado!.nome,
      datasVencimento: datasVencimento.where((data) => data.isAfter(DateTime.now())).toList(), // Filtra apenas datas futuras
      valor: valorEmprestado * (percentualJuros / 100),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing ? 'Transação atualizada com sucesso!' : 'Transação cadastrada com sucesso!',
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _valorController.dispose();
    _jurosController.dispose();
    _retornoController.dispose();
    _parcelasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Transação' : 'Cadastrar Transação'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildAutocompleteCliente(),
                const SizedBox(height: 20),
                _buildDatePicker('Data do Empréstimo', _dataEmprestimo, (picked) {
                  setState(() {
                    _dataEmprestimo = picked;
                  });
                }),
                const SizedBox(height: 16),
                _buildDatePicker('Data de Vencimento', _dataVencimento ?? _dataEmprestimo, (picked) {
                  setState(() {
                    _dataVencimento = picked;
                  });
                }),
                const SizedBox(height: 20),
                _buildValorEmprestado(),
                const SizedBox(height: 20),
                _buildParcelas(),
                const SizedBox(height: 20),
                _buildJuros(),
                const SizedBox(height: 20),
                _buildRetorno(),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _salvarTransacao,
                    child: Text(_isEditing ? 'Atualizar Transação' : 'Salvar Transação'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteCliente() {
    return Autocomplete<Obrigado>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _obrigados;
        }
        return _obrigados.where((obrigado) =>
            obrigado.nome.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
            obrigado.zap.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      displayStringForOption: (Obrigado option) => '${option.nome} (${option.zap})',
      onSelected: (Obrigado selection) {
        setState(() {
          _selectedObrigado = selection;
        });
      },
      fieldViewBuilder: (context, fieldTextEditingController, fieldFocusNode, onFieldSubmitted) {
        return TextFormField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          decoration: const InputDecoration(
            labelText: 'Cliente',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.search),
          ),
          validator: (value) {
            if (_selectedObrigado == null) {
              if (value == null || value.trim().isEmpty) {
                return 'Selecione ou cadastre um cliente';
              }
              _salvarNovoCliente(value.trim());
              return 'Cliente criado. Clique em "Salvar" novamente.';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onDatePicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          locale: const Locale('pt', 'BR'),
        );
        if (picked != null) {
          onDatePicked(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('dd/MM/yyyy').format(date)),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Widget _buildValorEmprestado() {
    return TextFormField(
      controller: _valorController,
      decoration: const InputDecoration(
        labelText: 'Valor Emprestado',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [CurrencyInputFormatter()],
      onChanged: (_) => _calcularRetorno(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Informe o valor';
        }
        final valor = _extrairValorNumerico(value);
        if (valor <= 0) {
          return 'Valor deve ser maior que zero';
        }
        return null;
      },
    );
  }

  Widget _buildParcelas() {
    return TextFormField(
      controller: _parcelasController,
      decoration: const InputDecoration(
        labelText: 'Quantidade de Parcelas',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Informe a quantidade de parcelas';
        }
        final parcelas = int.tryParse(value);
        if (parcelas == null || parcelas <= 0) {
          return 'Quantidade de parcelas deve ser maior que zero';
        }
        return null;
      },
    );
  }

  Widget _buildJuros() {
    return TextFormField(
      controller: _jurosController,
      decoration: const InputDecoration(
        labelText: 'Percentual de Juros',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [_jurosMask],
      onChanged: (_) => _calcularRetorno(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Informe o percentual';
        }
        final juros = _extrairValorNumerico(value);
        if (juros < 0) {
          return 'Juros deve ser maior ou igual a zero';
        }
        return null;
      },
    );
  }

  Widget _buildRetorno() {
    return TextFormField(
      controller: _retornoController,
      decoration: const InputDecoration(
        labelText: 'Valor de Retorno Mensal',
        border: OutlineInputBorder(),
        filled: true,
        enabled: false,
      ),
    );
  }

  Future<void> _carregarJurosPadrao() async {
    final jurosPadrao = await ConfiguracaoService.getJurosPadrao();
    _jurosController.text = '${jurosPadrao.toStringAsFixed(2).replaceAll('.', ',')}%';
    _calcularRetorno();
  }
}
