import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_endpoints.dart';

class UserSession {
  final String accessToken;
  final String refreshToken;
  final String id;
  final String email;
  final String displayName;
  final String username;
  final double typicalDistanceKm;
  final int typicalPaceSeconds;
  final int totalRuns;
  final double totalDistanceKm;

  UserSession({
    required this.accessToken,
    required this.refreshToken,
    required this.id,
    required this.email,
    required this.displayName,
    required this.username,
    this.typicalDistanceKm = 5.0,
    this.typicalPaceSeconds = 330,
    this.totalRuns = 0,
    this.totalDistanceKm = 0.0,
  });

  String get formattedPace {
    final mins = typicalPaceSeconds ~/ 60;
    final secs = (typicalPaceSeconds % 60).toString().padLeft(2, '0');
    return '$mins\'$secs"/km';
  }

  UserSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? id,
    String? email,
    String? displayName,
    String? username,
    double? typicalDistanceKm,
    int? typicalPaceSeconds,
    int? totalRuns,
    double? totalDistanceKm,
  }) {
    return UserSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      typicalDistanceKm: typicalDistanceKm ?? this.typicalDistanceKm,
      typicalPaceSeconds: typicalPaceSeconds ?? this.typicalPaceSeconds,
      totalRuns: totalRuns ?? this.totalRuns,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
    );
  }
}

class AuthNotifier extends StateNotifier<UserSession?> {
  AuthNotifier() : super(null);

  static const String _keyToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyEmail = 'auth_email';
  static const String _keyDisplayName = 'auth_display_name';
  static const String _keyUsername = 'auth_username';
  static const String _keyPace = 'auth_pace';
  static const String _keyDistance = 'auth_distance';
  static const String _keyTotalRuns = 'auth_total_runs';
  static const String _keyTotalDist = 'auth_total_dist';

