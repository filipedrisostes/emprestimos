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
  final _jurosMask = MaskTextInputFormatter(
    mask: '##,##%',
    filter: {"#": RegExp(r'[0-9]')},
  );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuração'),
      ),
      body: Column(
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
            TextButton(
                    onPressed: () async {
                      final juros = double.tryParse(_jurosController.text) ?? 30.0;
                      final email = _emailController.text;
                      await ConfiguracaoService.setJurosPadrao(juros);
                      await ConfiguracaoService.setEmailPadrao(email);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email padrão atualizado!')),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Juros padrão atualizado!')),
                      );
                    },
                    child: const Text('Salvar'),
                  )
        ]
      ),
    );
  }
}


class ConfiguracaoService {
  static const _jurosPadraoKey = 'juros_padrao';
  static const _emailPadraoKey = 'email_padrao';

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
  
}