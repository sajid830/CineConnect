import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
}

/// Real-time asynchronous event client for CineConnect.
///
/// Connects to `/ws/events` using the active Supabase JWT, maintains heartbeat
/// keepalive + exponential backoff reconnects, and broadcasts server-pushed
/// release and application events so UI lists update immediately.
class RealtimeEventsService {
  static final RealtimeEventsService instance = RealtimeEventsService();

  static const Set<String> releaseEventTypes = {
    'opportunity_released',
    'opportunity_updated',
    'opportunity_deleted',
    'project_released',
    'project_updated',
    'project_deleted',
  };

  static const Set<String> applicationEventTypes = {
    'application_created',
    'application_updated',
    'application_withdrawn',
    'application_status_updated',
  };

  final ApiClient _apiClient;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _isConnecting = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  String? _connectedToken;
  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;

  final _stateController = StreamController<RealtimeConnectionState>.broadcast();
  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();

  RealtimeEventsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  RealtimeConnectionState get connectionState => _state;
  bool get isConnected => _state == RealtimeConnectionState.connected;
  Stream<RealtimeConnectionState> get connectionStateStream =>
      _stateController.stream;
  Stream<Map<String, dynamic>> get eventsStream => _eventsController.stream;

  /// Emits whenever a job/opportunity or project is released, updated, or deleted.
  Stream<Map<String, dynamic>> get releaseEventsStream =>
      _eventsController.stream.where(
        (data) => releaseEventTypes.contains(data['event']?.toString()),
      );

  /// Emits whenever an application is submitted, updated, withdrawn, or its status changes.
  Stream<Map<String, dynamic>> get applicationEventsStream =>
      _eventsController.stream.where(
        (data) => applicationEventTypes.contains(data['event']?.toString()),
      );

  /// Emits for any job/project release or application mutation event.
  Stream<Map<String, dynamic>> get releaseOrApplicationEventsStream =>
      _eventsController.stream.where((data) {
        final evt = data['event']?.toString();
        return releaseEventTypes.contains(evt) ||
            applicationEventTypes.contains(evt);
      });

  Future<void> connect() async {
    if (_isDisposed) return;

    final token = _apiClient.currentAuthToken;
    if (token == null || token.isEmpty) {
      if (_state != RealtimeConnectionState.disconnected) {
        disconnect();
      } else {
        _setState(RealtimeConnectionState.disconnected);
      }
      return;
    }

    if (_state == RealtimeConnectionState.connected && _connectedToken == token) {
      return;
    }
    if (_isConnecting && _connectedToken == token) {
      return;
    }
    if (_state != RealtimeConnectionState.disconnected) {
      disconnect();
    }

    _connectedToken = token;
    _isConnecting = true;
    _setState(RealtimeConnectionState.connecting);

    try {
      final wsUrl = ApiEndpoints.webSocketEvents(token);
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      _channelSubscription = _channel!.stream.listen(
        _handleRawMessage,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
        cancelOnError: true,
      );

      _isConnecting = false;
      _reconnectAttempts = 0;
      _setState(RealtimeConnectionState.connected);
      _startPingTimer();
    } catch (_) {
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _handleRawMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString();
        final evt = decoded['event']?.toString();
        if (type == 'pong' || evt == 'heartbeat') {
          return;
        }
        _eventsController.add(decoded);
      }
    } catch (_) {}
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_channel != null && _state == RealtimeConnectionState.connected) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;

    if (_isDisposed) return;

    _setState(RealtimeConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();

    final token = _apiClient.currentAuthToken;
    if (token == null || token.isEmpty) return;

    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(1, 10);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  void _setState(RealtimeConnectionState next) {
    if (_state != next && !_isDisposed) {
      _state = next;
      _stateController.add(next);
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
    _connectedToken = null;
    _isConnecting = false;
    _setState(RealtimeConnectionState.disconnected);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _stateController.close();
    _eventsController.close();
  }
}

final realtimeEventsServiceProvider = Provider<RealtimeEventsService>((ref) {
  return RealtimeEventsService.instance;
});
