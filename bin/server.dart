import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:logging/logging.dart';
import 'package:dotenv/dotenv.dart';

import 'package:emprestimos/db.dart';
import 'package:emprestimos/routes/auth_routes.dart';
import 'package:emprestimos/routes/obrigados_routes.dart';
import 'package:emprestimos/routes/transacoes_routes.dart';

final DotEnv env = DotEnv()..load();  // Carrega o .env manualmente

void main() async {
  
  // Configura o logger para exibir os logs de requests
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('[${record.level.name}] ${record.time}: ${record.message}');
  });

  await Database.connect();

  final router = Router()
    ..mount('/auth/', AuthRoutes().router)
    ..mount('/obrigados/', ObrigadosRoutes().router)
    ..mount('/transacoes/', TransacoesRoutes().router);

  final handler = Pipeline()
      .addMiddleware(logMiddleware())
      .addMiddleware(_corsMiddleware())
      .addHandler(router);

  final port = int.parse(env['API_PORT'] ?? '8080');

  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('🚀 API rodando em http://${server.address.host}:$port');
}

Middleware logMiddleware() {
  final _logger = Logger('API');
  return (innerHandler) {
    return (request) async {
      final start = DateTime.now();
      final response = await innerHandler(request);
      final duration = DateTime.now().difference(start);
      _logger.info(
          '${request.method} ${request.requestedUri} → ${response.statusCode} (${duration.inMilliseconds} ms)');
      return response;
    };
  };
}

Middleware _corsMiddleware() {
  return createMiddleware(
    responseHandler: (res) => res.change(
      headers: {
        ...res.headers,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Origin, Content-Type',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      },
    ),
  );
}
