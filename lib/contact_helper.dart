import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactHelper {
  static Future<List<Contact>> getContacts() async {
    if (await Permission.contacts.request().isGranted) {
      return await ContactsService.getContacts();
    }
    return [];
  }

  static Future<List<Map<String, String>>> getContactsSimplified() async {
    final contacts = await getContacts();
    return contacts.map((contact) {
      return {
        'name': contact.displayName ?? '',
        'phone': contact.phones?.firstOrNull?.value ?? ''
      };
    }).toList();
  }
}