import 'package:livekit_client/livekit_client.dart';

class LiveKitVoiceManager {
  Room? _room;
  bool _isMuted = false;

  bool get isConnected => _room?.connectionState == ConnectionState.connected;
  bool get isMuted => _isMuted;

  Future<bool> connect({
    required String serverUrl,
    required String token,
  }) async {
    try {
      await disconnect();

      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            dtx: true, // Discontinuous transmission for battery & bandwidth savings
          ),
        ),
      );
      await _room!.connect(serverUrl, token);

      // Enable microphone by default
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      _isMuted = false;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> toggleMute() async {
    if (_room == null || _room!.localParticipant == null) return;
    _isMuted = !_isMuted;
    await _room!.localParticipant?.setMicrophoneEnabled(!_isMuted);
  }

  Future<void> disconnect() async {
    if (_room != null) {
      await _room!.disconnect();
      await _room!.dispose();
      _room = null;
    }
    _isMuted = false;
  }
}

