import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/route_names.dart';
import '../../../app/theme/colors.dart';
import '../state/friends_notifier.dart';
import '../state/friends_search_notifier.dart';

class FriendsListPage extends ConsumerStatefulWidget {
  const FriendsListPage({super.key});

  @override
  ConsumerState<FriendsListPage> createState() => _FriendsListPageState();
}

class _FriendsListPageState extends ConsumerState<FriendsListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsProvider);
    final searchResultsAsync = _searchQuery.length >= 2
        ? ref.watch(searchUsersProvider(_searchQuery))
        : null;

    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      appBar: AppBar(
        title: const Text('Companions & Friends'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(RouteNames.home),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceNavy,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.electricLime),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    hintText: 'Search runners by name or @username...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Main Content: Search Results OR Real Friends List
            Expanded(
              child: _searchQuery.length >= 2
                  ? _buildSearchResults(searchResultsAsync)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPendingRequests(),
                        Expanded(child: _buildAcceptedFriendsList(friendsAsync)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<FriendModel>>? searchResultsAsync) {
    if (searchResultsAsync == null) return const SizedBox();

    return searchResultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_search_rounded, size: 56, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  'No runners found for "$_searchQuery"',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final user = results[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceNavy,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderNavy),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.surfaceSlateNavy,
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.electricLime),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        Text('@${user.username}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final sent = await ref.read(friendsActionProvider.notifier).sendFriendRequest(user.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(sent ? 'Friend request sent to ${user.displayName}' : 'Request could not be sent'),
                            backgroundColor: sent ? AppColors.freshGreen : AppColors.errorCoral,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      backgroundColor: AppColors.electricLime,
                      foregroundColor: AppColors.midnightNavy,
                    ),
                    child: const Text('ADD FRIEND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricLime)),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.errorCoral))),
    );
  }

  Widget _buildPendingRequests() {
    final requestsAsync = ref.watch(friendRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) return const SizedBox();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceSlateNavy,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.electricLime.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_pin_rounded, color: AppColors.electricLime, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'PENDING COMPANION REQUESTS (${requests.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.electricLime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...requests.map((req) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.surfaceNavy,
                        child: Text(
                          req.displayName.isNotEmpty ? req.displayName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.electricLime),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(req.displayName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            Text('@${req.username}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final ok = await acceptFriendRequest(ref, req.id);
                          if (mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Accepted ${req.displayName} as running companion!'),
                                backgroundColor: AppColors.electricLime,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          backgroundColor: AppColors.electricLime,
                          foregroundColor: AppColors.midnightNavy,
                        ),
                        child: const Text('ACCEPT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildAcceptedFriendsList(AsyncValue<List<FriendModel>> friendsAsync) {
    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSlateNavy,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderNavy),
                    ),
                    child: const Icon(Icons.people_outline_rounded, size: 38, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'No Friends Added Yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Search for runners above by username or name to send a friend request and start running together.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            final initial = friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : 'U';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceNavy,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderNavy),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.buddyBlue.withValues(alpha: 0.2),
                    child: Text(
                      initial,
                      style: const TextStyle(color: AppColors.buddyBlue, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.displayName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${friend.username} • ${friend.typicalDistanceKm} km',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => context.push(RouteNames.startRun),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      backgroundColor: AppColors.electricLime,
                      foregroundColor: AppColors.midnightNavy,
                    ),
                    child: const Text('INVITE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricLime)),
      error: (e, _) => Center(child: Text('Error loading friends: $e', style: const TextStyle(color: AppColors.errorCoral))),
    );
  }
}
