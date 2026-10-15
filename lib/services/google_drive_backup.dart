import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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

  static Future<void> bindAutomaticAccount(File file) async {
    final prefs = await SharedPreferences.getInstance();
    await File('${file.path}.json').writeAsString(
        jsonEncode({
          'account': prefs.getString('backup_google_account'),
        }),
        flush: true);
  }

  Future<void> uploadAutomatic(File file) async {
    final sidecar = File('${file.path}.json');
    final metadata = await sidecar.exists()
        ? jsonDecode(await sidecar.readAsString()) as Map<String, dynamic>
        : <String, dynamic>{};
    final client = await _client(
        silent: true, expectedAccount: metadata['account'] as String?);
    try {
      final api = drive.DriveApi(client);
      final identity = File('${file.path}.remote');
      if (await identity.exists()) {
        metadata.addAll(
            jsonDecode(await identity.readAsString()) as Map<String, dynamic>);
        if (metadata['account'] != _googleSignIn.currentUser!.id) {
          throw StateError('Conecte a conta original do backup pendente');
        }
      } else {
        metadata['account'] ??= _googleSignIn.currentUser!.id;
        metadata['id'] =
            (await api.files.generateIds(count: 1, space: 'drive')).ids!.single;
        // Publish an immutable identity before sending bytes; interrupted writes
        // leave only .tmp and no upload has started. Retries reuse the same ID.
        final temporary = File('${identity.path}.tmp');
        await temporary.writeAsString(jsonEncode(metadata), flush: true);
        await temporary.rename(identity.path);
      }
      final id = metadata['id'] as String;
      try {
        final existing =
            await api.files.get(id, $fields: 'id,md5Checksum') as drive.File;
        final checksum = (await md5.bind(file.openRead()).first).toString();
        if (existing.md5Checksum == checksum) return;
        throw StateError('O backup remoto não corresponde à cópia local');
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status != 404) rethrow;
      }
      final stamp = RegExp(r'bkp_auto_(.+)_[a-f0-9]+\.db$')
          .firstMatch(file.path)
          ?.group(1);
      final capturedAt = (await file.lastModified()).toUtc();
      await api.files
          .create(
              drive.File()
                ..id = id
                ..name = file.uri.pathSegments.last
                ..createdTime = capturedAt
                ..description =
                    'Backup automático após alteração no banco. Data UTC: $stamp'
                ..mimeType = 'application/octet-stream',
              uploadMedia: drive.Media(file.openRead(), await file.length()))
          .timeout(const Duration(minutes: 3));
    } finally {
      client.close();
    }
  }

  Future<void> uploadBackup(File file, String email) async {
    final client = await _client();
    try {
      final api = drive.DriveApi(client);
      final now = DateTime.now();
      final name =
          'bkp_${now.day.toString().padLeft(2, '0')}_${now.month.toString().padLeft(2, '0')}_${now.year}.db';
      await api.files.create(drive.File()..name = name,
          uploadMedia: drive.Media(file.openRead(), await file.length()));
    } finally {
      client.close();
    }
  }

  Future<bool> restoreBackup(String email) async {
    final client = await _client();
    File? temp;
    try {
      final api = drive.DriveApi(client);
      final files = (await api.files.list(
              q: "name contains 'bkp_' and trashed = false",
              spaces: 'drive',
              orderBy: 'createdTime desc',
              $fields: 'files(id,name)'))
          .files;
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
