import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/route_names.dart';
import '../../../app/theme/colors.dart';
import '../../../app/widgets/logout_confirmation_dialog.dart';
import '../../active_run/domain/run_state_model.dart';
import '../../active_run/state/active_run_notifier.dart';
import '../../auth/state/auth_notifier.dart';
import '../../friends/state/friends_notifier.dart';

class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userSession = ref.watch(authProvider);
    final friendsAsync = ref.watch(friendsProvider);

    final runnerName = userSession?.displayName ?? 'Runner';
    final runnerHandle = userSession?.username != null ? '@${userSession!.username}' : '@runner';
    final userInitial = runnerName.isNotEmpty ? runnerName[0].toUpperCase() : 'R';
    final paceString = userSession?.formattedPace ?? '5\'30"/km';
    final totalKm = userSession?.totalDistanceKm.toStringAsFixed(1) ?? '0.0';
    final totalRuns = userSession?.totalRuns ?? 0;

    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      body: RefreshIndicator(
        color: AppColors.electricLime,
        backgroundColor: AppColors.surfaceNavy,
        onRefresh: () async {
          await ref.read(authProvider.notifier).refreshProfile();
          ref.invalidate(friendsProvider);
        },
        child: CustomScrollView(
        slivers: [
          // Dynamic Rich Athletic Hero Header
          SliverAppBar(
            expandedHeight: 290,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.midnightNavy,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
                tooltip: 'Notifications',
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppColors.textPrimary),
                tooltip: 'Log out',
                onPressed: () => showLogoutConfirmationDialog(context, ref),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/running_track_night.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.midnightNavy.withValues(alpha: 0.45),
                          AppColors.midnightNavy.withValues(alpha: 0.85),
                          AppColors.midnightNavy,
                        ],
                        stops: const [0.0, 0.65, 1.0],
                      ),
                    ),
                  ),

                  // Hero Profile Content Overlay (Filling the top with authentic runner identity)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.electricLime.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.electricLime.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(radius: 3.5, backgroundColor: AppColors.electricLime),
                              SizedBox(width: 6),
                              Text(
                                'ACTIVE RUNNER PROFILE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: AppColors.electricLime,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surfaceSlateNavy,
                                border: Border.all(color: AppColors.electricLime, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.electricLime.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  userInitial,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.electricLime,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    runnerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$runnerHandle • Pace: $paceString',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            _buildTopQuickBadge(Icons.straighten_rounded, '$totalKm km', 'Total Distance'),
                            const SizedBox(width: 8),
                            _buildTopQuickBadge(Icons.timer_outlined, paceString, 'Target Pace'),
                            const SizedBox(width: 8),
                            _buildTopQuickBadge(Icons.fitness_center_rounded, '$totalRuns runs', 'Completed'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Body Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Buddy Card or Empty State
                  friendsAsync.when(
                    data: (friends) {
                      if (friends.isEmpty) {
                        return _buildNoBuddyCard(context);
                      }
                      return _buildYourBuddyCard(context, ref, friends.first);
                    },
                    loading: () => Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceNavy,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.electricLime),
                      ),
                    ),
                    error: (_, __) => _buildNoBuddyCard(context),
                  ),

                  const SizedBox(height: 20),

                  // Start Solo vs Run Together Dual Launchpad
                  _buildRunLaunchpad(context, ref),

                  const SizedBox(height: 24),

                  // Real Aggregate Stats
                  _buildWeeklyStats(totalKm, totalRuns, paceString),

                  const SizedBox(height: 24),

                  // Friends Online / Empty state
                  _buildFriendsQuickList(context, friendsAsync),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        backgroundColor: AppColors.surfaceNavy,
        selectedItemColor: AppColors.electricLime,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) {
            context.push(RouteNames.friends);
          } else if (index == 2) {
            context.push(RouteNames.history);
          } else if (index == 3) {
            context.push(RouteNames.profile);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildTopQuickBadge(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceNavy.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderNavy),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.electricLime),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBuddyCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceNavy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderNavy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_add_alt_rounded, color: AppColors.buddyBlue, size: 24),
              SizedBox(width: 10),
              Text(
                'NO RUNNING BUDDY YET',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Connect with a friend to unlock synchronized shared runs, companion telemetry, and live WebRTC voice.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push(RouteNames.friends),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              backgroundColor: AppColors.electricLime,
              foregroundColor: AppColors.midnightNavy,
            ),
            child: const Text('FIND & INVITE COMPANIONS', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildYourBuddyCard(BuildContext context, WidgetRef ref, FriendModel buddy) {
    final buddyName = buddy.displayName.trim();
    final words = buddyName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.isNotEmpty
        ? words.map((n) => n[0].toUpperCase()).take(2).join()
        : 'B';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceNavy,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borderNavy, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'YOUR RUNNING BUDDY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.freshGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.freshGreen.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: AppColors.freshGreen),
                    SizedBox(width: 6),
                    Text(
                      'Ready to run',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.freshGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.buddyBlue,
                child: Text(
                  initials,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buddyName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Typical: ${buddy.typicalDistanceKm} km • @${buddy.username}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.push(RouteNames.startRun),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.electricLime,
              foregroundColor: AppColors.midnightNavy,
              elevation: 4,
              shadowColor: AppColors.electricLime.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.midnightNavy, size: 22),
                SizedBox(width: 8),
                Text(
                  'RUN TOGETHER NOW',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunLaunchpad(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              ref.read(activeRunProvider.notifier).initSession(
                runId: 'solo_${DateTime.now().millisecondsSinceEpoch}',
                type: RunType.solo,
              );
              context.push(RouteNames.activeRun);
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceNavy,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderNavy),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.directions_run_rounded, color: AppColors.electricLime, size: 28),
                  SizedBox(height: 12),
                  Text(
                    'Solo Run',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text('GPS & audio pacing', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push(RouteNames.startRun),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceNavy,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderNavy),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.people_alt_rounded, color: AppColors.buddyBlue, size: 28),
                  SizedBox(height: 12),
                  Text(
                    'Choose Buddy',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text('Invite any companion', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyStats(String totalKm, int totalRuns, String paceString) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceNavy,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderNavy),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AGGREGATE RUNNING STATS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(label: 'Total Distance', value: '$totalKm km', color: AppColors.electricLime),
              _StatItem(label: 'Runs Logged', value: '$totalRuns', color: AppColors.textPrimary),
              _StatItem(label: 'Target Pace', value: paceString, color: AppColors.buddyBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsQuickList(BuildContext context, AsyncValue<List<FriendModel>> friendsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'COMPANIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            GestureDetector(
              onTap: () => context.push(RouteNames.friends),
              child: const Text(
                'Find Runners',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.electricLime,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        friendsAsync.when(
          data: (friends) {
            if (friends.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSlateNavy,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'No companions connected yet. Use Find Runners to connect!',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              );
            }
            return Column(
              children: friends.map((f) {
                return _buildFriendItem(f.displayName, '@${f.username}', true);
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricLime)),
          error: (_, __) => const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildFriendItem(String name, String sub, bool isOnline) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderNavy),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceSlateNavy,
            child: Text(
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'R',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.freshGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  CircleAvatar(radius: 3, backgroundColor: AppColors.freshGreen),
                  SizedBox(width: 4),
                  Text('Active', style: TextStyle(fontSize: 10, color: AppColors.freshGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
