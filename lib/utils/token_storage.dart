import 'package:shared_preferences/shared_preferences.dart';

/// Simplified storage — only company code persists (for login flow design)
/// Auth state is in-memory only (resets on refresh, as intended for prototype)
class TokenStorage {
  static const _companyCodeKey = 'taskmanager_company_code';

  static Future<void> setTokens(String access, String refresh) async {}

  static Future<void> clearTokens() async {}

  static Future<String?> getCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_companyCodeKey);
  }

  static Future<void> setCompanyCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_companyCodeKey, code.toUpperCase());
  }

  static Future<bool> hasCompanyCode() async {
    final code = await getCompanyCode();
    return code != null && code.isNotEmpty;
  }
}
