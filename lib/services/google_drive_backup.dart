import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';

class GoogleDriveBackup {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  Future<void> uploadBackup(File file, String email) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) throw Exception('Falha ao autenticar com o Google');

      final authHeaders = await account.authHeaders;
      final authenticateClient = AuthenticatedClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      final now = DateTime.now();
      final fileName = 'bkp_${now.day.toString().padLeft(2, '0')}_'
          '${now.month.toString().padLeft(2, '0')}_'
          '${now.year}.db';

      final driveFile = drive.File()..name = fileName;

      await driveApi.files.create(
        driveFile,
        uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
      );

      print('Backup enviado com sucesso para o Google Drive como $fileName para $email');
    } catch (e) {
      print('Erro ao enviar backup: $e');
      rethrow;
    }
  }

  Future<bool> restoreBackup(String email) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) throw Exception('Falha ao autenticar com o Google');

      final authHeaders = await account.authHeaders;
      final authenticateClient = AuthenticatedClient(authHeaders);
      final driveApi = drive.DriveApi(authenticateClient);

      // Lista os arquivos mais recentes com prefixo 'bkp_'
      final fileList = await driveApi.files.list(
        q: "name contains 'bkp_' and trashed = false",
        spaces: 'drive',
        orderBy: 'createdTime desc',
        $fields: 'files(id, name)',
      );

      final files = fileList.files;
      if (files == null || files.isEmpty) {
        print('Nenhum backup encontrado para $email.');
        return false;
      }

      final fileId = files.first.id;
      if (fileId == null) return false;

      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as http.Response;

      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDir.path}/emprestimos.db';
      final dbFile = File(dbPath);

      await dbFile.writeAsBytes(media.bodyBytes);
      print('Backup restaurado com sucesso de $email para $dbPath');
      return true;
    } catch (e) {
      print('Erro ao restaurar backup: $e');
      rethrow;
    }
  }
}

class AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = IOClient();

  AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
