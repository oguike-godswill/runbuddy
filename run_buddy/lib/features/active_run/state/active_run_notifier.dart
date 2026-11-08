import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/location/gps_engine.dart';
import '../../../core/location/gps_point.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/realtime/realtime_run_client.dart';
import '../../auth/state/auth_notifier.dart';
import '../../runs/presentation/run_history_page.dart';
import '../../voice/livekit_voice_manager.dart';
import '../domain/run_state_model.dart';

class ActiveRunNotifier extends StateNotifier<RunStateModel> {
  final Ref ref;
  final GpsEngine _gpsEngine = GpsEngine();
  final RealtimeRunClient _realtimeClient = RealtimeRunClient();
  final LiveKitVoiceManager _voiceManager = LiveKitVoiceManager();

  StreamSubscription<GpsPoint>? _gpsSub;
  Timer? _durationTimer;
  StreamController<String>? _reactionStreamController;
  StreamController<String> get _reactionController =>
      _reactionStreamController ??= StreamController<String>.broadcast();

  Stream<String> get reactionStream => _reactionController.stream;

  void sendReaction(String reactionKey) {
    final user = ref.read(authProvider);
    if (user != null && state.type == RunType.together) {
      _realtimeClient.sendReaction(
        runId: state.id,
        userId: user.id,
        emoji: reactionKey,
      );
    }
  }

  ActiveRunNotifier(this.ref)
      : super(const RunStateModel(
          id: '',
          type: RunType.solo,
        ));

