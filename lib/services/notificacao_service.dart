import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../dao/transacao_dao.dart';
import '../dao/obrigado_dao.dart';
import '../database_helper.dart';

class NotificacaoService {
  static final instance = NotificacaoService._();
  NotificacaoService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void> atualizar({bool requestPermission = false}) async {
    if (!Platform.isAndroid) return;
    try {
      if (!_initialized) {
        tzdata.initializeTimeZones();
        await _plugin.initialize(const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher')));
        _initialized = true;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (requestPermission) await android?.requestNotificationsPermission();
      final exact = await android?.canScheduleExactNotifications() ?? false;
      final dao = TransacaoDao(DatabaseHelper.instance);
      final clientes = {
        for (final o
            in await ObrigadoDao(DatabaseHelper.instance).getAllObrigados())
          o.id: o.nome
      };
      await _plugin.cancelAll();
      final now = DateTime.now();
      for (final t in await dao.getAllTransacoes()) {
        if (t.id == null ||
            t.dataPagamentoCompleto != null ||
            t.dataPagamentoRetorno != null ||
            t.dataVencimento == null) continue;
        final d = t.dataVencimento!;
        final when = DateTime(d.year, d.month, d.day, 9);
        if (!when.isAfter(now)) continue;
        await _plugin.zonedSchedule(
            t.id!,
            'Notificações de Vencimento',
            '${clientes[t.idObrigado] ?? 'Cliente'}: parcela ${t.parcela} vence hoje.',
            tz.TZDateTime.from(when.toUtc(), tz.UTC),
            const NotificationDetails(
                android: AndroidNotificationDetails(
                    'vencimentos_channel', 'Notificações de Vencimento',
                    channelDescription: 'Lembretes dos vencimentos cadastrados',
                    importance: Importance.high,
                    priority: Priority.high)),
            androidScheduleMode: exact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle);
      }
    } catch (e, st) {
      debugPrint('Erro ao agendar notificações: $e\n$st');
    }
  }
}
