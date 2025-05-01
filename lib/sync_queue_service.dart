import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SyncQueueService {
  static const _queueKey = 'sync_queue';

  Future<void> adicionarNaFila(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final fila = prefs.getStringList(_queueKey) ?? [];
    fila.add(jsonEncode(payload));
    await prefs.setStringList(_queueKey, fila);
  }

  Future<List<Map<String, dynamic>>> carregarFila() async {
    final prefs = await SharedPreferences.getInstance();
    final fila = prefs.getStringList(_queueKey) ?? [];
    return fila.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<void> limparFila() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  Future<void> removerItem(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final fila = prefs.getStringList(_queueKey) ?? [];
    fila.remove(jsonEncode(item));
    await prefs.setStringList(_queueKey, fila);
  }
}
