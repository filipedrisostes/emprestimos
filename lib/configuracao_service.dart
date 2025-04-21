import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracaoService {
  static const _jurosPadraoKey = 'juros_padrao';

  static Future<double> getJurosPadrao() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_jurosPadraoKey) ?? 5.0; // Valor padrão 5%
  }

  static Future<void> setJurosPadrao(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_jurosPadraoKey, valor);
  }
}