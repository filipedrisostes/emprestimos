import 'package:emprestimos/screens/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
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
      ),
    );
  }
}

// class HomeScreen extends StatelessWidget {
//   const HomeScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Gerenciador de Empréstimos'),
        
//       ),
//       drawer: Drawer(
//         child: ListView(
//           padding: EdgeInsets.zero,
//           children: [
//             const DrawerHeader(
//               decoration: BoxDecoration(
//                 color: Colors.blue,
//               ),
//               child: Text('Menu'),
//             ),
//             ListTile(
//               leading: const Icon(Icons.person_add),
//               title: const Text('Cadastrar Pessoa'),
//               onTap: () {
//                 Navigator.pop(context); // Fecha o drawer
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const CadastroObrigadoScreen(),
//                   ),
//                 );
//               },
//             ),
//             // Adicione mais itens do menu aqui
//           ],
//         ),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const ListaObrigadosScreen(),
//                   ),
//                 );
//               },
//               child: const Text('Visualizar Obrigados'),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const CadastroObrigadoScreen(),
//                   ),
//                 );
//               },
//               child: const Text('Cadastrar Obrigado'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }