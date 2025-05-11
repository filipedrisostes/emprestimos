import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notificationsPlugin.initialize(settings);
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
  }

  static Future<bool> _verificarPermissaoAlarme() async {
    if (Platform.isAndroid) {
      // Método alternativo sem device_info_plus
      try {
        return await Permission.scheduleExactAlarm.request().isGranted;
      } catch (e) {
        print('Erro ao verificar permissão: $e');
        return false;
      }
    }
    return true;
  }

  static Future<void> agendarNotificacaoVencimento({
    required int id,
    required String nomeObrigado,
    required DateTime dataVencimento,
  }) async {
    try {
      if (dataVencimento.isBefore(DateTime.now())) return;
      
      if (!await _verificarPermissaoAlarme()) {
        print('Permissão para alarmes exatos não concedida');
        return;
      }

      final saoPaulo = tz.getLocation('America/Sao_Paulo');
      final dataAlvo = tz.TZDateTime.from(dataVencimento, saoPaulo);

      await _notificationsPlugin.zonedSchedule(
        id,
        'Transação vencendo!',
        'A transação de $nomeObrigado vence hoje.',
        dataAlvo,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'vencimento_channel',
            'Transações Vencidas',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('Erro ao agendar notificação: $e');
      // Fallback para notificação não-exata
      await _notificationsPlugin.zonedSchedule(
        id,
        'Transação vencendo!',
        'A transação de $nomeObrigado vence hoje.',
        tz.TZDateTime.from(dataVencimento, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'vencimento_channel',
            'Transações Vencidas',
            importance: Importance.max,
          ),
        ),
        androidAllowWhileIdle: false,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}