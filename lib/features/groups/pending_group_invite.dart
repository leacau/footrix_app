import 'package:shared_preferences/shared_preferences.dart';

class PendingGroupInvite {
  static const _key = 'pending_group_invite_code';

  static Future<void> save(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  static Future<String?> take() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      await prefs.remove(_key);
    }
    return code;
  }
}
