import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../configuracao_service.dart';
import '../services/notificacao_service.dart';

class ConfiguracaoScreen extends StatefulWidget {
  const ConfiguracaoScreen({super.key});

  @override
  _ConfiguracaoScreenState createState() => _ConfiguracaoScreenState();
}

class _ConfiguracaoScreenState extends State<ConfiguracaoScreen> {
  final _jurosController = TextEditingController();
  final _emailController = TextEditingController();
  final _zapController = TextEditingController();
  final _diasVencimentoController = TextEditingController();

  final _jurosMask = MaskTextInputFormatter(
    mask: '##,##%',
    filter: {"#": RegExp(r'[0-9]')},
  );

  final _zapMask = MaskTextInputFormatter(
    mask: '(##)#####-####',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

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

  @override
  void initState() {
    super.initState();
    _carregarConfiguracoesSalvas();
  }

  Future<void> _carregarConfiguracoesSalvas() async {
    final juros = await ConfiguracaoService.getJurosPadrao();
    final email = await ConfiguracaoService.getEmailPadrao();
    final zap = await ConfiguracaoService.getZapPadrao();
    final diasVencimento = await ConfiguracaoService.getDiasVencimentoPadrao();

    if (!mounted) return;
    setState(() {
      _jurosController.text =
          '${juros.toStringAsFixed(2).replaceAll('.', ',')}%';
      _emailController.text = email;
      _zapController.text = zap;
      _diasVencimentoController.text = diasVencimento.toString();
    });
  }

  @override
  void dispose() {
    _jurosController.dispose();
    _emailController.dispose();
    _zapController.dispose();
    _diasVencimentoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
            child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email de recuperação',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
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
              controller: _zapController,
              decoration: const InputDecoration(
                labelText: 'Celular',
                border: OutlineInputBorder(),
                hintText: '(99)99999-9999',
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [_zapMask],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _diasVencimentoController,
              decoration: const InputDecoration(
                labelText: 'Dias para Vencimento',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                final juros =
                    _extrairValorNumerico(_jurosController.text); // Correto
                final email = _emailController.text;
                final zap = _zapController.text;
                final diasVenc =
                    int.tryParse(_diasVencimentoController.text) ?? 0;

                await ConfiguracaoService.setJurosPadrao(juros);
                await ConfiguracaoService.setEmailPadrao(email);
                await ConfiguracaoService.setZapPadrao(zap);
                await ConfiguracaoService.setDiasVencimentoPadrao(diasVenc);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Configurações salvas com sucesso!')),
                );
              },
              child: const Text('Salvar'),
            ),
            TextButton.icon(
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Ativar lembretes de vencimento'),
              onPressed: () async {
                await NotificacaoService.instance
                    .atualizar(requestPermission: true);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Confira a permissão de notificações nos ajustes do aparelho.')));
              },
            ),
          ],
        )),
      ),
    );
  }
}
