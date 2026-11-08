import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/route_names.dart';
import '../../../app/theme/colors.dart';
import '../domain/run_state_model.dart';
import '../state/active_run_notifier.dart';

class _RunCheer {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String message;

  const _RunCheer({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.message,
  });
}

const _kRunCheers = [
  _RunCheer(
    id: 'fire',
    label: 'FIRE',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF6D00),
    message: 'Fire Pace Activated!',
  ),
  _RunCheer(
    id: 'surge',
    label: 'SURGE',
    icon: Icons.bolt_rounded,
    color: AppColors.electricLime,
    message: 'Speed Surge!',
  ),
  _RunCheer(
    id: 'power',
    label: 'POWER',
    icon: Icons.fitness_center_rounded,
    color: AppColors.buddyBlue,
    message: 'Max Power!',
  ),
  _RunCheer(
    id: 'heart',
    label: 'HEART',
    icon: Icons.favorite_rounded,
    color: Color(0xFFFF2A6D),
    message: 'Keep Pushing!',
  ),
  _RunCheer(
    id: 'cheer',
    label: 'CHEERS',
    icon: Icons.thumb_up_alt_rounded,
    color: AppColors.freshGreen,
    message: 'Great Job!',
  ),
];

class _ParticleData {
  final Key key;
  final IconData icon;
  final Color color;
  final double startX;
  final double driftX;
  final double driftY;
  final double size;

  const _ParticleData({
    required this.key,
    required this.icon,
    required this.color,
    required this.startX,
    required this.driftX,
    required this.driftY,
    required this.size,
  });
}

class ActiveSharedRunPage extends ConsumerStatefulWidget {
  const ActiveSharedRunPage({super.key});

  @override
  ConsumerState<ActiveSharedRunPage> createState() => _ActiveSharedRunPageState();
}

