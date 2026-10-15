import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'database_snapshot.dart';
import 'google_drive_backup.dart';

class AutomaticBackupService with WidgetsBindingObserver {
  static final status = ValueNotifier<String>('Backup automático: iniciando…');
  static AutomaticBackupService? instance;
  final DatabaseHelper helper;
  final Directory directory;
  final Future<void> Function(File file) upload;
  final void Function(String message) report;
  Future<void> Function(File file)? prepare;
  Future<void>? _sending;
  Timer? _retry;
  StreamSubscription<ConnectivityResult>? _connectivity;
  AutomaticBackupService(this.helper, this.directory, this.upload, this.report);
  File get _dirty => File('${directory.path}/capture-pending');

  static Future<void> start() async {
    final dir = await getApplicationSupportDirectory();
    final service = AutomaticBackupService(
        DatabaseHelper.instance,
        Directory('${dir.path}/automatic-backups'),
        (file) => GoogleDriveBackup().uploadAutomatic(file),
        (message) => status.value = message);
    instance = service;
    service.prepare = GoogleDriveBackup.bindAutomaticAccount;
    await service.initialize();
    WidgetsBinding.instance.addObserver(service);
    service._connectivity =
        Connectivity().onConnectivityChanged.listen((event) {
      if (event != ConnectivityResult.none) unawaited(service.sendPending());
    });
    service._retry = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(service.retry());
    });
    unawaited(service.sendPending());
  }

  Future<void> initialize() async {
    await directory.create(recursive: true);
    helper.beforeChange = () async {
      // Recover a snapshot interrupted by a crash before another write occurs.
      if (await _dirty.exists()) await capture(await helper.database);
      if (await _dirty.exists())
        throw StateError(
            'Libere espaço para preservar o backup antes de salvar outra alteração');
      await _dirty.writeAsString('pending', flush: true);
    };
    helper.unchanged = _clearDirty;
    helper.afterChange = capture;
    if (await _dirty.exists())
      await helper.exclusive(() async {
        await capture(await helper.database);
      });
    report(
        'Backup automático ativo. Envios pendentes: ${(await pending()).length}.');
  }

  Future<void> _clearDirty() async {
    if (await _dirty.exists()) await _dirty.delete();
  }

  Future<List<File>> pending() async => (await directory
      .list()
      .where((item) => item is File && item.path.endsWith('.db'))
      .cast<File>()
      .toList())
    ..sort((a, b) => a.path.compareTo(b.path));

  Future<void> capture(Database db) async {
    try {
      final stamp =
          DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final nonce = Random.secure().nextInt(0x7fffffff).toRadixString(16);
      final file = File('${directory.path}/bkp_auto_${stamp}_$nonce.db');
      await prepare?.call(file);
      await databaseSnapshot(db, file.path);
      await _clearDirty();
      report('Alteração salva. Backup aguardando envio ao Google Drive.');
      unawaited(sendPending());
    } catch (e) {
      // The database commit has succeeded. Never report it as a failed save.
      debugPrint('Erro ao criar snapshot automático: $e');
      report(
          'Dados salvos, mas não foi possível criar a cópia de backup. Verifique o espaço livre e tente novamente.');
    }
  }

  Future<void> retry() async {
    try {
      if (await _dirty.exists()) {
        await helper.exclusive(() async => capture(await helper.database));
      }
      await sendPending();
    } catch (_) {
      report('Backup pendente. Verifique o armazenamento e tente novamente.');
    }
  }

  Future<void> sendPending() =>
      _sending ??= _send().whenComplete(() => _sending = null);
  Future<void> _send() async {
    try {
      while (true) {
        final files = await pending();
        if (files.isEmpty) {
          if (!await _dirty.exists()) report('Backup automático em dia.');
          return;
        }
        report('Enviando backups ao Google Drive (${files.length} pendentes)…');
        final file = files.first;
        await upload(file);
        await file.delete();
        final metadata = File('${file.path}.json');
        if (await metadata.exists()) await metadata.delete();
        final identity = File('${file.path}.remote');
        if (await identity.exists()) await identity.delete();
      }
    } catch (e) {
      report(
          'Backup pendente: confira a conexão e o login do Google. Tentaremos novamente automaticamente.');
      debugPrint('Backup automático: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(retry());
  }

  Future<void> dispose() async {
    _retry?.cancel();
    await _connectivity?.cancel();
    helper.beforeChange = null;
    helper.afterChange = null;
    helper.unchanged = null;
    await _sending;
  }
}
