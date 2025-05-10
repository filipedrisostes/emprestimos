import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracaoScreen extends StatefulWidget {
  const ConfiguracaoScreen({Key? key}) : super(key: key);

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

    setState(() {
      _jurosController.text =
          juros.toStringAsFixed(2).replaceAll('.', ',') + '%';
      _emailController.text = email;
      _zapController.text = zap;
      _diasVencimentoController.text = diasVencimento.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                final juros =
                    _extrairValorNumerico(_jurosController.text); // Correto
                final email = _emailController.text;
                final zap = _zapController.text;
                final diasVenc = int.tryParse(_diasVencimentoController.text) ?? 0;

                await ConfiguracaoService.setJurosPadrao(juros);
                await ConfiguracaoService.setEmailPadrao(email);
                await ConfiguracaoService.setZapPadrao(zap);
                await ConfiguracaoService.setDiasVencimentoPadrao(diasVenc.toString());

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Configurações salvas com sucesso!')),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class ConfiguracaoService {
  static const _jurosPadraoKey = 'juros_padrao';
  static const _emailPadraoKey = 'email_padrao';
  static const _zapPadraoKey = 'zap_padrao';
  static const _diasVencimentoPadraoKey = 'dias_vencimento_padrao';

  static Future<double> getJurosPadrao() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_jurosPadraoKey) ?? 30.0;
  }

  static Future<void> setJurosPadrao(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_jurosPadraoKey, valor);
  }

  static Future<String> getEmailPadrao() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailPadraoKey) ?? "Sem email definido";
  }

  static Future<void> setEmailPadrao(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailPadraoKey, email);
  }

  static Future<String> getZapPadrao() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_zapPadraoKey) ?? "Sem celular definido";
  }

  static Future<void> setZapPadrao(String zap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_zapPadraoKey, zap);
  }

  static Future<int> getDiasVencimentoPadrao() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getString(_diasVencimentoPadraoKey);
    return int.tryParse(valor ?? '') ?? 0;
  }

  static Future<void> setDiasVencimentoPadrao(String dias) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_diasVencimentoPadraoKey, dias);
  }
}
