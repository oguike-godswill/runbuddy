import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/route_names.dart';
import '../../../app/theme/colors.dart';
import '../../active_run/state/active_run_notifier.dart';

class RunLobbyPage extends ConsumerStatefulWidget {
  const RunLobbyPage({super.key});

  @override
  ConsumerState<RunLobbyPage> createState() => _RunLobbyPageState();
}

class _RunLobbyPageState extends ConsumerState<RunLobbyPage> {
  bool _isUserReady = false;
  bool _isPartnerReady = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Simulate partner readiness after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isPartnerReady = true;
        });
        _checkStartCountdown();
      }
    });
  }

  void _toggleUserReady() {
    setState(() {
      _isUserReady = !_isUserReady;
    });
    _checkStartCountdown();
  }

  void _checkStartCountdown() {
    if (_isUserReady && _isPartnerReady && _countdown == 0) {
      setState(() {
        _countdown = 3;
      });
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_countdown <= 1) {
          timer.cancel();
          if (mounted) {
            context.pushReplacement(RouteNames.activeRun);
          }
        } else {
          if (mounted) {
            setState(() {
              _countdown--;
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(activeRunProvider);

    return Scaffold(
      backgroundColor: AppColors.midnightNavy,
      appBar: AppBar(
        title: const Text('Shared Run Lobby'),
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
              // Lobby Status Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSlateNavy,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_tethering_rounded,
                        color: AppColors.freshGreen, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Realtime WebSocket Connected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Countdown Overlay if Active
              if (_countdown > 0)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_countdown',
                        style: const TextStyle(
                          fontSize: 96,
                          fontWeight: FontWeight.w900,
                          color: AppColors.electricLime,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'GET READY TO RUN!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Participants Readiness Cards
                Row(
                  children: [
                    // You Card
                    Expanded(
                      child: _buildParticipantCard(
                        name: 'You',
                        role: 'Host',
                        color: AppColors.electricLime,
                        isReady: _isUserReady,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Buddy Card
                    Expanded(
                      child: _buildParticipantCard(
                        name: runState.partnerName ?? 'Companion',
                        role: 'Companion',
                        color: AppColors.buddyBlue,
                        isReady: _isPartnerReady,
                      ),
                    ),
                  ],
                ),

              const Spacer(),

              // Voice setting card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceNavy,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.borderNavy),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.headset_mic_rounded, color: AppColors.electricLime),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WebRTC Voice Room', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('Auto-connect on run start', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Switch(
                      value: true,
                      onChanged: (val) {},
                      activeThumbColor: AppColors.electricLime,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Ready CTA Button
              ElevatedButton(
                onPressed: _countdown > 0 ? null : _toggleUserReady,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isUserReady ? AppColors.surfaceSlateNavy : AppColors.electricLime,
                  foregroundColor: _isUserReady ? AppColors.electricLime : AppColors.midnightNavy,
                  side: _isUserReady ? const BorderSide(color: AppColors.electricLime, width: 2) : BorderSide.none,
                ),
                child: Text(
                  _isUserReady ? 'WAITING FOR PARTNER...' : "I'M READY",
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantCard({
    required String name,
    required String role,
    required Color color,
    required bool isReady,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReady ? color : AppColors.borderNavy,
          width: isReady ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(Icons.person_rounded, size: 36, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            role,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isReady
                  ? AppColors.freshGreen.withValues(alpha: 0.15)
                  : AppColors.surfaceSlateNavy,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isReady ? AppColors.freshGreen : AppColors.borderNavy,
              ),
            ),
            child: Text(
              isReady ? 'READY' : 'PREPARING',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isReady ? AppColors.freshGreen : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

