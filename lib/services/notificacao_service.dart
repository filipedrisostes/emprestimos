import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  static const String _channelId = 'vencimentos_channel';
  static const String _channelName = 'Notificações de Vencimento';
  static const String _channelDesc = 'Notificações para transações vencidas';

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notificationsPlugin.initialize(settings);
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    // Configurar canal de notificação (Android 8+)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    
    await _notificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(androidChannel);
  }

  static Future<bool> _verificarPermissoes() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      return true;
    }
    return true;
  }

  static Future<void> agendarNotificacoesVencimento({
    required int idTransacaoPai,
    required String nomeObrigado,
    required List<DateTime> datasVencimento,
    required double valor,
  }) async {
    try {
      if (!await _verificarPermissoes()) {
        print('Permissões de notificação não concedidas');
        return;
      }

      final saoPaulo = tz.getLocation('America/Sao_Paulo');
      final agora = tz.TZDateTime.now(saoPaulo);
      
      // Filtra apenas datas futuras (evita notificar transações já vencidas)
      final datasFuturas = datasVencimento.where((data) => data.isAfter(agora)).toList();

      for (int i = 0; i < datasFuturas.length; i++) {
        final dataVencimento = datasFuturas[i];
        final dataNotificacao = tz.TZDateTime.from(
          dataVencimento.subtract(const Duration(days: 1)), // Notifica 1 dia antes
          saoPaulo,
        );

        await _notificationsPlugin.zonedSchedule(
          idTransacaoPai + i,
          'Transação vencendo amanhã!',
          'Parcela ${i+1} de $nomeObrigado - ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor)}',
          dataNotificacao,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation: 
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      print('Erro ao agendar notificações: $e');
    }
  }

  static Future<void> cancelarNotificacoes(int idTransacaoPai) async {
  final todasNotificacoes = await _notificationsPlugin.pendingNotificationRequests();
  
  // Cancela todas as notificações relacionadas a esta transação
  for (final notificacao in todasNotificacoes) {
    if (notificacao.id >= idTransacaoPai && notificacao.id < idTransacaoPai + 100) {
      await _notificationsPlugin.cancel(notificacao.id);
    }
  }
}

  static Future<void> mostrarNotificacaoVencida({
    required int id,
    required String titulo,
    required String mensagem,
  }) async {
    if (!await _verificarPermissoes()) return;

    await _notificationsPlugin.show(
      id,
      titulo,
      mensagem,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          color: Colors.red,
          enableVibration: true,
        ),
      ),
    );
  }
}