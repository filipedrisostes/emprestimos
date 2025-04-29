import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracaoService {
  static const _jurosPadraoKey = 'juros_padrao';
  static const _diasVencimentoPadraoKey = 'dias_vencimento_padrao'; // ✅ Novo campo para dias vencimento

  // Retorna o valor padrão de juros salvo
  static Future<double> getJurosPadrao() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_jurosPadraoKey) ?? 30.0; // 5% como padrão
  }

  // Atualiza o valor de juros padrão
  static Future<void> setJurosPadrao(double valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_jurosPadraoKey, valor);
  }

  // ✅ Novo método: Retorna dias de vencimento padrão (default 30)
  static Future<int> getDiasVencimentoPadrao() async {
    final prefs = await SharedPreferences.getInstance();
    final dias = prefs.getInt(_diasVencimentoPadraoKey);
    return dias ?? 30; // ✅ Se não tiver valor salvo, assume 30 dias
  }


  // ✅ Novo método: Atualiza dias de vencimento padrão
  static Future<void> setDiasVencimentoPadrao(int dias) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_diasVencimentoPadraoKey, dias);
  }
}
