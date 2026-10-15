import 'package:flutter/services.dart';

class IOSConfiguration {
  static const channel = MethodChannel('emprestimos/ios_configuration');
  static Future<void> checkGoogleSignIn() async {
    final values = await channel
        .invokeMapMethod<String, dynamic>('googleSignInConfiguration');
    final id = values?['clientId'] as String? ?? '';
    final schemes = values?['schemes'] as List<dynamic>? ?? [];
    if (!RegExp(r'^[0-9]+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$')
            .hasMatch(id) ||
        !schemes.contains(id.split('.').reversed.join('.'))) {
      throw StateError(
          'O Google Drive ainda não foi configurado para este iPhone. Configure o cliente OAuth iOS e gere uma nova versão do app.');
    }
  }
}
