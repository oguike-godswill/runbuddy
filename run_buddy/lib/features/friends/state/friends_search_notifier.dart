import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/api_endpoints.dart';
import '../../auth/state/auth_notifier.dart';
import 'friends_notifier.dart';

final searchUsersProvider = FutureProvider.autoDispose.family<List<FriendModel>, String>((ref, query) async {
  final session = ref.watch(authProvider);
  if (session == null || query.trim().length < 2) return [];

  try {
    final res = await http.get(
      Uri.parse('${ApiEndpoints.friendSearch}?q=${Uri.encodeComponent(query.trim())}'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['users'] as List<dynamic>;
      return list.map((item) => FriendModel.fromJson(item)).toList();
    }
  } catch (_) {}

  return [];
});

class FriendsActionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  FriendsActionNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<bool> sendFriendRequest(String recipientId) async {
    final session = ref.read(authProvider);
    if (session == null) return false;

    state = const AsyncValue.loading();
    try {
      final res = await http.post(
        Uri.parse(ApiEndpoints.friendRequests),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({'recipientId': recipientId}),
      );

      if (res.statusCode == 201) {
        state = const AsyncValue.data(null);
        return true;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    return false;
  }
}

final friendsActionProvider = StateNotifierProvider<FriendsActionNotifier, AsyncValue<void>>((ref) {
  return FriendsActionNotifier(ref);
});

