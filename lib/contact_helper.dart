import 'package:flutter_contacts/flutter_contacts.dart';

class ContactHelper {
  /// Retorna a lista completa de contatos, com propriedades básicas
  static Future<List<Contact>> getContacts() async {
    if (await FlutterContacts.requestPermission(readonly: true)) {
      return await FlutterContacts.getContacts(withProperties: true);
    }
    return [];
  }

  /// Retorna uma lista simplificada com nome e telefone
  static Future<List<Map<String, String>>> getContactsSimplified() async {
    final contacts = await getContacts();
    return contacts.map((contact) {
      final name = contact.displayName;
      final phone =
          contact.phones.isNotEmpty ? contact.phones.first.number : '';
      return {
        'name': name,
        'phone': phone,
      };
    }).toList();
  }
}
