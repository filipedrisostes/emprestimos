import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';

class GoogleDriveBackup {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  Future<void> uploadBackup(File file) async {
    final account = await _googleSignIn.signIn();
    final authHeaders = await account!.authHeaders;
    final authenticateClient = AuthenticatedClient(authHeaders);

    final driveApi = drive.DriveApi(authenticateClient);

    final driveFile = drive.File();
    driveFile.name = 'bkp_${DateTime.now().toString().split(' ').first.replaceAll('-', '_')}';

    await driveApi.files.create(
      driveFile,
      uploadMedia: drive.Media(file.openRead(), file.lengthSync()),
    );
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
