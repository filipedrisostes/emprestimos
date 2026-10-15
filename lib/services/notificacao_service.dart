import 'dart:io';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../dao/transacao_dao.dart';
import '../dao/obrigado_dao.dart';
import '../database_helper.dart';
import '../models/transacao.dart';

class NotificacaoService with WidgetsBindingObserver {
  static final instance = NotificacaoService._();
  NotificacaoService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void> _work = Future.value();
  void start() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(atualizar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(atualizar());
  }

  static List<Transacao> proximas(List<Transacao> items, DateTime now,
      {int? limit}) {
    final result = items.where((t) {
      final due = t.dataVencimento;
      return t.id != null &&
          t.dataPagamentoCompleto == null &&
          t.dataPagamentoRetorno == null &&
          due != null &&
          DateTime(due.year, due.month, due.day, 9).isAfter(now);
    }).toList()
      ..sort((a, b) {
        final byDate = a.dataVencimento!.compareTo(b.dataVencimento!);
        return byDate != 0 ? byDate : a.id!.compareTo(b.id!);
      });
    return limit == null ? result : result.take(limit).toList();
  }

  Future<void> atualizar({bool requestPermission = false}) {
    final result = _work.then((_) => _atualizar(requestPermission));
    _work = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _atualizar(bool requestPermission) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      if (!_initialized) {
        tzdata.initializeTimeZones();
        await _plugin.initialize(const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false)));
        _initialized = true;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (requestPermission) await android?.requestNotificationsPermission();
      if (requestPermission && Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
      final exact = await android?.canScheduleExactNotifications() ?? false;
      final dao = TransacaoDao(DatabaseHelper.instance);
      final clientes = {
        for (final o
            in await ObrigadoDao(DatabaseHelper.instance).getAllObrigados())
          o.id: o.nome
      };
      await _plugin.cancelAll();
      final now = DateTime.now();
      for (final t in proximas(await dao.getAllTransacoes(), now,
          limit: Platform.isIOS ? 64 : null)) {
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
                iOS: DarwinNotificationDetails(
                    presentAlert: true, presentSound: true),
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
