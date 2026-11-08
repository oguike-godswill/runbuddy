import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/route_names.dart';
import '../../../app/theme/colors.dart';
import '../domain/run_state_model.dart';
import '../state/active_run_notifier.dart';

class RunSummaryPage extends ConsumerWidget {
  const RunSummaryPage({super.key});

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPace(double paceSeconds) {
    if (paceSeconds <= 0 || paceSeconds > 3600) return "--'--\"";
    final min = paceSeconds ~/ 60;
    final sec = (paceSeconds % 60).toInt();
    return '$min\'${sec.toString().padLeft(2, '0')}"';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(activeRunProvider);
    final isSolo = runState.type == RunType.solo;
    final partnerName = runState.partnerName ?? 'Companion';

    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      appBar: AppBar(
        title: const Text('Run Summary'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              ref.read(activeRunProvider.notifier).disposeRun();
              context.go(RouteNames.home);
            },
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Celebration Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.electricLime.withValues(alpha: 0.2),
                      AppColors.surfaceNavy,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.electricLime.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: AppColors.electricLime, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      isSolo ? 'SOLO RUN COMPLETED' : 'SHARED RUN COMPLETED',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.electricLime,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSolo ? 'Great job on your run!' : 'Great run with $partnerName!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Run Stats Overview
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceNavy,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryMetric(
                          'TOTAL DISTANCE',
                          '${runState.distanceKm.toStringAsFixed(2)} km',
                          AppColors.electricLime,
                        ),
                        _buildSummaryMetric(
                          'TOTAL TIME',
                          _formatDuration(runState.durationSeconds),
                          AppColors.textPrimary,
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.borderNavy, height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryMetric(
                          'AVG PACE',
                          '${_formatPace(runState.paceSecondsPerKm)}/km',
                          AppColors.textPrimary,
                        ),
                        _buildSummaryMetric(
                          isSolo ? 'SESSION STATUS' : 'PARTNER DIST',
                          isSolo ? 'Completed' : '${runState.partnerDistanceKm.toStringAsFixed(2)} km',
                          AppColors.buddyBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Highlights Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSlateNavy,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isSolo ? AppColors.electricLime : AppColors.buddyBlue,
                      child: isSolo
                          ? const Icon(Icons.person_rounded, color: AppColors.midnightNavy)
                          : Text(
                              partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSolo ? 'Personal Solo Workout' : partnerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isSolo
                                ? 'Telemetry and route logged for your personal profile.'
                                : 'Kept pace with you for ${_formatDuration(runState.durationSeconds)}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () {
                  ref.read(activeRunProvider.notifier).disposeRun();
                  context.go(RouteNames.home);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricLime,
                  foregroundColor: AppColors.midnightNavy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('BACK TO HOME', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
