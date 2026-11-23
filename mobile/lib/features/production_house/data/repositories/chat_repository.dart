import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/chat_service.dart';
import '../models/chat_message.dart';
import 'collaboration_repository.dart';

abstract class ChatRepository {
  Future<List<ChatMessage>> getMessages(String collaborationId);

  Future<ChatMessage> send(String collaborationId, String body);

  /// Messages from the other person, pushed as they arrive.
  Stream<ChatMessage> incoming(String collaborationId);

  void dispose();
}

class RemoteChatRepository implements ChatRepository {
  final ChatService _chatService;
  final CollaborationRepository _collaborationRepository;
  final StreamController<ChatMessage> _incomingController =
      StreamController<ChatMessage>.broadcast();
  StreamSubscription? _wsSubscription;
  final Map<String, String> _collabToTalentMap = {};

  RemoteChatRepository({
    required ChatService chatService,
    required CollaborationRepository collaborationRepository,
  })  : _chatService = chatService,
        _collaborationRepository = collaborationRepository {
    _initWsListener();
  }

  void _initWsListener() {
    _chatService.connectWebSocket();
    _wsSubscription = _chatService.incomingMessagesStream.listen((event) {
      final currentUserId = ApiClient.currentUserId;
      final msgId = event['message_id']?.toString() ?? '';
      final senderId = event['sender_id']?.toString() ?? '';
      final recipientId = event['recipient_id']?.toString() ?? '';
      final body = event['body']?.toString() ?? '';
      final createdAt = DateTime.tryParse(event['created_at']?.toString() ?? '') ??
          DateTime.now();

      // Find if this event corresponds to any collaboration known to us
      String? matchedCollabId;
      for (final entry in _collabToTalentMap.entries) {
        if (entry.value == senderId || entry.value == recipientId) {
          matchedCollabId = entry.key;
          break;
        }
      }
      matchedCollabId ??= senderId;

      final isMine = currentUserId != null && senderId == currentUserId;

      _incomingController.add(
        ChatMessage(
          id: msgId,
          collaborationId: matchedCollabId,
          body: body,
          sentAt: createdAt,
          isMine: isMine,
        ),
      );
    });
  }

  Future<String> _resolvePartnerUserId(String collaborationId) async {
    if (_collabToTalentMap.containsKey(collaborationId)) {
      return _collabToTalentMap[collaborationId]!;
    }

    try {
      final collabs = await _collaborationRepository.getCollaborations();
      for (final c in collabs) {
        _collabToTalentMap[c.id] = c.talent.id;
      }
      if (_collabToTalentMap.containsKey(collaborationId)) {
        return _collabToTalentMap[collaborationId]!;
      }
    } catch (_) {}

    // Fallback: If collaborationId is directly a user ID
    _collabToTalentMap[collaborationId] = collaborationId;
    return collaborationId;
  }

  @override
  Future<List<ChatMessage>> getMessages(String collaborationId) async {
    final partnerUserId = await _resolvePartnerUserId(collaborationId);
    await _chatService.connectWebSocket();

    final rawList = await _chatService.getConversationMessages(partnerUserId);
    final currentUserId = ApiClient.currentUserId;

    return rawList.map((m) {
      final senderId = m['sender_id']?.toString() ?? '';
      final createdAt = DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now();
      return ChatMessage(
        id: m['id']?.toString() ?? '',
        collaborationId: collaborationId,
        body: m['body']?.toString() ?? '',
        sentAt: createdAt,
        isMine: currentUserId != null && senderId == currentUserId,
      );
    }).toList();
  }

  @override
  Future<ChatMessage> send(String collaborationId, String body) async {
    final partnerUserId = await _resolvePartnerUserId(collaborationId);
    final res = await _chatService.sendMessage(
      recipientId: partnerUserId,
      body: body,
    );

    final msgId = res['id']?.toString() ?? '';
    final createdAt = DateTime.tryParse(res['created_at']?.toString() ?? '') ??
        DateTime.now();

    return ChatMessage(
      id: msgId,
      collaborationId: collaborationId,
      body: body,
      sentAt: createdAt,
      isMine: true,
    );
  }

  @override
  Stream<ChatMessage> incoming(String collaborationId) {
    _chatService.connectWebSocket();
    return _incomingController.stream.where((m) {
      final partnerId = _collabToTalentMap[collaborationId] ?? collaborationId;
      return m.collaborationId == collaborationId ||
          m.collaborationId == partnerId;
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _incomingController.close();
  }
}

class MockChatRepository implements ChatRepository {
  final _controller = StreamController<ChatMessage>.broadcast();
  int _counter = 0;

  final Map<String, List<ChatMessage>> _store = {
    'c1': [
      ChatMessage(
        id: 'm1',
        collaborationId: 'c1',
        body: 'Hi Rohan, welcome to Midnight Express. Shoot starts in September.',
        sentAt: DateTime.now().subtract(const Duration(days: 2)),
        isMine: true,
      ),
      ChatMessage(
        id: 'm2',
        collaborationId: 'c1',
        body: 'Thank you! Happy to be on board. Can you share the schedule?',
        sentAt: DateTime.now().subtract(const Duration(days: 2, minutes: -5)),
        isMine: false,
      ),
    ],
  };

  static const _replies = [
    'Sounds good!',
    'Got it, thanks for letting me know.',
    'Can we talk about this tomorrow?',
    'Perfect, I will be there.',
  ];

  @override
  Future<List<ChatMessage>> getMessages(String collaborationId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.of(_store[collaborationId] ?? const []);
  }

  @override
  Future<ChatMessage> send(String collaborationId, String body) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final message = ChatMessage(
      id: 'mock-${_counter++}',
      collaborationId: collaborationId,
      body: body,
      sentAt: DateTime.now(),
      isMine: true,
    );
    _store.putIfAbsent(collaborationId, () => []).add(message);
    _simulateReply(collaborationId);
    return message;
  }

  void _simulateReply(String collaborationId) {
    Future.delayed(const Duration(seconds: 2), () {
      if (_controller.isClosed) return;
      final reply = ChatMessage(
        id: 'mock-${_counter++}',
        collaborationId: collaborationId,
        body: _replies[_counter % _replies.length],
        sentAt: DateTime.now(),
        isMine: false,
      );
      _store[collaborationId]!.add(reply);
      _controller.add(reply);
    });
  }

  @override
  Stream<ChatMessage> incoming(String collaborationId) {
    return _controller.stream.where((m) => m.collaborationId == collaborationId);
  }

  @override
  void dispose() => _controller.close();
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  const useMock = bool.fromEnvironment('USE_MOCK_PH', defaultValue: true);
  if (useMock) {
    return MockChatRepository();
  }
  final chatService = ref.watch(chatServiceProvider);
  final colRepo = ref.watch(collaborationRepositoryProvider);
  final repo = RemoteChatRepository(
    chatService: chatService,
    collaborationRepository: colRepo,
  );
  ref.onDispose(repo.dispose);
  return repo;
});