  Future<void> _persistSession(UserSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      await prefs.setString(_keyToken, session.accessToken);
      await prefs.setString(_keyRefreshToken, session.refreshToken);
      await prefs.setString(_keyUserId, session.id);
      await prefs.setString(_keyEmail, session.email);
      await prefs.setString(_keyDisplayName, session.displayName);
      await prefs.setString(_keyUsername, session.username);
      await prefs.setInt(_keyPace, session.typicalPaceSeconds);
      await prefs.setDouble(_keyDistance, session.typicalDistanceKm);
      await prefs.setInt(_keyTotalRuns, session.totalRuns);
      await prefs.setDouble(_keyTotalDist, session.totalDistanceKm);
    } catch (_) {}
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      await prefs.remove(_keyToken);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyDisplayName);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyPace);
      await prefs.remove(_keyDistance);
      await prefs.remove(_keyTotalRuns);
      await prefs.remove(_keyTotalDist);
    } catch (_) {}
  }

  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
      final token = prefs.getString(_keyToken);
      final userId = prefs.getString(_keyUserId);
      if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
        return false;
      }

      final email = prefs.getString(_keyEmail) ?? '';
      final displayName = prefs.getString(_keyDisplayName) ?? 'Runner';
      final username = prefs.getString(_keyUsername) ?? 'runner';
      final pace = prefs.getInt(_keyPace) ?? 330;
      final typDist = prefs.getDouble(_keyDistance) ?? 5.0;
      final totalRuns = prefs.getInt(_keyTotalRuns) ?? 0;
      final totalDist = prefs.getDouble(_keyTotalDist) ?? 0.0;
      final refreshToken = prefs.getString(_keyRefreshToken) ?? '';

      state = UserSession(
        accessToken: token,
        refreshToken: refreshToken,
        id: userId,
        email: email,
        displayName: displayName,
        username: username,
        typicalPaceSeconds: pace,
        typicalDistanceKm: typDist,
        totalRuns: totalRuns,
        totalDistanceKm: totalDist,
      );

      // Verify and refresh stats in background
      refreshProfile().catchError((_) {});
      return true;
    } catch (_) {
      return false;
    }
  }

  void updateStats({required int totalRuns, required double totalDistanceKm}) {
    if (state != null) {
      state = state!.copyWith(
        totalRuns: totalRuns,
        totalDistanceKm: totalDistanceKm,
      );
      _persistSession(state!);
    }
  }

  Future<Map<String, dynamic>> register({
    required String displayName,
    required String username,
    required String email,
    required String password,
    required int typicalPaceSeconds,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(ApiEndpoints.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'displayName': displayName,
          'username': username,
          'email': email,
          'password': password,
          'typicalPaceSeconds': typicalPaceSeconds,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        final user = data['user'];
        final session = UserSession(
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
          id: user['id'],
          email: user['email'],
          displayName: user['display_name'] ?? displayName,
          username: user['username'],
          typicalPaceSeconds: typicalPaceSeconds,
          totalRuns: 0,
          totalDistanceKm: 0.0,
        );
        state = session;
        await _persistSession(session);
        return {'success': true};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to Run Buddy server: $e'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(ApiEndpoints.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final user = data['user'];
        final token = data['accessToken'];

        // Fetch fresh profile stats
        final profileRes = await http.get(
          Uri.parse(ApiEndpoints.me),
          headers: {'Authorization': 'Bearer $token'},
        );

        double dist = 0.0;
        int runs = 0;
        int pace = 330;

        if (profileRes.statusCode == 200) {
          final pData = jsonDecode(profileRes.body)['user'];
          dist = double.tryParse('${pData['total_distance_km']}') ?? 0.0;
          runs = int.tryParse('${pData['total_runs']}') ?? 0;
          pace = int.tryParse('${pData['typical_pace_seconds']}') ?? 330;
        }

        final session = UserSession(
          accessToken: token,
          refreshToken: data['refreshToken'],
          id: user['id'],
          email: user['email'],
          displayName: user['displayName'] ?? user['display_name'] ?? 'Runner',
          username: user['username'],
          typicalPaceSeconds: pace,
          totalDistanceKm: dist,
          totalRuns: runs,
        );
        state = session;
        await _persistSession(session);
        return {'success': true};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Invalid credentials'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Server connection error: $e'};
    }
  }

  void logout() {
    state = null;
    _clearPersistedSession();
  }

  Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String newPassword,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(ApiEndpoints.resetPassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Password reset successfully!'};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Password reset failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Server connection error: $e'};
    }
  }

  Future<void> refreshProfile() async {
    if (state == null) return;
    try {
      final res = await http.get(
        Uri.parse(ApiEndpoints.me),
        headers: {'Authorization': 'Bearer ${state!.accessToken}'},
      );
      if (res.statusCode == 200) {
        final pData = jsonDecode(res.body)['user'];
        final dist = double.tryParse('${pData['total_distance_km']}') ?? state!.totalDistanceKm;
        final runs = int.tryParse('${pData['total_runs']}') ?? state!.totalRuns;
        final pace = int.tryParse('${pData['typical_pace_seconds']}') ?? state!.typicalPaceSeconds;
        final typDist = double.tryParse('${pData['typical_distance_km']}') ?? state!.typicalDistanceKm;
        state = state!.copyWith(
          totalDistanceKm: dist,
          totalRuns: runs,
          typicalPaceSeconds: pace,
          typicalDistanceKm: typDist,
          displayName: pData['display_name'] ?? pData['displayName'] ?? state!.displayName,
          username: pData['username'] ?? state!.username,
        );
        _persistSession(state!);
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> updateProfile({
    required String displayName,
    required int typicalPaceSeconds,
    required double typicalDistanceKm,
  }) async {
    if (state == null) return {'success': false, 'error': 'Not authenticated'};
    try {
      final res = await http.put(
        Uri.parse(ApiEndpoints.me),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${state!.accessToken}',
        },
        body: jsonEncode({
          'displayName': displayName,
          'typicalPaceSeconds': typicalPaceSeconds,
          'typicalDistanceKm': typicalDistanceKm,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final pData = data['user'];
        final pace = int.tryParse('${pData['typical_pace_seconds']}') ?? typicalPaceSeconds;
        final dist = double.tryParse('${pData['typical_distance_km']}') ?? typicalDistanceKm;
        state = state!.copyWith(
          displayName: pData['display_name'] ?? displayName,
          typicalPaceSeconds: pace,
          typicalDistanceKm: dist,
        );
        _persistSession(state!);
        return {'success': true};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Profile update failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserSession?>((ref) {
  return AuthNotifier();
});
