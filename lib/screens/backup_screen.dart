import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database_helper.dart';
import '../configuracao_service.dart';
import '../services/backup_service.dart';
import '../services/google_drive_backup.dart';
import '../services/notificacao_service.dart';
import '../services/automatic_backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String _email = '';
  bool _busy = false;
  final _backup = BackupService(DatabaseHelper.instance);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = await ConfiguracaoService.getEmailPadrao();
    if (mounted) setState(() => _email = email);
  }

  Future<bool> _confirmRestore() async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Restaurar Backup'),
                  content: const Text(
                      'Os dados atuais serão substituídos pelos dados do backup. Continuar?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Restaurar'))
                  ])) ??
      false;
  Future<void> _run(Future<String?> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await work();
      if (mounted && message != null)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro no backup: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _local() async {
    Directory dir;
    if (Platform.isAndroid) {
      var allowed = await Permission.manageExternalStorage.isGranted;
      if (!allowed)
        allowed = (await Permission.manageExternalStorage.request()).isGranted;
      if (!allowed) allowed = (await Permission.storage.request()).isGranted;
      if (!allowed)
        throw StateError(
            'Permita o acesso aos arquivos para salvar em Downloads');
      dir = Directory('/storage/emulated/0/Download/EmprestimosBackups');
    } else {
      dir = await getApplicationDocumentsDirectory();
      if (Platform.isIOS) dir = Directory('${dir.path}/Backups');
    }
    final file = await _backup.exportar(
        '${dir.path}/backup_emprestimos_${DateTime.now().millisecondsSinceEpoch}.db');
    return Platform.isIOS
        ? 'Backup salvo. Abra Arquivos > No Meu iPhone > Empréstimos > Backups.'
        : 'Backup criado em: ${file.path}';
  }

  Future<String?> _restoreLocal() async {
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(
          label: 'Banco de dados',
          extensions: ['db', 'sqlite', 'sqlite3'],
          uniformTypeIdentifiers: ['public.data'])
    ]);
    if (file == null || !mounted || !await _confirmRestore()) return null;
    await _backup.restaurar(File(file.path));
    await NotificacaoService.instance.atualizar();
    return 'Backup restaurado com sucesso!';
  }

  Future<String?> _driveUpload() async {
    final dir = await getTemporaryDirectory();
    final file = await _backup.exportar(
        '${dir.path}/upload_${DateTime.now().microsecondsSinceEpoch}.db');
    try {
      await GoogleDriveBackup().uploadBackup(file, _email);
      return 'Backup enviado com sucesso!';
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<String?> _driveRestore() async {
    if (!await _confirmRestore()) return null;
    final ok = await GoogleDriveBackup().restoreBackup(_email);
    if (ok) await NotificacaoService.instance.atualizar();
    return ok
        ? 'Backup restaurado com sucesso!'
        : 'Nenhum backup encontrado no Drive.';
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: Scaffold(
          appBar: AppBar(title: const Text('Backup & Restauração')),
          body: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Text('Email configurado: $_email',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<String>(
                        valueListenable: AutomaticBackupService.status,
                        builder: (_, value, __) =>
                            Text(value, textAlign: TextAlign.center)),
                    TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await GoogleDriveBackup().connect();
                                  await AutomaticBackupService.instance
                                      ?.retry();
                                  return null;
                                }),
                        child: const Text(
                            'Conectar Google / tentar envios pendentes')),
                    for (final action in <(String, Future<String?> Function())>[
                      ('Fazer Backup no Google Drive', _driveUpload),
                      ('Restaurar Backup do Google Drive', _driveRestore),
                      ('Fazer Backup Local', _local),
                      ('Restaurar Backup Local', _restoreLocal),
                    ])
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ElevatedButton(
                              onPressed: _busy ? null : () => _run(action.$2),
                              child: Text(action.$1))),
                    if (_busy) const CircularProgressIndicator(),
                  ])))));
}
