import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracaoService {
  static const _jurosPadraoKey = 'juros_padrao';
  static const _diasVencimentoPadraoKey = 'dias_vencimento_padrao'; // ✅ Novo campo para dias vencimento
  static const _emailPadraoKey = 'email_padrao';

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
    final raw = prefs.get(_diasVencimentoPadraoKey);
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 30;
    return 30;
  }

  // ✅ Novo método: Atualiza dias de vencimento padrão
  static Future<void> setDiasVencimentoPadrao(int dias) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_diasVencimentoPadraoKey, dias);
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
