import 'package:emprestimos/background_backup.dart';
import 'package:emprestimos/screens/home_screen.dart';
import 'package:emprestimos/services/offline_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
//import 'package:workmanager/workmanager.dart';

// Defina AQUI o mesmo nome da task do background_backup.dart
const String _backupTask = "periodicBackup";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
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
