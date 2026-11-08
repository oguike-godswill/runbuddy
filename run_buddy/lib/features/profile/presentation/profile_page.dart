import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/route_names.dart';
import '../../../app/theme/colors.dart';
import '../../../app/widgets/logout_confirmation_dialog.dart';
import '../../auth/state/auth_notifier.dart';
import 'edit_profile_modal.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final runnerName = user?.displayName ?? 'Runner';
    final runnerHandle = user?.username != null ? '@${user!.username}' : '@runner';
    final runnerEmail = user?.email ?? '';
    final initial = runnerName.isNotEmpty ? runnerName[0].toUpperCase() : 'R';
    final totalKm = user?.totalDistanceKm.toStringAsFixed(1) ?? '0.0';
    final totalRuns = user?.totalRuns ?? 0;
    final pace = user?.formattedPace ?? '5\'30"/km';

    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      appBar: AppBar(
        title: const Text('Runner Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(RouteNames.home),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.electricLime),
            tooltip: 'Edit Profile',
            onPressed: () => showEditProfileModal(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.errorCoral),
            tooltip: 'Sign Out',
            onPressed: () => showLogoutConfirmationDialog(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.electricLime,
          backgroundColor: AppColors.surfaceNavy,
          onRefresh: () async {
            await ref.read(authProvider.notifier).refreshProfile();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Profile Badge
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceSlateNavy,
                        border: Border.all(color: AppColors.electricLime, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.electricLime.withValues(alpha: 0.35),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.electricLime),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      runnerName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      runnerHandle,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.electricLime),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      runnerEmail,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => showEditProfileModal(context, ref),
                      icon: const Icon(Icons.edit_rounded, size: 15),
                      label: const Text('EDIT PROFILE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceSlateNavy,
                        foregroundColor: AppColors.electricLime,
                        side: const BorderSide(color: AppColors.borderNavy),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Lifetime Stats Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceNavy,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIFETIME METRICS',
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
                        _buildMetricCol('TOTAL DISTANCE', '$totalKm km', AppColors.electricLime),
                        _buildMetricCol('COMPLETED RUNS', '$totalRuns', AppColors.textPrimary),
                        _buildMetricCol('TARGET PACE', pace, AppColors.buddyBlue),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Running Preferences Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceNavy,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RUNNING PREFERENCES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPreferenceRow(
                      'Base Pace',
                      pace,
                      Icons.timer_outlined,
                      onTap: () => showEditProfileModal(context, ref),
                    ),
                    const Divider(color: AppColors.borderNavy, height: 24),
                    _buildPreferenceRow('Voice Companion', 'WebRTC Enabled (LiveKit)', Icons.mic_rounded),
                    const Divider(color: AppColors.borderNavy, height: 24),
                    _buildPreferenceRow('Location Privacy', 'Authorized Per Run Only', Icons.security_rounded),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: () => showLogoutConfirmationDialog(context, ref),
                icon: const Icon(Icons.logout_rounded, color: AppColors.errorCoral),
                label: const Text('LOG OUT OF ACCOUNT', style: TextStyle(color: AppColors.errorCoral, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.errorCoral),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        backgroundColor: AppColors.surfaceNavy,
        selectedItemColor: AppColors.electricLime,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) context.go(RouteNames.home);
          if (index == 1) context.push(RouteNames.friends);
          if (index == 2) context.push(RouteNames.history);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.directions_run_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline_rounded), label: 'Friends'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildPreferenceRow(String title, String subtitle, IconData icon, {VoidCallback? onTap}) {
    final row = Row(
      children: [
        Icon(icon, color: AppColors.electricLime, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (onTap != null)
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: row,
      );
    }
    return row;
  }
}

