import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    Future<String> s = retornaDadosDoBanco();
    return Scaffold(
      body: Text(s.toString()),
    );
  }

  Future<String> retornaDadosDoBanco() async {
    var db = await openDatabase("emprestimos.db");
    await db.close();
    return "S";
  }
}