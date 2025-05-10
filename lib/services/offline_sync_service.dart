import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Estrutura de fila de sincronização salva em SharedPreferences como lista JSON
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal() {
    _initConnectivityListener();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isProcessing = false;

  void _initConnectivityListener() {
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _processQueue();
      }
    });
  }

  Future<void> enqueue(String endpoint, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final queueList = prefs.getStringList('sync_queue') ?? [];
    queueList.add(jsonEncode({'endpoint': endpoint, 'payload': payload}));
    await prefs.setStringList('sync_queue', queueList);
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    final prefs = await SharedPreferences.getInstance();
    final queueList = prefs.getStringList('sync_queue') ?? [];
    final newQueue = <String>[];

    for (var item in queueList) {
      try {
        final obj = jsonDecode(item) as Map<String, dynamic>;
        final url = obj['endpoint'] as String;
        final payload = obj['payload'] as Map<String, dynamic>;
        final token = prefs.getString('jwt_token');
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer \$token',
          },
          body: jsonEncode(payload),
        );
        if (response.statusCode != 200) {
          newQueue.add(item);
        }
      } catch (_) {
        newQueue.add(item);
      }
    }

    await prefs.setStringList('sync_queue', newQueue);
    _isProcessing = false;
  }

  void dispose() {
    _subscription?.cancel();
  }
}

// Uso no app Flutter, em vez de chamar direto a API:
// await OfflineSyncService().enqueue('https://api/endpoint', {'key': 'value'});
// E sempre que voltar a conexão, ele tentará reenviar automaticamente.
