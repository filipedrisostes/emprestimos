import 'package:emprestimos/database_helper.dart';
import 'package:emprestimos/screens/home_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'services/automatic_backup_service.dart';
import 'services/notificacao_service.dart';
//import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await DatabaseHelper.instance.database; // força inicialização
  await AutomaticBackupService.start();

  runApp(const MyApp());
  NotificacaoService.instance.start();
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
