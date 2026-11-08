import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../app/route_names.dart';
import '../../../app/theme/colors.dart';
import '../../../core/network/api_endpoints.dart';
import '../../active_run/domain/run_state_model.dart';
import '../../active_run/state/active_run_notifier.dart';
import '../../auth/state/auth_notifier.dart';
import '../../friends/state/friends_notifier.dart';

class StartRunPage extends ConsumerStatefulWidget {
  const StartRunPage({super.key});

  @override
  ConsumerState<StartRunPage> createState() => _StartRunPageState();
}

class _StartRunPageState extends ConsumerState<StartRunPage> {
  String? _selectedFriendId;
  double _goalDistanceKm = 5.0;
  bool _enableVoice = true;
  bool _isCreatingRun = false;

  void _handleCreateRunTogether(List<FriendModel> friends) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    if (_selectedFriendId == null && friends.isNotEmpty) {
      _selectedFriendId = friends.first.id;
    }

    if (_selectedFriendId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a friend or add a companion first'),
          backgroundColor: AppColors.errorCoral,
        ),
      );
      return;
    }

    final selectedFriend = friends.firstWhere((f) => f.id == _selectedFriendId);

    setState(() => _isCreatingRun = true);

    try {
      final res = await http.post(
        Uri.parse(ApiEndpoints.runs),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.accessToken}',
        },
        body: jsonEncode({
          'type': 'TOGETHER',
          'partnerId': selectedFriend.id,
          'goalDistanceKm': _goalDistanceKm,
        }),
      );

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final runId = data['run']['id'];
        final voiceData = data['voice'];

        ref.read(activeRunProvider.notifier).initSession(
          runId: runId,
          type: RunType.together,
          partnerId: selectedFriend.id,
          partnerName: selectedFriend.displayName,
          voiceToken: voiceData?['token'],
          voiceServerUrl: voiceData?['serverUrl'],
        );

        if (mounted) {
          context.push(RouteNames.runLobby);
        }
      } else {
        throw Exception('Run creation rejected');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not create shared run: $e'),
            backgroundColor: AppColors.errorCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingRun = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);

    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      appBar: AppBar(
        title: const Text('Run Together Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '1. CHOOSE YOUR COMPANION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: friendsAsync.when(
                  data: (friends) {
                    if (friends.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            const Text(
                              'No Companions Added',
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Search and add a running friend before starting a shared run.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => context.push(RouteNames.friends),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.electricLime,
                                foregroundColor: AppColors.midnightNavy,
                              ),
                              child: const Text('SEARCH RUNNERS', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      );
                    }

                    _selectedFriendId ??= friends.first.id;

                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final isSelected = _selectedFriendId == friend.id;
                        final initial = friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : 'U';

                        return GestureDetector(
                          onTap: () => setState(() => _selectedFriendId = friend.id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.surfaceSlateNavy : AppColors.surfaceNavy,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.electricLime : AppColors.borderNavy,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isSelected ? AppColors.electricLime : AppColors.surfaceSlateNavy,
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      color: isSelected ? AppColors.midnightNavy : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(friend.displayName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AppColors.textPrimary)),
                                      Text('@${friend.username} • Typical: ${friend.typicalDistanceKm} km',
                                          style: const TextStyle(
                                              fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded, color: AppColors.electricLime)
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricLime)),
                  error: (_, __) => const Center(child: Text('Could not load companions')),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                '2. GOAL DISTANCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [3.0, 5.0, 10.0, 15.0].map((dist) {
                  final isSelected = _goalDistanceKm == dist;
                  return GestureDetector(
                    onTap: () => setState(() => _goalDistanceKm = dist),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.electricLime : AppColors.surfaceNavy,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderNavy),
                      ),
                      child: Text(
                        '${dist.toInt()} km',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.midnightNavy : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Voice WebRTC Option (LiveKit)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceNavy,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic_none_rounded, color: AppColors.electricLime),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LiveKit Remote Voice Chat',
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Natural conversation while running',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _enableVoice,
                      activeThumbColor: AppColors.electricLime,
                      onChanged: (val) => setState(() => _enableVoice = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isCreatingRun
                    ? null
                    : () {
                        friendsAsync.whenData((friends) => _handleCreateRunTogether(friends));
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: AppColors.electricLime,
                  foregroundColor: AppColors.midnightNavy,
                ),
                child: _isCreatingRun
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.midnightNavy),
                      )
                    : const Text(
                        'START SHARED RUN & JOIN LOBBY',
                        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
