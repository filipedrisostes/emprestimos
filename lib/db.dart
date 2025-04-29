import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

// Carrega o .env uma única vez
final DotEnv env = DotEnv()..load();

class Database {
  static PostgreSQLConnection? _connection;

  static Future<PostgreSQLConnection> connect() async {
    if (_connection != null && _connection!.isClosed == false) {
      return _connection!;
    }

    final host = env['DB_HOST']!;
    final port = int.parse(env['DB_PORT'] ?? '5432');
    final database = env['DB_NAME']!;
    final user = env['DB_USER']!;
    final password = env['DB_PASSWORD']!;

    final connection = PostgreSQLConnection(
      host,
      port,
      database,
      username: user,
      password: password,
      useSSL: true, // obrigatório em RDS
    );

    await connection.open();
    print('✅ Conectado ao PostgreSQL: $host/$database');

    _connection = connection;
    return connection;
  }

  static Future<void> close() async {
    if (_connection != null && !_connection!.isClosed) {
      await _connection!.close();
      print('🔌 Conexão encerrada.');
    }
  }
}