class _ActiveSharedRunPageState extends ConsumerState<ActiveSharedRunPage> {
  final List<_ParticleData> _particles = [];
  String? _hudMessage;
  Color? _hudColor;
  IconData? _hudIcon;
  Timer? _hudTimer;
  StreamSubscription<String>? _reactionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reactionSub = ref.read(activeRunProvider.notifier).reactionStream.listen((reactionId) {
        final cheer = _kRunCheers.firstWhere(
          (c) => c.id == reactionId,
          orElse: () => _kRunCheers.first,
        );
        final runState = ref.read(activeRunProvider);
        _triggerCheer(cheer, runState, ref.read(activeRunProvider.notifier), isFromPartner: true);
      });
    });
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _reactionSub?.cancel();
    super.dispose();
  }

  void _triggerCheer(_RunCheer cheer, RunStateModel runState, ActiveRunNotifier notifier,
      {bool isFromPartner = false}) {
    if (!isFromPartner) {
      notifier.sendReaction(cheer.id);
    }

    _hudTimer?.cancel();
    setState(() {
      _hudMessage = isFromPartner
          ? '${runState.partnerName ?? 'Partner'} sent ${cheer.label}!'
          : (runState.type == RunType.together
              ? 'Sent ${cheer.label} to ${runState.partnerName ?? 'Companion'}!'
              : cheer.message);
      _hudColor = cheer.color;
      _hudIcon = cheer.icon;
    });

    _hudTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _hudMessage = null);
      }
    });

    final rand = math.Random();
    for (int i = 0; i < 5; i++) {
      final pKey = UniqueKey();
      final particle = _ParticleData(
        key: pKey,
        icon: cheer.icon,
        color: cheer.color,
        startX: (rand.nextDouble() - 0.5) * 100,
        driftX: (rand.nextDouble() - 0.5) * 80,
        driftY: -120 - rand.nextDouble() * 70,
        size: 22.0 + rand.nextDouble() * 14,
      );

      setState(() {
        _particles.add(particle);
      });

      Timer(const Duration(milliseconds: 1300), () {
        if (mounted) {
          setState(() {
            _particles.removeWhere((p) => p.key == pKey);
          });
        }
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPace(double paceSeconds) {
    if (paceSeconds <= 0 || paceSeconds > 3600) return "--'--\"";
    final min = (paceSeconds ~/ 60);
    final sec = (paceSeconds % 60).toInt();
    return '$min\'${sec.toString().padLeft(2, '0')}"';
  }

  Future<void> _handleExitRequested(
    BuildContext context,
    RunStateModel runState,
    ActiveRunNotifier notifier,
  ) async {
    final isInitial = runState.durationSeconds == 0 && runState.distanceKm == 0;
    if (isInitial) {
      notifier.disposeRun();
      context.pop();
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderNavy, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.stop_circle_outlined, color: AppColors.errorCoral, size: 24),
            SizedBox(width: 10),
            Text(
              'End Active Run?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: const Text(
          'Your run is currently active. Would you like to finish and record this workout, or keep running?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Running', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Finish & Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      await notifier.finishRun();
      if (context.mounted) {
        context.pushReplacement(RouteNames.runSummary);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(activeRunProvider);
    final runNotifier = ref.read(activeRunProvider.notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleExitRequested(context, runState, runNotifier);
      },
      child: Scaffold(
        backgroundColor: AppColors.midnightNavy,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar: Connection & Voice & Partner Status
              _buildTopStatusHeader(context, runState, runNotifier),

              // Hero Live Togetherness & Proximity Banner
              _buildTogethernessIndicator(runState, runNotifier),

              // Live Map Simulation Container with Floating Burst & Top HUD Pill
              Expanded(
                flex: 4,
                child: _buildLiveMapContainer(runState),
              ),

              // Primary Metrics Display (Distance, Pace, Time) + In-Run Reactions
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceNavy,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    border: Border(
                      top: BorderSide(color: AppColors.borderNavy, width: 1.5),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                    // Distance Hero Counter
                    Column(
                      children: [
                        const Text(
                          'DISTANCE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              runState.distanceKm.toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.w800,
                                color: AppColors.electricLime,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'km',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Metrics Grid (Duration, Pace, Partner Distance)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricTile(
                          label: 'TIME',
                          value: _formatDuration(runState.durationSeconds),
                        ),
                        Container(
                          width: 1,
                          height: 38,
                          color: AppColors.borderNavy,
                        ),
                        _buildMetricTile(
                          label: 'CURRENT PACE',
                          value: _formatPace(runState.paceSecondsPerKm),
                        ),
                        if (runState.type == RunType.together) ...[
                          Container(
                            width: 1,
                            height: 38,
                            color: AppColors.borderNavy,
                          ),
                          _buildMetricTile(
                            label: runState.partnerName ?? 'BUDDY',
                            value: '${runState.partnerDistanceKm.toStringAsFixed(2)} km',
                            highlightColor: AppColors.buddyBlue,
                          ),
                        ],
                      ],
                    ),

                    // In-Run Athletic Encouragement Reactions
                    _buildAthleticReactionRow(context, runState, runNotifier),

                    // Action Controls (Pause/Resume, Finish, Voice)
                    _buildActionControls(context, runState, runNotifier),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTopStatusHeader(
      BuildContext context, RunStateModel runState, ActiveRunNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Voice & Partner State
          Row(
            children: [
              GestureDetector(
                onTap: runState.type == RunType.together ? notifier.toggleVoiceMute : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSlateNavy,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: runState.isVoiceConnected ? AppColors.electricLime : AppColors.borderNavy,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        runState.isMuted
                            ? Icons.mic_off_rounded
                            : (runState.isVoiceConnected ? Icons.mic_rounded : Icons.mic_none_rounded),
                        size: 16,
                        color: runState.isMuted
                            ? AppColors.errorCoral
                            : (runState.isVoiceConnected ? AppColors.electricLime : AppColors.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        runState.isMuted ? 'Muted' : (runState.isVoiceConnected ? 'LiveKit Voice Active' : 'Connecting Voice...'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: runState.isMuted
                              ? AppColors.errorCoral
                              : AppColors.electricLime,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Partner Status Tag
          if (runState.type == RunType.together)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSlateNavy,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderNavy),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getPartnerStateColor(runState.partnerState),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${runState.partnerName ?? 'Partner'}: ${_partnerStateLabel(runState.partnerState)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTogethernessIndicator(RunStateModel runState, ActiveRunNotifier notifier) {
    if (runState.type == RunType.solo) {
      final isPaused = runState.userState == RunParticipantState.paused;
      final isInitial = isPaused && runState.durationSeconds == 0;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceNavy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isInitial
                ? AppColors.electricLime
                : (runState.isSimulating ? AppColors.electricLime : AppColors.borderNavy),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isInitial
                      ? Icons.play_circle_fill_rounded
                      : (isPaused
                          ? Icons.pause_circle_filled_rounded
                          : (runState.isSimulating ? Icons.auto_mode_rounded : Icons.gps_fixed_rounded)),
                  size: 16,
                  color: isInitial
                      ? AppColors.electricLime
                      : (isPaused ? AppColors.warningAmber : AppColors.electricLime),
                ),
                const SizedBox(width: 8),
                Text(
                  isInitial
                      ? 'Ready to Run • Tap Play to Start'
                      : (isPaused
                          ? 'Solo Run • Paused'
                          : (runState.isSimulating ? 'Simulating Run (11.5 km/h)' : 'Solo Run • Live GPS Active')),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isInitial ? AppColors.electricLime : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: notifier.toggleSimulation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: runState.isSimulating
                      ? AppColors.warningAmber.withValues(alpha: 0.15)
                      : AppColors.electricLime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: runState.isSimulating ? AppColors.warningAmber : AppColors.electricLime,
                  ),
                ),
                child: Text(
                  runState.isSimulating ? 'Stop Sim' : 'Simulate Run',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: runState.isSimulating ? AppColors.warningAmber : AppColors.electricLime,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    String message;
    IconData icon;
    Color color;

    final delta = runState.distanceDeltaMeters;
    if (runState.partnerState == RunParticipantState.paused) {
      message = '${runState.partnerName ?? 'Partner'} paused';
      icon = Icons.pause_circle_outline_rounded;
      color = AppColors.warningAmber;
    } else if (runState.partnerState == RunParticipantState.reconnecting) {
      message = '${runState.partnerName ?? 'Partner'} reconnecting...';
      icon = Icons.wifi_find_rounded;
      color = AppColors.warningAmber;
    } else if (delta.abs() < 25) {
      message = "You're running side-by-side!";
      icon = Icons.bolt_rounded;
      color = AppColors.electricLime;
    } else if (delta > 0) {
      message = "${runState.partnerName ?? 'Partner'} is ${delta.toInt()}m ahead";
      icon = Icons.arrow_upward_rounded;
      color = AppColors.buddyBlue;
    } else {
      message = "You're ${delta.abs().toInt()}m ahead";
      icon = Icons.star_rounded;
      color = AppColors.electricLime;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: notifier.toggleSimulation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: runState.isSimulating
                    ? AppColors.warningAmber.withValues(alpha: 0.15)
                    : AppColors.electricLime.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: runState.isSimulating ? AppColors.warningAmber : AppColors.electricLime,
                ),
              ),
              child: Text(
                runState.isSimulating ? 'Stop Sim' : 'Sim GPS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: runState.isSimulating ? AppColors.warningAmber : AppColors.electricLime,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMapContainer(RunStateModel runState) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSlateNavy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderNavy, width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapGridPainter(),
            ),
          ),

          // User Marker (Electric Lime)
          Align(
            alignment: const Alignment(-0.25, 0.25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.midnightNavy,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.electricLime),
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.electricLime,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.electricLime,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.electricLime.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Partner Marker if Together Run
          if (runState.type == RunType.together)
            Align(
              alignment: Alignment(
                0.25,
                -0.25 - (runState.distanceDeltaMeters / 500.0).clamp(-0.4, 0.4),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.midnightNavy,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.buddyBlue),
                    ),
                    child: Text(
                      runState.partnerName ?? 'BUDDY',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.buddyBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.buddyBlue,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.buddyBlue.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Live Floating Burst Particles
          Align(
            alignment: const Alignment(0.0, 0.5),
            child: Stack(
              clipBehavior: Clip.none,
              children: _particles.map((p) => _FloatingBurstParticle(key: p.key, data: p)).toList(),
            ),
          ),

          // Dynamic Top HUD Pill
          if (_hudMessage != null)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.midnightNavy.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _hudColor ?? AppColors.electricLime, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: (_hudColor ?? AppColors.electricLime).withValues(alpha: 0.40),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_hudIcon != null) ...[
                        Icon(_hudIcon, color: _hudColor ?? AppColors.electricLime, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _hudMessage!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    Color highlightColor = AppColors.textPrimary,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: highlightColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAthleticReactionRow(
      BuildContext context, RunStateModel runState, ActiveRunNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSlateNavy.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderNavy.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _kRunCheers.map((cheer) {
          return GestureDetector(
            onTap: () => _triggerCheer(cheer, runState, notifier),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.midnightNavy,
                border: Border.all(
                  color: cheer.color.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cheer.color.withValues(alpha: 0.20),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                cheer.icon,
                color: cheer.color,
                size: 20,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionControls(
      BuildContext context, RunStateModel runState, ActiveRunNotifier notifier) {
    final isPaused = runState.userState == RunParticipantState.paused;
    final isInitial = isPaused && runState.durationSeconds == 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isInitial)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, size: 16, color: AppColors.electricLime),
                SizedBox(width: 6),
                Text(
                  'TAP PLAY TO START RUN',
                  style: TextStyle(
                    color: AppColors.electricLime,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Finish / Cancel Button
            GestureDetector(
              onTap: () => _handleExitRequested(context, runState, notifier),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.errorCoral.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.errorCoral, width: 2),
                ),
                child: Icon(
                  isInitial ? Icons.close_rounded : Icons.stop_rounded,
                  size: 30,
                  color: AppColors.errorCoral,
                ),
              ),
            ),

            // Hero Play/Pause Button
            GestureDetector(
              onTap: notifier.toggleUserPause,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPaused ? AppColors.electricLime : AppColors.deepLime,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.electricLime.withValues(alpha: 0.4),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 44,
                  color: AppColors.midnightNavy,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getPartnerStateColor(RunParticipantState state) {
    switch (state) {
      case RunParticipantState.running:
        return AppColors.freshGreen;
      case RunParticipantState.paused:
        return AppColors.warningAmber;
      case RunParticipantState.reconnecting:
        return AppColors.warningAmber;
      case RunParticipantState.finished:
        return AppColors.textSecondary;
    }
  }

  String _partnerStateLabel(RunParticipantState state) {
    switch (state) {
      case RunParticipantState.running:
        return 'Running';
      case RunParticipantState.paused:
        return 'Paused';
      case RunParticipantState.reconnecting:
        return 'Reconnecting';
      case RunParticipantState.finished:
        return 'Finished';
    }
  }
}

class _FloatingBurstParticle extends StatefulWidget {
  final _ParticleData data;

  const _FloatingBurstParticle({required super.key, required this.data});

  @override
  State<_FloatingBurstParticle> createState() => _FloatingBurstParticleState();
}

class _FloatingBurstParticleState extends State<_FloatingBurstParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _yAnim;
  late Animation<double> _xAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _yAnim = Tween<double>(begin: 0.0, end: widget.data.driftY).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );

    _xAnim = Tween<double>(begin: 0.0, end: widget.data.driftX).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutQuad),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.3, end: 1.3), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 0.9), weight: 65),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _anim, curve: Curves.easeIn));

    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(widget.data.startX + _xAnim.value, _yAnim.value),
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(
              opacity: _opacityAnim.value.clamp(0.0, 1.0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.midnightNavy.withValues(alpha: 0.75),
                  boxShadow: [
                    BoxShadow(
                      color: widget.data.color.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  widget.data.icon,
                  color: widget.data.color,
                  size: widget.data.size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.borderNavy.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 32) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 32) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
