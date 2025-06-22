import 'package:emprestimos/background_backup.dart';
import 'package:emprestimos/dao/obrigado_dao.dart';
import 'package:emprestimos/dao/transacao_dao.dart';
import 'package:emprestimos/dao/transacao_pai_dao.dart';
import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/screens/home_screen.dart';
import 'package:emprestimos/services/notificacao_service.dart';
import 'package:emprestimos/services/offline_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
//import 'package:workmanager/workmanager.dart';

// Defina AQUI o mesmo nome da task do background_backup.dart
const String _backupTask = "periodicBackup";
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR'); // Importante para datas em português
  await NotificationService.initialize();
  await _verificarTransacoesVencidas();
  
  /*WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize(); // 🔁 Isso deve vir ANTES de qualquer uso do tz.local
  Intl.defaultLocale = 'pt_BR';*/
  
  /*const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);*/

    // 1) inicializa o dispatcher
  /*Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false, // true = mais logs
  );

  // 2) registra a tarefa periódica (a cada 24h)
  Workmanager().registerPeriodicTask(
    '1',
    _backupTask,
    frequency: Duration(hours: 24),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );*/
  // Inicializa o listener de conectividade
  OfflineSyncService();  // apenas instanciar já dispara o listener
  await DatabaseHelper.instance.database; // força inicialização
  await _verificarTransacoesVencidas();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Gerenciador de Empréstimos',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const HomeScreen(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
  supportedLocales: const [
    Locale('pt', 'BR'),
  ],
      ),
      
    );
  }

}

Future<void> _verificarTransacoesVencidas() async {
  try {
    final agora = DateTime.now();
    final transacaoDao = TransacaoDao(DatabaseHelper.instance);
    final transacoes = await transacaoDao.getAllTransacoes();
    
    for (final transacao in transacoes) {
      // Verifica se:
      // 1. Tem data de vencimento
      // 2. Está vencida (data anterior à atual)
      // 3. Não foi paga (nem parcial nem totalmente)
      if (transacao.dataVencimento != null && 
          transacao.dataVencimento!.isBefore(agora) &&
          transacao.dataPagamentoRetorno == null &&
          transacao.dataPagamentoCompleto == null) {
        
        final transacaoPai = await TransacaoPaiDao(DatabaseHelper.instance)
            .buscarPorId(transacao.idTransacaoPai);
        
        if (transacaoPai != null) {
          final obrigado = await ObrigadoDao(DatabaseHelper.instance)
              .getObrigadoById(transacaoPai.idObrigado);
          
          if (obrigado != null) {
            await NotificationService.mostrarNotificacaoVencida(
              id: transacao.id ?? 0,
              titulo: 'Transação vencida!',
              mensagem: 'Parcela ${transacao.parcela} de ${obrigado.nome} venceu em ${DateFormat('dd/MM/yyyy', 'pt_BR').format(transacao.dataVencimento!)}',
            );
          }
        }
      }
    }
  } catch (e) {
    print('Erro ao verificar transações vencidas: $e');
  }
}