import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/obrigado.dart';
import '../models/transacao.dart';
import 'package:emprestimos/sync_queue_service.dart';

class SyncSenderService {
  static const String baseUrl = 'https://emprestimos.cnw4ikm605fa.us-east-2.rds.amazonaws.com'; // Substitua aqui
  static const String syncUrl = '$baseUrl/sync/';

  Future<void> sincronizar(
    List<Obrigado> obrigados,
    List<Transacao> transacoes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final payload = {
      'obrigados': obrigados.map((o) => o.toJson()).toList(),
      'transacoes': transacoes.map((t) => t.toJson()).toList(),
    };

    if (token == null) {
      await SyncQueueService().adicionarNaFila(payload);
      throw Exception('Sem token: salvando na fila');
    }

    try {
      final response = await http.post(
        Uri.parse(syncUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('Erro do servidor');
      }

      print('✅ Sincronização OK');
    } catch (e) {
      await SyncQueueService().adicionarNaFila(payload);
      rethrow;
    }
  }

  Future<void> processarFilaPendente() async {
    final fila = await SyncQueueService().carregarFila();
    for (var item in fila) {
      try {
        await sincronizarSemSalvarNaFila(item);
        await SyncQueueService().removerItem(item);
      } catch (_) {
        // mantêm na fila
      }
    }
  }

  Future<void> sincronizarSemSalvarNaFila(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) throw Exception('Sem token');

    await http.post(
      Uri.parse(syncUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );
  }
}
