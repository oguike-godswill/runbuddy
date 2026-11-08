import 'package:shared_preferences/shared_preferences.dart';

class ApiEndpoints {
  static const String _defaultUrl = 'http://192.168.100.25:4000';
  static const String _keyServerUrl = 'custom_server_base_url';

  static String _baseUrl = const String.fromEnvironment('API_URL', defaultValue: _defaultUrl);

  /// Initializes persisted server URL preferences on startup.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      final savedUrl = prefs.getString(_keyServerUrl);
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _baseUrl = savedUrl.trim();
      }
    } catch (_) {}
  }

  /// Updates base URL dynamically and persists to SharedPreferences.
  static Future<void> setCustomBaseUrl(String newUrl) async {
    String cleanUrl = newUrl.trim();
    while (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (cleanUrl.isEmpty) {
      cleanUrl = _defaultUrl;
    }
    _baseUrl = cleanUrl;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      await prefs.setString(_keyServerUrl, cleanUrl);
    } catch (_) {}
  }

  static String get baseUrl => _baseUrl;

  static String get wsUrl {
    const envWs = String.fromEnvironment('WS_URL', defaultValue: '');
    if (envWs.isNotEmpty) return envWs;
    if (_baseUrl.startsWith('https://')) {
      return _baseUrl.replaceFirst('https://', 'wss://');
    } else if (_baseUrl.startsWith('http://')) {
      return _baseUrl.replaceFirst('http://', 'ws://');
    } else if (_baseUrl.startsWith('ws://') || _baseUrl.startsWith('wss://')) {
      return _baseUrl;
    }
    return 'ws://$_baseUrl';
  }

  // Auth
  static String get register => '$baseUrl/api/v1/auth/register';
  static String get login => '$baseUrl/api/v1/auth/login';
  static String get resetPassword => '$baseUrl/api/v1/auth/reset-password';
  static String get verifyEmail => '$baseUrl/api/v1/auth/verify';
  static String get me => '$baseUrl/api/v1/users/me';

  // Friends & Social
  static String get friends => '$baseUrl/api/v1/friends';
  static String get friendSearch => '$baseUrl/api/v1/users/search';
  static String get friendRequests => '$baseUrl/api/v1/friends/requests';

  // Runs
  static String get runs => '$baseUrl/api/v1/runs';
  static String get notifications => '$baseUrl/api/v1/notifications';
}
