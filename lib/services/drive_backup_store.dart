import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// One stable Drive ID for the current backup and one for each closed day.
class DriveBackupStore {
  final drive.DriveApi api;
  final Directory identities;
  final String account;
  DriveBackupStore(this.api, this.identities, this.account);

  Future<void> put(File source, String name) async {
    if (name != 'bkp_atual.db' &&
        !RegExp(r'^bkp_dia_\d{4}-\d{2}-\d{2}\.db$').hasMatch(name)) {
      throw ArgumentError('Nome de backup inválido');
    }
    await identities.create(recursive: true);
    final key = sha256.convert(utf8.encode('$account/$name')).toString();
    final identity = File('${identities.path}/$key.json');
    String id;
    if (await identity.exists()) {
      id = (jsonDecode(await identity.readAsString())
          as Map<String, dynamic>)['id'] as String;
    } else {
      final found = await api.files.list(
          q: "name = '$name' and trashed = false",
          spaces: 'drive',
          orderBy: 'modifiedTime desc',
          pageSize: 1,
          $fields: 'files(id)');
      id = found.files?.isNotEmpty == true
          ? found.files!.first.id!
          : (await api.files.generateIds(count: 1, space: 'drive')).ids!.single;
      final temp = File('${identity.path}.tmp');
      await temp.writeAsString(jsonEncode({'id': id}), flush: true);
      await temp.rename(identity.path);
    }
    drive.File? existing;
    try {
      existing = await api.files.get(id, $fields: 'id,md5Checksum,trashed')
          as drive.File;
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status != 404) rethrow;
    }
    if (existing?.trashed == true) {
      // A user removed the old target; the next attempt will create a new one.
      await identity.delete();
      return put(source, name);
    }
    final checksum = (await md5.bind(source.openRead()).first).toString();
    if (existing?.md5Checksum == checksum) return;
    if (existing != null && name != 'bkp_atual.db') {
      throw StateError(
          'Já existe um fechamento diferente para $name. O histórico foi preservado.');
    }
    final metadata = drive.File()
      ..name = name
      ..mimeType = 'application/octet-stream'
      ..appProperties = {'emprestimosBackup': 'daily-v2'}
      ..description = name == 'bkp_atual.db'
          ? 'Estado atual do banco de empréstimos. Atualizado após cada alteração.'
          : 'Fechamento do dia ${name.substring(8, 18)} no horário local do aparelho.';
    final media = drive.Media(source.openRead(), await source.length());
    if (existing == null) {
      metadata.id = id;
      await api.files
          .create(metadata, uploadMedia: media)
          .timeout(const Duration(minutes: 3));
    } else {
      await api.files
          .update(metadata, id, uploadMedia: media)
          .timeout(const Duration(minutes: 3));
    }
  }
}
