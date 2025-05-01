import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../services/sync_service.dart';

class SyncRoutes {
  final _service = SyncService();

  Router get router {
    final router = Router();

    router.post('/', _sincronizar);

    return router;
  }

  Future<Response> _sincronizar(Request request) async {
    final body = await request.readAsString();

    final resultado = await _service.processarSync(body);

    return Response.ok(resultado, headers: {'Content-Type': 'application/json'});
  }
}
