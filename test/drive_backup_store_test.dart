import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:emprestimos/services/drive_backup_store.dart';

void main() {
  late Directory dir;
  late File source;
  late DriveBackupStore store;
  late MockClient client;
  late Map<String, String> remote;
  late int creates;
  late int updates;
  late int generated;
  late bool loseResponse;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('drive_store_test');
    source = await File('${dir.path}/source.db').writeAsString('primeiro');
    remote = {};
    creates = updates = generated = 0;
    loseResponse = false;
    http.Response response(Object data, [int code = 200]) =>
        http.Response(jsonEncode(data), code, headers: {'content-type': 'application/json'});
    client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/generateIds')) return response({'ids': ['id${++generated}']});
      if (request.method == 'GET' && path.endsWith('/files')) return response({'files': []});
      if (request.method == 'GET') {
        final id = request.url.pathSegments.last;
        return remote.containsKey(id) ? response({'id': id, 'md5Checksum': remote[id]}) :
            response({'error': {'code': 404, 'message': 'Not found'}}, 404);
      }
      final checksum = md5.convert(await source.readAsBytes()).toString();
      if (request.method == 'POST') {
        creates++;
        final id = 'id$generated';
        remote[id] = checksum;
        if (loseResponse) {
          loseResponse = false;
          return response({'error': {'code': 503, 'message': 'Lost response'}}, 503);
        }
        return response({'id': id});
      }
      if (request.method == 'PATCH') {
        updates++;
        final id = request.url.pathSegments.last;
        remote[id] = checksum;
        return response({'id': id});
      }
      throw StateError('Unexpected ${request.method} $path');
    });
    store = DriveBackupStore(drive.DriveApi(client), Directory('${dir.path}/ids'), 'account');
  });
  tearDown(() async { client.close(); await dir.delete(recursive: true); });

  test('cria atual uma vez e sobrescreve mesmo ID com PATCH', () async {
    await store.put(source, 'bkp_atual.db');
    await source.writeAsString('segundo');
    await store.put(source, 'bkp_atual.db');
    expect(creates, 1);
    expect(updates, 1);
    expect(generated, 1);
    expect(remote.length, 1);
    expect(remote['id1'], md5.convert(utf8.encode('segundo')).toString());
  });

  test('resposta perdida reutiliza ID e não duplica arquivo no Drive', () async {
    loseResponse = true;
    await expectLater(store.put(source, 'bkp_atual.db'), throwsA(isA<drive.DetailedApiRequestError>()));
    await store.put(source, 'bkp_atual.db');
    expect(creates, 1);
    expect(updates, 0);
    expect(generated, 1);
  });

  test('histórico diário é idempotente e não aceita sobrescrita diferente', () async {
    await store.put(source, 'bkp_dia_2026-10-14.db');
    await store.put(source, 'bkp_dia_2026-10-14.db');
    await source.writeAsString('outro dia');
    await expectLater(store.put(source, 'bkp_dia_2026-10-14.db'), throwsStateError);
    await store.put(source, 'bkp_dia_2026-10-15.db');
    expect(creates, 2);
    expect(updates, 0);
    expect(remote.length, 2);
  });
}
