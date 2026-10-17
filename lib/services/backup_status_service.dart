import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupStatusService extends ChangeNotifier {
  static final instance = BackupStatusService();
  int pending = 0;
  DateTime? lastUpload;
  String? account, file;
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    lastUpload =
        DateTime.tryParse(prefs.getString('last_drive_upload_at') ?? '');
    account = prefs.getString('last_drive_upload_account');
    file = prefs.getString('last_drive_upload_file');
    notifyListeners();
  }

  void updatePending(int count) {
    pending = count;
    notifyListeners();
  }

  Future<void> uploaded(String name, String email) async {
    lastUpload = DateTime.now();
    account = email;
    file = name;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_drive_upload_at', lastUpload!.toUtc().toIso8601String());
    await prefs.setString('last_drive_upload_account', email);
    await prefs.setString('last_drive_upload_file', name);
  }
}
