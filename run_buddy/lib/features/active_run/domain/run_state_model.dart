enum RunType {
  solo,
  together,
}

enum RunParticipantState {
  running,
  paused,
  reconnecting,
  finished,
}

class RunStateModel {
  final String id;
  final RunType type;
  final String? partnerId;
  final String? partnerName;
  final String? voiceToken;
  final String? voiceServerUrl;
  final RunParticipantState userState;
  final RunParticipantState partnerState;
  final double distanceKm;
  final int durationSeconds;
  final double paceSecondsPerKm;
  final double partnerDistanceKm;
  final int partnerDurationSeconds;
  final double partnerPaceSecondsPerKm;
  final double distanceDeltaMeters;
  final bool isVoiceConnected;
  final bool isMuted;
  final bool isSimulating;

  const RunStateModel({
    required this.id,
    required this.type,
    this.partnerId,
    this.partnerName,
    this.voiceToken,
    this.voiceServerUrl,
    this.userState = RunParticipantState.running,
    this.partnerState = RunParticipantState.running,
    this.distanceKm = 0.0,
    this.durationSeconds = 0,
    this.paceSecondsPerKm = 0.0,
    this.partnerDistanceKm = 0.0,
    this.partnerDurationSeconds = 0,
    this.partnerPaceSecondsPerKm = 0.0,
    this.distanceDeltaMeters = 0.0,
    this.isVoiceConnected = false,
    this.isMuted = false,
    this.isSimulating = false,
  });

  RunStateModel copyWith({
    String? id,
    RunType? type,
    String? partnerId,
    String? partnerName,
    String? voiceToken,
    String? voiceServerUrl,
    RunParticipantState? userState,
    RunParticipantState? partnerState,
    double? distanceKm,
    int? durationSeconds,
    double? paceSecondsPerKm,
    double? partnerDistanceKm,
    int? partnerDurationSeconds,
    double? partnerPaceSecondsPerKm,
    double? distanceDeltaMeters,
    bool? isVoiceConnected,
    bool? isMuted,
    bool? isSimulating,
  }) {
    return RunStateModel(
      id: id ?? this.id,
      type: type ?? this.type,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      voiceToken: voiceToken ?? this.voiceToken,
      voiceServerUrl: voiceServerUrl ?? this.voiceServerUrl,
      userState: userState ?? this.userState,
      partnerState: partnerState ?? this.partnerState,
      distanceKm: distanceKm ?? this.distanceKm,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      paceSecondsPerKm: paceSecondsPerKm ?? this.paceSecondsPerKm,
      partnerDistanceKm: partnerDistanceKm ?? this.partnerDistanceKm,
      partnerDurationSeconds: partnerDurationSeconds ?? this.partnerDurationSeconds,
      partnerPaceSecondsPerKm: partnerPaceSecondsPerKm ?? this.partnerPaceSecondsPerKm,
      distanceDeltaMeters: distanceDeltaMeters ?? this.distanceDeltaMeters,
      isVoiceConnected: isVoiceConnected ?? this.isVoiceConnected,
      isMuted: isMuted ?? this.isMuted,
      isSimulating: isSimulating ?? this.isSimulating,
    );
  }
}
