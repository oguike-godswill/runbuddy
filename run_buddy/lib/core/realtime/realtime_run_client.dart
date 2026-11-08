import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../location/gps_point.dart';
import '../network/api_endpoints.dart';

typedef TelemetryCallback = void Function(Map<String, dynamic> data);
typedef PartnerStatusCallback = void Function(String status);
typedef ReactionCallback = void Function(String emoji);

class RealtimeRunClient {
  final String? _explicitServerUrl;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  String? _authToken;

  TelemetryCallback? onPartnerTelemetry;
  PartnerStatusCallback? onPartnerStatus;
  ReactionCallback? onPartnerReaction;
  void Function()? onCountdownStart;
  void Function()? onAllCompleted;

  RealtimeRunClient({String? serverUrl}) : _explicitServerUrl = serverUrl;

  String get serverUrl => _explicitServerUrl ?? ApiEndpoints.wsUrl;

  bool get isConnected => _isConnected;

  void connect({required String runId, required String userId, String? token}) {
    disconnect();
    _authToken = token;

    try {
      final uri = Uri.parse(serverUrl);
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _subscription = _channel?.stream.listen(
        (message) {
          try {
            final payload = jsonDecode(message as String);
            _handleIncomingEvent(payload);
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
        },
        onError: (err) {
          _isConnected = false;
        },
      );

      // Join run with authentication token
      sendEvent('run.join', {
        'runId': runId,
        'userId': userId,
      });
    } catch (e) {
      _isConnected = false;
    }
  }

  void _handleIncomingEvent(Map<String, dynamic> payload) {
    final eventType = payload['eventType'] as String?;
    switch (eventType) {
      case 'run.partner_telemetry':
        onPartnerTelemetry?.call(payload);
        break;
      case 'run.partner_paused':
        onPartnerStatus?.call('PAUSED');
        break;
      case 'run.partner_resumed':
        onPartnerStatus?.call('RUNNING');
        break;
      case 'run.partner_finished':
        onPartnerStatus?.call('FINISHED');
        break;
      case 'run.countdown_start':
        onCountdownStart?.call();
        break;
      case 'run.all_completed':
        onAllCompleted?.call();
        break;
      case 'run.reaction':
        if (payload['emoji'] != null) {
          onPartnerReaction?.call(payload['emoji'] as String);
        }
        break;
    }
  }

  void markReady({required String runId, required String userId}) {
    sendEvent('run.ready', {'runId': runId, 'userId': userId});
  }

  void broadcastLocation({
    required String runId,
    required String userId,
    required GpsPoint point,
    required double distanceKm,
    required int durationSeconds,
    required double paceSeconds,
  }) {
    sendEvent('run.location', {
      'runId': runId,
      'userId': userId,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'speedMps': point.speedMps,
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'averagePaceSeconds': paceSeconds,
    });
  }

  void pause({required String runId, required String userId}) {
    sendEvent('run.pause', {'runId': runId, 'userId': userId});
  }

  void resume({required String runId, required String userId}) {
    sendEvent('run.resume', {'runId': runId, 'userId': userId});
  }

  void finish({required String runId, required String userId}) {
    sendEvent('run.finish', {'runId': runId, 'userId': userId});
  }

  void sendReaction({required String runId, required String userId, required String emoji}) {
    sendEvent('run.reaction', {'runId': runId, 'userId': userId, 'emoji': emoji});
  }

  void sendEvent(String eventType, Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      data['eventType'] = eventType;
      if (_authToken != null) {
        data['token'] = _authToken;
      }
      _channel?.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _authToken = null;
  }
}

