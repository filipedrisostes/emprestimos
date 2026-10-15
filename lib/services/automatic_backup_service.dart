import 'dart:async';
import 'dart:convert';
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
  final DateTime Function() clock;
  Future<void> Function(File file)? prepare;
  Future<void>? _sending;
  String? _inFlight;
  Timer? _retry;
  Timer? _midnight;
  bool _disposed = false;
  StreamSubscription<ConnectivityResult>? _connectivity;
  Map<String, dynamic> _state = {'archives': <dynamic>[]};
  AutomaticBackupService(this.helper, this.directory, this.upload, this.report,
      {DateTime Function()? now})
      : clock = now ?? DateTime.now;
  File get _dirty => File('${directory.path}/capture-pending');
  File get _manifest => File('${directory.path}/daily-state.json');
  List<dynamic> get _archives => _state['archives'] as List<dynamic>;
  File _file(String name) => File('${directory.path}/$name');
  static String day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
      if (event != ConnectivityResult.none) unawaited(service.retry());
    });
    service._retry = Timer.periodic(
        const Duration(minutes: 1), (_) => unawaited(service.retry()));
    service._scheduleMidnight();
    unawaited(service.sendPending());
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = clock();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), () async {
      await retry();
      if (!_disposed) _scheduleMidnight();
    });
  }

  Future<void> _save() async {
    final temp = File('${_manifest.path}.tmp');
    await temp.writeAsString(jsonEncode(_state), flush: true);
    await temp.rename(_manifest.path);
  }

  Future<void> initialize() async {
    await directory.create(recursive: true);
    if (await _manifest.exists()) {
      _state =
          jsonDecode(await _manifest.readAsString()) as Map<String, dynamic>;
    } else {
      await _migrateLegacy();
    }
    helper.beforeChange = () async {
      await _recover();
      await _rollover(); // Freeze yesterday BEFORE today's first mutation.
      await _dirty.writeAsString(clock().toIso8601String(), flush: true);
    };
    helper.unchanged = _clearDirty;
    helper.afterChange = capture;
    await helper.exclusive(() async {
      await _recover();
      await _rollover();
      if (_state['current'] == null) {
        await _dirty.writeAsString(clock().toIso8601String(), flush: true);
        await capture(await helper.database, send: false);
      }
    });
    report(
        'Backup atual e histórico diário ativos. Pendentes: ${(await pending()).length}.');
  }

  Future<void> _clearDirty() async {
    if (await _dirty.exists()) await _dirty.delete();
  }

  Future<void> _recover() async {
    if (!await _dirty.exists()) return;
    final timestamp = DateTime.tryParse(await _dirty.readAsString()) ?? clock();
    await capture(await helper.database, at: timestamp, send: false);
    if (await _dirty.exists()) {
      throw StateError(
          'Libere espaço para preservar o backup antes de salvar outra alteração');
    }
  }

  Future<void> _metadata(File file, String name, {File? from}) async {
    var data = <String, dynamic>{};
    if (from != null && await File('${from.path}.json').exists()) {
      data = jsonDecode(await File('${from.path}.json').readAsString())
          as Map<String, dynamic>;
    }
    if (from != null && await File('${from.path}.owner').exists()) {
      data['account'] = await File('${from.path}.owner').readAsString();
    }
    data['remoteName'] = name;
    await File('${file.path}.json')
        .writeAsString(jsonEncode(data), flush: true);
    if (from == null) await prepare?.call(file);
  }

  // Calendar arithmetic uses local dates, including months, years and DST.
  Future<void> _rollover({DateTime? until, bool persist = true}) async {
    if (_state['current'] == null) return;
    final today = day(until ?? clock());
    while ((_state['day'] as String).compareTo(today) < 0) {
      final date = _state['day'] as String;
      final name = 'bkp_dia_$date.db';
      final source = _file(_state['current'] as String);
      final archive = _file(name);
      if (!await archive.exists()) {
        await _metadata(archive, name, from: source);
        final temp = await source.copy('${archive.path}.partial');
        await temp.rename(archive.path);
      }
      if (!_archives.contains(name)) _archives.add(name);
      final parsed = DateTime.parse(date);
      _state['day'] = day(DateTime(parsed.year, parsed.month, parsed.day + 1));
      // Save each date so interrupted catch-up resumes without duplicating days.
      if (persist) await _save();
    }
  }

  Future<List<File>> pending() async {
    return [
      for (final name in _archives) _file(name as String),
      if (_state['pendingCurrent'] == true) _file(_state['current'] as String),
    ];
  }

  Future<void> capture(Database db, {DateTime? at, bool send = true}) async {
    try {
      final now = at ?? clock();
      await _rollover(until: now);
      final name =
          'current_${now.microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}.db';
      final file = _file(name);
      await _metadata(file, 'bkp_atual.db');
      await databaseSnapshot(db, file.path);
      _state['current'] = name;
      _state['day'] ??= day(now);
      _state['pendingCurrent'] = true;
      await _save();
      await _clearDirty();
      await _pruneCurrent();
      report('Dados salvos. Atualização do backup aguardando envio.');
      if (send) unawaited(sendPending());
    } catch (e) {
      debugPrint('Erro ao criar snapshot automático: $e');
      report(
          'Dados salvos, mas a cópia está pendente. Verifique o espaço livre.');
    }
  }

  Future<void> _pruneCurrent() async {
    for (final entity in await directory.list().toList()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File &&
          name.startsWith('current_') &&
          name.endsWith('.db') &&
          name != _state['current'] &&
          name != _inFlight) {
        await entity.delete();
        final metadata = File('${entity.path}.json');
        if (await metadata.exists()) await metadata.delete();
        final owner = File('${entity.path}.owner');
        if (await owner.exists()) await owner.delete();
      }
    }
  }

  Future<void> retry() async {
    try {
      await helper.exclusive(() async {
        await _recover();
        await _rollover();
      });
      await sendPending();
    } catch (e) {
      debugPrint('Backup diário pendente: $e');
      report('Backup pendente. Verifique o armazenamento e tente novamente.');
    }
  }

  Future<void> sendPending() =>
      _sending ??= _send().whenComplete(() => _sending = null);
  Future<void> _send() async {
    try {
      while (!_disposed) {
        final file = await helper.exclusive(() async {
          final files = await pending();
          if (files.isEmpty) return null;
          _inFlight = files.first.uri.pathSegments.last;
          return files.first;
        });
        if (file == null) {
          if (!await _dirty.exists())
            report('Backup atual e histórico diário em dia.');
          return;
        }
        report('Sincronizando backup atual e histórico diário…');
        await upload(file);
        await helper.exclusive(() async {
          final name = file.uri.pathSegments.last;
          if (_archives.contains(name)) {
            _archives.remove(name);
            await _save();
            await file.delete();
            final metadata = File('${file.path}.json');
            if (await metadata.exists()) await metadata.delete();
          } else if (_state['current'] == name) {
            _state['pendingCurrent'] = false;
            await _save();
          }
          _inFlight = null;
          await _pruneCurrent();
        });
      }
    } catch (e) {
      debugPrint('Backup automático: $e');
      report(
          'Backup pendente: confira a conexão e o login do Google. Tentaremos novamente.');
    } finally {
      _inFlight = null;
    }
  }

  // Upgrade the previous per-change queue: retain the final state of each date.
  Future<void> _migrateLegacy() async {
    final old = (await directory
        .list()
        .where((e) =>
            e is File &&
            e.uri.pathSegments.last.startsWith('bkp_auto_') &&
            e.path.endsWith('.db'))
        .cast<File>()
        .toList())
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final source in old) {
      final date = (await source.lastModified()).toLocal();
      await _rollover(until: date, persist: false);
      final name = 'current_legacy_${source.uri.pathSegments.last}';
      final target = _file(name);
      await _metadata(target, 'bkp_atual.db', from: source);
      await source.copy(target.path);
      _state['current'] = name;
      _state['day'] ??= day(date);
      _state['pendingCurrent'] = true;
    }
    await _save();
    // Keep the old queue as a local safety copy, but don't upload it again.
    if (old.isNotEmpty) {
      final legacy = Directory('${directory.path}/legacy');
      await legacy.create(recursive: true);
      for (final source in old) {
        await source.rename('${legacy.path}/${source.uri.pathSegments.last}');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleMidnight();
      unawaited(retry());
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    _midnight?.cancel();
    await _connectivity?.cancel();
    helper.beforeChange = null;
    helper.afterChange = null;
    helper.unchanged = null;
    await _sending;
  }
}
