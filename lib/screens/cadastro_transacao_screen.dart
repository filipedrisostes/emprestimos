import 'package:emprestimos/configuracao_service.dart';
import 'package:emprestimos/currency_input_formatter.dart';
import 'package:emprestimos/services/notificacao_service.dart';
import 'package:emprestimos/services/obrigado_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/models/obrigado.dart';
import 'package:emprestimos/models/transacao.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CadastroTransacaoScreen extends StatefulWidget {
  final Transacao? transacao;

  const CadastroTransacaoScreen({super.key, this.transacao});

  @override
  _CadastroTransacaoScreenState createState() => _CadastroTransacaoScreenState();
}

class _CadastroTransacaoScreenState extends State<CadastroTransacaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _jurosController = TextEditingController();
  final _retornoController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;
  late TransacaoDao _transacaoDao;
  late ObrigadoDao _obrigadoDao;
  final _obrigadoService = ObrigadoService();

  DateTime? _dataVencimento;
  int _diasVencimentoPadrao = 30;

  List<Obrigado> _obrigados = [];
  Obrigado? _selectedObrigado;
  DateTime _dataEmprestimo = DateTime.now();
  bool _isEditing = false;

  final _valorMask = MaskTextInputFormatter(
    mask: 'R\$ #.###,##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _jurosMask = MaskTextInputFormatter(
    mask: '##,##%',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _transacaoDao = TransacaoDao(_dbHelper);
    _obrigadoDao = ObrigadoDao(_dbHelper);
    _carregarObrigados();
    _carregarDiasVencimentoPadrao();
    _carregarJurosPadrao();

    if (widget.transacao != null) {
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
        (o) => o.id == widget.transacao!.idObrigado,
        orElse: () => _obrigados.first,
      );
    }
  }

  void _preencherCamposEdicao() {
    final transacao = widget.transacao!;
    _dataEmprestimo = transacao.dataEmprestimo;
    _dataVencimento = transacao.dataVencimento;
    _valorController.text = _formatarMoeda(transacao.valorEmprestado);
    _jurosController.text = '${transacao.percentualJuros.toStringAsFixed(2)}%';
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
      double juros = _extrairValorNumerico(_jurosController.text);
      juros = juros / 100;
      final retorno = valor * juros;
      _retornoController.text = _formatarMoeda(retorno);
    } catch (_) {
      _retornoController.text = 'R\$ 0,00';
    }
  }

  double _extrairValorNumerico(String valorFormatado) {
    return double.parse(
      valorFormatado
          .replaceAll('R\$', '')
          .replaceAll('%', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim(),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataEmprestimo,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _dataEmprestimo = picked;
      });
    }
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

    final transacao = Transacao(
      id: _isEditing ? widget.transacao!.id : null,
      idObrigado: _selectedObrigado!.id!,
      dataEmprestimo: _dataEmprestimo,
      dataVencimento: _dataVencimento,
      valorEmprestado: _extrairValorNumerico(_valorController.text),
      percentualJuros: _extrairValorNumerico(_jurosController.text),
      retorno: _extrairValorNumerico(_retornoController.text),
      dataPagamentoRetorno: _isEditing ? widget.transacao!.dataPagamentoRetorno : null,
      dataPagamentoCompleto: _isEditing ? widget.transacao!.dataPagamentoCompleto : null,
    );

    int id = -1;
    if (_isEditing) {
      await _transacaoDao.updateTransacao(transacao);
      id = widget.transacao!.id!;
    } else {
      id = await _transacaoDao.insertTransacao(transacao);
    }

    if (_dataVencimento != null) {
      await NotificationService.agendarNotificacaoVencimento(
        id: id,
        nomeObrigado: _selectedObrigado!.nome,
        dataVencimento: _dataVencimento!,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_isEditing
              ? 'Transação atualizada com sucesso!'
              : 'Transação cadastrada com sucesso!')),
    );
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _valorController.dispose();
    _jurosController.dispose();
    _retornoController.dispose();
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
                Autocomplete<Obrigado>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _obrigados;
                    }
                    return _obrigados.where((obrigado) =>
                        obrigado.nome
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase()) ||
                        obrigado.zap
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase()));
                  },
                  displayStringForOption: (Obrigado option) =>
                      '${option.nome} (${option.zap})',
                  onSelected: (Obrigado selection) {
                    setState(() {
                      _selectedObrigado = selection;
                    });
                  },
                  fieldViewBuilder: (context, fieldTextEditingController,
                      fieldFocusNode, onFieldSubmitted) {
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
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Selecione ou cadastre um cliente';
                          }
                          _salvarNovoCliente(value.trim());
                          return 'Cliente criado. Clique em "Salvar" novamente.';
                        }
                        return null;
                      },
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        child: SizedBox(
                          height: 200.0,
                          width: MediaQuery.of(context).size.width - 32,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final Obrigado option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child:
                                      Text('${option.nome} (${option.zap})'),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data do Empréstimo',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd/MM/yyyy').format(_dataEmprestimo)),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dataVencimento ?? _dataEmprestimo,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _dataVencimento = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de Vencimento',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _dataVencimento != null
                          ? DateFormat('dd/MM/yyyy').format(_dataVencimento!)
                          : 'Selecione uma data',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
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
                ),
                const SizedBox(height: 20),
                TextFormField(
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
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _retornoController,
                  decoration: const InputDecoration(
                    labelText: 'Valor de Retorno Mensal',
                    border: OutlineInputBorder(),
                    filled: true,
                    enabled: false,
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _salvarTransacao,
                    child: Text(
                        _isEditing ? 'Atualizar Transação' : 'Salvar Transação'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _carregarJurosPadrao() async {
    final jurosPadrao = await ConfiguracaoService.getJurosPadrao();
    _jurosController.text = '${jurosPadrao.toStringAsFixed(2).replaceAll('.', ',')}%';
    _calcularRetorno();
  }
}
