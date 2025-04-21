import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactHelper {
  /// Retorna a lista completa de contatos, com propriedades básicas
  static Future<List<Contact>> getContacts() async {
    // flutter_contacts já possui controle de permissão, mas se quiser manter permission_handler:
    if (await Permission.contacts.request().isGranted) {
      if (await FlutterContacts.requestPermission()) {
        return await FlutterContacts.getContacts(withProperties: true);
      }
    }
    return [];
  }

  /// Retorna uma lista simplificada com nome e telefone
  static Future<List<Map<String, String>>> getContactsSimplified() async {
    final contacts = await getContacts();
    return contacts.map((contact) {
      final name = contact.displayName;
      final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
      return {
        'name': name,
        'phone': phone,
      };
    }).toList();
  }
}
