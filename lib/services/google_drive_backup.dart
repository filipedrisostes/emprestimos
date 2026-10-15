import 'dart:io';
import 'dart:convert';
import 'drive_backup_store.dart';
import 'ios_configuration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../database_helper.dart';
import 'backup_service.dart';

class GoogleDriveBackup {
  static final GoogleSignIn _googleSignIn =
      GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
  Future<AuthenticatedClient> _client(
      {bool silent = false, String? expectedAccount}) async {
    if (Platform.isIOS) await IOSConfiguration.checkGoogleSignIn();
    final account = silent
        ? await _googleSignIn.signInSilently(suppressErrors: false)
        : await _googleSignIn.signIn();
    if (account == null) throw StateError('Login cancelado');
    if (expectedAccount != null && account.id != expectedAccount) {
      throw StateError(
          'Conecte a conta original para enviar os backups pendentes');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backup_google_account', account.id);
    await prefs.setString('backup_google_email', account.email);
    return AuthenticatedClient(await account.authHeaders);
  }

  Future<void> connect() async {
    final client = await _client();
    client.close();
  }

  static Future<void> _uploads = Future.value();
  static Future<void> _serialize(Future<void> Function() action) {
    final result = _uploads.then((_) => action());
    _uploads = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<void> bindAutomaticAccount(File file) async {
    final prefs = await SharedPreferences.getInstance();
    final sidecar = File('${file.path}.json');
    final data = await sidecar.exists()
        ? jsonDecode(await sidecar.readAsString()) as Map<String, dynamic>
        : <String, dynamic>{};
    data['account'] = prefs.getString('backup_google_account');
    await sidecar.writeAsString(jsonEncode(data), flush: true);
  }

  Future<void> uploadAutomatic(File file) => _serialize(() async {
        final sidecar = File('${file.path}.json');
        final metadata =
            jsonDecode(await sidecar.readAsString()) as Map<String, dynamic>;
        final owner = File('${file.path}.owner');
        final expected = await owner.exists()
            ? await owner.readAsString()
            : metadata['account'] as String?;
        final client = await _client(silent: true, expectedAccount: expected);
        try {
          // Bind an initially unassigned snapshot before attempting any upload.
          if (!await owner.exists()) {
            final temp = File('${owner.path}.tmp');
            await temp.writeAsString(_googleSignIn.currentUser!.id,
                flush: true);
            await temp.rename(owner.path);
          }
          await _store(client).then(
              (store) => store.put(file, metadata['remoteName'] as String));
        } finally {
          client.close();
        }
      });

  Future<DriveBackupStore> _store(AuthenticatedClient client) async {
    final dir = await getApplicationSupportDirectory();
    return DriveBackupStore(
        drive.DriveApi(client),
        Directory('${dir.path}/drive-backup-identities'),
        _googleSignIn.currentUser!.id);
  }

  Future<void> uploadBackup(File file, String email) => _serialize(() async {
        final client = await _client();
        try {
          await (await _store(client)).put(file, 'bkp_atual.db');
        } finally {
          client.close();
        }
      });

  Future<bool> restoreBackup(String email) async {
    final client = await _client();
    File? temp;
    try {
      final api = drive.DriveApi(client);
      // Prefer the live backup even when a daily archive was uploaded later.
      var files = (await api.files.list(
              q: "name = 'bkp_atual.db' and trashed = false",
              spaces: 'drive',
              orderBy: 'modifiedTime desc',
              pageSize: 1,
              $fields: 'files(id,name)'))
          .files;
      if (files == null || files.isEmpty) {
        files = (await api.files.list(
                q: "name contains 'bkp_' and trashed = false",
                spaces: 'drive',
                orderBy: 'modifiedTime desc',
                pageSize: 1,
                $fields: 'files(id,name)'))
            .files;
      }
      if (files == null || files.isEmpty) return false;
      final media = await api.files.get(files.first.id!,
          downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      temp = File(
          '${(await getTemporaryDirectory()).path}/drive_restore_${DateTime.now().microsecondsSinceEpoch}.db');
      final sink = temp.openWrite();
      try {
        await sink.addStream(media.stream);
      } finally {
        await sink.close();
      }
      await BackupService(DatabaseHelper.instance).restaurar(temp);
      return true;
    } finally {
      client.close();
      if (temp != null && await temp.exists()) await temp.delete();
    }
  }
}

class AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  AuthenticatedClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request..headers.addAll(_headers));
  @override
  void close() {
    _client.close();
    super.close();
  }
}
