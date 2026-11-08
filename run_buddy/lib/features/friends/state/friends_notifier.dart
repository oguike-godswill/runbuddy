import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/api_endpoints.dart';
import '../../auth/state/auth_notifier.dart';

class FriendModel {
  final String id;
  final String displayName;
  final String username;
  final String email;
  final double typicalDistanceKm;
  final int typicalPaceSeconds;
  final int totalRuns;

  FriendModel({
    required this.id,
    required this.displayName,
    required this.username,
    required this.email,
    this.typicalDistanceKm = 5.0,
    this.typicalPaceSeconds = 330,
    this.totalRuns = 0,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['id'] ?? '',
      displayName: json['display_name'] ?? json['displayName'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      typicalDistanceKm: double.tryParse('${json['typical_distance_km']}') ?? 5.0,
      typicalPaceSeconds: int.tryParse('${json['typical_pace_seconds']}') ?? 330,
      totalRuns: int.tryParse('${json['total_runs']}') ?? 0,
    );
  }
}

final friendsProvider = FutureProvider<List<FriendModel>>((ref) async {
  final session = ref.watch(authProvider);
  if (session == null) return [];

  try {
    final response = await http.get(
      Uri.parse(ApiEndpoints.friends),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = data['friends'] as List<dynamic>;
      return list.map((item) => FriendModel.fromJson(item)).toList();
    }
  } catch (_) {}

  // Zero dummy data: if no friends in database, return empty list!
  return [];
});

class FriendRequestModel {
  final String id;
  final String requesterId;
  final String username;
  final String displayName;
  final double typicalDistanceKm;

  FriendRequestModel({
    required this.id,
    required this.requesterId,
    required this.username,
    required this.displayName,
    this.typicalDistanceKm = 5.0,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'] ?? '',
      requesterId: json['requester_id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? 'Runner',
      typicalDistanceKm: double.tryParse('${json['typical_distance_km']}') ?? 5.0,
    );
  }
}

final friendRequestsProvider = FutureProvider<List<FriendRequestModel>>((ref) async {
  final session = ref.watch(authProvider);
  if (session == null) return [];

  try {
    final response = await http.get(
      Uri.parse(ApiEndpoints.friendRequests),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = (data['requests'] as List<dynamic>?) ?? [];
      return list.map((item) => FriendRequestModel.fromJson(item)).toList();
    }
  } catch (_) {}

  return [];
});

Future<bool> acceptFriendRequest(WidgetRef ref, String requestId) async {
  final session = ref.read(authProvider);
  if (session == null) return false;
  try {
    final res = await http.post(
      Uri.parse('${ApiEndpoints.friendRequests}/$requestId/accept'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    if (res.statusCode == 200) {
      ref.invalidate(friendRequestsProvider);
      ref.invalidate(friendsProvider);
      return true;
    }
  } catch (_) {}
  return false;
}
