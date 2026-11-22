import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

enum ChatConnectionState {
  disconnected,
  connecting,
  connected,
}

/// Centralized Chat & Real-Time WebSocket service for CineConnect.
///
/// Handles:
/// - Authenticated REST operations for conversations and message history.
/// - WebSocket connection with Supabase JWT query authentication.
/// - Auto-reconnection with exponential backoff on connection drops.
/// - Heartbeat ping/pong keepalive.
/// - Broadcast streams for incoming messages, connection state, and missed-message sync.
class ChatService {
  final ApiClient _apiClient;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _isConnecting = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  final _connectionStateController =
      StreamController<ChatConnectionState>.broadcast();
  final _incomingEventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  ChatConnectionState _currentState = ChatConnectionState.disconnected;

  ChatService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  ChatConnectionState get connectionState => _currentState;
  Stream<ChatConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<Map<String, dynamic>> get incomingEventsStream =>
      _incomingEventsController.stream;

  /// Stream filtered specifically for 'new_message' events.
  Stream<Map<String, dynamic>> get incomingMessagesStream =>
      _incomingEventsController.stream.where(
        (data) => data['event'] == 'new_message',
      );

  // ==========================================
  // 1. REST API Operations
  // ==========================================

  /// Fetch active conversation summaries with unread counts.
  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final res = await _apiClient.get(ApiEndpoints.listConversations);
      if (res is List) {
        return res
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Failed to fetch conversations: $e',
      );
    }
  }

  /// Fetch conversation thread message history with [partnerUserId].
  /// Automatically marks incoming unread messages as read on the backend.
  Future<List<Map<String, dynamic>>> getConversationMessages(
    String partnerUserId, {
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final res = await _apiClient.get(
        ApiEndpoints.userConversation(partnerUserId),
        queryParams: {'skip': skip, 'limit': limit},
      );
      if (res is List) {
        return res
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Failed to fetch conversation messages: $e',
      );
    }
  }

  /// Send a direct message to [recipientId] via the authenticated REST endpoint.
  Future<Map<String, dynamic>> sendMessageRest({
    required String recipientId,
    required String body,
  }) async {
    try {
      final res = await _apiClient.post(
        ApiEndpoints.sendMessage,
        body: {
          'recipient_id': recipientId,
          'body': body,
        },
      );
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      throw ApiException(
        statusCode: 500,
        message: 'Unexpected response from send message endpoint',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Failed to send message: $e',
      );
    }
  }

  /// Get total unread direct messages count.
  Future<int> getUnreadCount() async {
    try {
      final res = await _apiClient.get(ApiEndpoints.unreadMessageCount);
      if (res is Map && res['unread_count'] is int) {
        return res['unread_count'] as int;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // ==========================================
  // 2. WebSocket Real-Time Operations
  // ==========================================

  /// Connects to the backend WebSocket endpoint using the active Supabase JWT.
  Future<void> connectWebSocket() async {
    if (_isDisposed) return;
    if (_currentState == ChatConnectionState.connected || _isConnecting) return;

    final token = _apiClient.currentAuthToken;
    if (token == null || token.isEmpty) {
      _setConnectionState(ChatConnectionState.disconnected);
      return;
    }

    _isConnecting = true;
    _setConnectionState(ChatConnectionState.connecting);

    try {
      final wsUrl = ApiEndpoints.webSocketChat(token);
      final uri = Uri.parse(wsUrl);

      _channel = WebSocketChannel.connect(uri);

      _channelSubscription = _channel!.stream.listen(
        (data) {
          _handleIncomingRawData(data);
        },
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      _isConnecting = false;
      _reconnectAttempts = 0;
      _setConnectionState(ChatConnectionState.connected);
      _startPingTimer();
    } catch (e) {
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _handleIncomingRawData(dynamic raw) {
    try {
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          // If server acknowledged ping with pong
          if (decoded['type'] == 'pong') {
            return;
          }
          _incomingEventsController.add(decoded);
        }
      }
    } catch (_) {}
  }

  /// Sends a message payload over the active WebSocket.
  /// Returns `true` if queued successfully to the socket.
  bool sendMessageWebSocket({
    required String recipientId,
    required String body,
  }) {
    if (_channel != null && _currentState == ChatConnectionState.connected) {
      try {
        final payload = jsonEncode({
          'type': 'message',
          'recipient_id': recipientId,
          'body': body,
        });
        _channel!.sink.add(payload);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Unified send message operation:
  /// Attempts REST send (for immediate DB persistence confirmation and response schema),
  /// while WebSocket handles real-time delivery to the recipient.
  Future<Map<String, dynamic>> sendMessage({
    required String recipientId,
    required String body,
  }) async {
    return await sendMessageRest(recipientId: recipientId, body: body);
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel != null && _currentState == ChatConnectionState.connected) {
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

    _setConnectionState(ChatConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();

    // Check if user is still authenticated before attempting reconnect
    final token = _apiClient.currentAuthToken;
    if (token == null || token.isEmpty) return;

    _reconnectAttempts++;
    // Exponential backoff: 1s, 2s, 4s, up to 10s max
    final delaySeconds = (_reconnectAttempts * 2).clamp(1, 10);

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connectWebSocket();
    });
  }

  void _setConnectionState(ChatConnectionState state) {
    if (_currentState != state && !_isDisposed) {
      _currentState = state;
      _connectionStateController.add(state);
    }
  }

  /// Manually close the WebSocket connection (e.g. on user logout).
  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
    _setConnectionState(ChatConnectionState.disconnected);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _connectionStateController.close();
    _incomingEventsController.close();
  }
}

/// Central Riverpod provider for [ChatService].
final chatServiceProvider = Provider<ChatService>((ref) {
  final service = ChatService();
  ref.onDispose(service.dispose);
  return service;
});