  void initSession({
    required String runId,
    required RunType type,
    String? partnerId,
    String? partnerName,
    String? voiceToken,
    String? voiceServerUrl,
  }) async {
    // Reset previous run resources
    disposeRun();
    _gpsEngine.reset();

    final initialPaused = (type == RunType.solo);

    state = RunStateModel(
      id: runId,
      type: type,
      partnerId: partnerId,
      partnerName: partnerName,
      voiceToken: voiceToken,
      voiceServerUrl: voiceServerUrl,
      userState: initialPaused ? RunParticipantState.paused : RunParticipantState.running,
      partnerState: type == RunType.together ? RunParticipantState.running : RunParticipantState.finished,
    );

    final user = ref.read(authProvider);

    // 1. Connect WebRTC Voice if shared run
    if (type == RunType.together && voiceToken != null && voiceServerUrl != null) {
      final voiceOk = await _voiceManager.connect(serverUrl: voiceServerUrl, token: voiceToken);
      state = state.copyWith(isVoiceConnected: voiceOk);
    }

    // 2. Setup Authenticated WebSocket
    if (type == RunType.together && user != null) {
      _realtimeClient.onPartnerTelemetry = (data) {
        final pDist = (data['distanceKm'] as num?)?.toDouble() ?? state.partnerDistanceKm;
        final pPace = (data['averagePaceSeconds'] as num?)?.toDouble() ?? state.partnerPaceSecondsPerKm;
        final pDur = (data['durationSeconds'] as num?)?.toInt() ?? state.partnerDurationSeconds;
        final delta = (pDist - state.distanceKm) * 1000.0;

        state = state.copyWith(
          partnerDistanceKm: pDist,
          partnerPaceSecondsPerKm: pPace,
          partnerDurationSeconds: pDur,
          distanceDeltaMeters: delta,
          partnerState: RunParticipantState.running,
        );
      };

      _realtimeClient.onPartnerStatus = (status) {
        if (status == 'PAUSED') {
          state = state.copyWith(partnerState: RunParticipantState.paused);
        } else if (status == 'RUNNING') {
          state = state.copyWith(partnerState: RunParticipantState.running);
        } else if (status == 'FINISHED') {
          state = state.copyWith(partnerState: RunParticipantState.finished);
        }
      };

      _realtimeClient.onPartnerReaction = (reaction) {
        _reactionController.add(reaction);
      };

      _realtimeClient.connect(runId: runId, userId: user.id, token: user.accessToken);
    }

    // 3. Setup GPS & Stream Tracking
    _gpsSub = _gpsEngine.pointStream.listen((point) {
      if (state.userState != RunParticipantState.running) return;

      final newDist = _gpsEngine.totalDistanceKm;
      double currentPace = 0.0;
      if (newDist > 0.05 && state.durationSeconds > 0) {
        currentPace = state.durationSeconds / newDist;
      }

      final delta = (state.partnerDistanceKm - newDist) * 1000.0;

      state = state.copyWith(
        distanceKm: newDist,
        paceSecondsPerKm: currentPace,
        distanceDeltaMeters: delta,
      );

      // Relay live GPS telemetry to partner over WebSocket
      if (state.type == RunType.together && user != null) {
        _realtimeClient.broadcastLocation(
          runId: state.id,
          userId: user.id,
          point: point,
          distanceKm: newDist,
          durationSeconds: state.durationSeconds,
          paceSeconds: currentPace,
        );
      }
    });

    final hasPerm = await _gpsEngine.requestPermissions();
    if (hasPerm) {
      _gpsEngine.startTracking();
      if (initialPaused) {
        _gpsEngine.pauseTracking();
      }
    }

    // 4. Timer for Duration
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.userState == RunParticipantState.running) {
        state = state.copyWith(durationSeconds: state.durationSeconds + 1);
      }
    });
  }

  void toggleSimulation() {
    _gpsEngine.toggleSimulation();
    state = state.copyWith(isSimulating: _gpsEngine.isSimulating);
  }

  void toggleUserPause() {
    final user = ref.read(authProvider);
    if (state.userState == RunParticipantState.running) {
      state = state.copyWith(userState: RunParticipantState.paused);
      _gpsEngine.pauseTracking();
      if (user != null && state.type == RunType.together) {
        _realtimeClient.pause(runId: state.id, userId: user.id);
      }
    } else if (state.userState == RunParticipantState.paused) {
      state = state.copyWith(userState: RunParticipantState.running);
      _gpsEngine.resumeTracking();
      if (user != null && state.type == RunType.together) {
        _realtimeClient.resume(runId: state.id, userId: user.id);
      }
    }
  }

  void toggleVoiceMute() async {
    await _voiceManager.toggleMute();
    state = state.copyWith(isMuted: _voiceManager.isMuted);
  }

  Future<void> finishRun() async {
    final user = ref.read(authProvider);
    state = state.copyWith(userState: RunParticipantState.finished);

    _gpsEngine.stopTracking();
    _durationTimer?.cancel();

    if (user != null) {
      int safePace = 0;
      if (!state.paceSecondsPerKm.isNaN && !state.paceSecondsPerKm.isInfinite && state.paceSecondsPerKm > 0) {
        safePace = state.paceSecondsPerKm.toInt();
      }
      double safeDist = 0.0;
      if (!state.distanceKm.isNaN && !state.distanceKm.isInfinite && state.distanceKm > 0) {
        safeDist = double.parse(state.distanceKm.toStringAsFixed(3));
      }

      // 1. Immediate optimistic update so dashboard and profile instantly reflect the new run
      final optimisticRuns = user.totalRuns + 1;
      final optimisticDist = user.totalDistanceKm + safeDist;
      ref.read(authProvider.notifier).updateStats(
        totalRuns: optimisticRuns,
        totalDistanceKm: optimisticDist,
      );
      ref.invalidate(runHistoryProvider);

      if (state.type == RunType.together) {
        _realtimeClient.finish(runId: state.id, userId: user.id);
      }

      // 2. Authoritative persistence in PostgreSQL
      try {
        final res = await http.post(
          Uri.parse('${ApiEndpoints.runs}/complete'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${user.accessToken}',
          },
          body: jsonEncode({
            'runId': state.id,
            'type': state.type == RunType.together ? 'TOGETHER' : 'SOLO',
            'distanceKm': safeDist,
            'durationSeconds': state.durationSeconds,
            'paceSeconds': safePace,
          }),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final stats = data['stats'];
          if (stats != null) {
            final authRuns = int.tryParse('${stats['total_runs']}') ?? optimisticRuns;
            final authDist = double.tryParse('${stats['total_distance_km']}') ?? optimisticDist;
            ref.read(authProvider.notifier).updateStats(
              totalRuns: authRuns,
              totalDistanceKm: authDist,
            );
            ref.invalidate(runHistoryProvider);
          }
        }
      } catch (_) {}
    }
  }

  void disposeRun() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _gpsSub?.cancel();
    _gpsSub = null;
    _gpsEngine.stopTracking();
    _realtimeClient.disconnect();
    _voiceManager.disconnect();
  }

  @override
  void dispose() {
    disposeRun();
    _reactionStreamController?.close();
    super.dispose();
  }
}

final activeRunProvider =
    StateNotifierProvider<ActiveRunNotifier, RunStateModel>((ref) {
  return ActiveRunNotifier(ref);
});
