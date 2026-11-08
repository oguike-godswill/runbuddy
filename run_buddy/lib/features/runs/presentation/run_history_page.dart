import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../app/route_names.dart';
import '../../../app/theme/colors.dart';
import '../../../core/network/api_endpoints.dart';
import '../../active_run/domain/run_state_model.dart';
import '../../active_run/state/active_run_notifier.dart';
import '../../auth/state/auth_notifier.dart';

class RunRecord {
  final String id;
  final String type;
  final double distanceKm;
  final int durationSeconds;
  final int averagePaceSeconds;
  final DateTime createdAt;

  RunRecord({
    required this.id,
    required this.type,
    required this.distanceKm,
    required this.durationSeconds,
    required this.averagePaceSeconds,
    required this.createdAt,
  });

  factory RunRecord.fromJson(Map<String, dynamic> json) {
    return RunRecord(
      id: json['id'] ?? '',
      type: json['type'] ?? 'SOLO',
      distanceKm: double.tryParse('${json['distance_km']}') ?? 0.0,
      durationSeconds: int.tryParse('${json['duration_seconds']}') ?? 0,
      averagePaceSeconds: int.tryParse('${json['average_pace_seconds']}') ?? 0,
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
    );
  }

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (averagePaceSeconds <= 0) return "--'--\"";
    final m = averagePaceSeconds ~/ 60;
    final s = (averagePaceSeconds % 60).toString().padLeft(2, '0');
    return '$m\'$s"/km';
  }
}

final runHistoryProvider = FutureProvider<List<RunRecord>>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null) return [];

  try {
    final res = await http.get(
      Uri.parse(ApiEndpoints.runs),
      headers: {'Authorization': 'Bearer ${user.accessToken}'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = (data['runs'] as List<dynamic>?) ?? [];
      return list.map((item) => RunRecord.fromJson(item)).toList();
    }
  } catch (_) {}

  return [];
});

class RunHistoryPage extends ConsumerWidget {
  const RunHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final historyAsync = ref.watch(runHistoryProvider);

    final totalRuns = user?.totalRuns ?? 0;
    final totalKm = user?.totalDistanceKm.toStringAsFixed(1) ?? '0.0';

    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      appBar: AppBar(
        title: const Text('Run History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(RouteNames.home),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceNavy,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('TOTAL RUNS', '$totalRuns', AppColors.textPrimary),
                    Container(width: 1, height: 36, color: AppColors.borderNavy),
                    _buildStatCol('DISTANCE', '$totalKm km', AppColors.electricLime),
                    Container(width: 1, height: 36, color: AppColors.borderNavy),
                    _buildStatCol('AVG PACE', user?.formattedPace ?? "--'--\"", AppColors.buddyBlue),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'LOGGED SESSIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: RefreshIndicator(
                  color: AppColors.electricLime,
                  backgroundColor: AppColors.surfaceNavy,
                  onRefresh: () async {
                    ref.invalidate(runHistoryProvider);
                    await ref.read(authProvider.notifier).refreshProfile();
                  },
                  child: historyAsync.when(
                    data: (runs) {
                      if (runs.isEmpty) {
                        return LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
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
                                      child: const Icon(Icons.directions_run_rounded, size: 36, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 18),
                                    const Text(
                                      'No Runs Logged Yet',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 8),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        'Your completed solo and shared companion runs will be recorded here with GPS routes and pace breakdown.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton(
                                      onPressed: () {
                                        ref.read(activeRunProvider.notifier).initSession(
                                          runId: 'solo_${DateTime.now().millisecondsSinceEpoch}',
                                          type: RunType.solo,
                                        );
                                        context.push(RouteNames.activeRun);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.electricLime,
                                        foregroundColor: AppColors.midnightNavy,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      ),
                                      child: const Text('START FIRST RUN', style: TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: runs.length,
                        itemBuilder: (context, index) {
                        final r = runs[index];
                        final isTogether = r.type.toUpperCase() == 'TOGETHER';
                        final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(r.createdAt.toLocal());

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceNavy,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderNavy),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isTogether
                                      ? AppColors.buddyBlue.withValues(alpha: 0.15)
                                      : AppColors.electricLime.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isTogether ? Icons.people_rounded : Icons.directions_run_rounded,
                                  color: isTogether ? AppColors.buddyBlue : AppColors.electricLime,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${r.distanceKm.toStringAsFixed(2)} km',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSlateNavy,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isTogether ? 'TOGETHER' : 'SOLO',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: isTogether ? AppColors.buddyBlue : AppColors.electricLime,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${r.formattedDuration} • Pace: ${r.formattedPace}',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.electricLime)),
                  error: (_, __) => const Center(child: Text('Could not load history', style: TextStyle(color: AppColors.textSecondary))),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        backgroundColor: AppColors.surfaceNavy,
        selectedItemColor: AppColors.electricLime,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) context.go(RouteNames.home);
          if (index == 1) context.push(RouteNames.friends);
          if (index == 3) context.push(RouteNames.profile);
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

  Widget _buildStatCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ],
    );
  }
}
