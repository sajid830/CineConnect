import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/network/api_client.dart';
import 'package:cineconnect/core/services/chat_service.dart';
import 'package:cineconnect/features/production_house/data/models/chat_message.dart';
import 'package:cineconnect/features/production_house/data/repositories/chat_repository.dart';
import 'package:cineconnect/features/production_house/collaboration/collaborations_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String collaborationId;

  const ChatScreen({super.key, required this.collaborationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _error = false;
  bool _sending = false;
  StreamSubscription<ChatMessage>? _subscription;
  StreamSubscription<ChatConnectionState>? _connSubscription;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(chatRepositoryProvider);
    _subscription = repo.incoming(widget.collaborationId).listen((message) {
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == message.id)) {
            _messages = [..._messages, message];
          }
        });
      }
    });

    final chatService = ref.read(chatServiceProvider);
    _connSubscription = chatService.connectionStateStream.listen((state) {
      if (state == ChatConnectionState.connected && _messages.isNotEmpty) {
        // Reconnected: recover any messages potentially missed while disconnected
        _refreshQuietly();
      }
    });

    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connSubscription?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.collaborationId.isEmpty || widget.collaborationId == 'general') {
      setState(() {
        _loading = false;
        _messages = [];
        _error = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final list =
          await ref.read(chatRepositoryProvider).getMessages(widget.collaborationId);
      if (mounted) setState(() => _messages = list);
    } catch (e) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshQuietly() async {
    try {
      final list =
          await ref.read(chatRepositoryProvider).getMessages(widget.collaborationId);
      if (mounted) setState(() => _messages = list);
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    _inputController.clear();
    setState(() => _sending = true);
    try {
      final sent =
          await ref.read(chatRepositoryProvider).send(widget.collaborationId, text);
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == sent.id)) {
            _messages = [..._messages, sent];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _inputController.text = text;
        final errorMsg = (e is ApiException && e.message.isNotEmpty)
            ? e.message
            : 'Message not sent. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(collaborationsProvider).maybeWhen(
          data: (list) => list
              .where((c) => c.id == widget.collaborationId)
              .map((c) => c.talent.fullName)
              .firstOrNull,
          orElse: () => null,
        );

    return Scaffold(
      appBar: AppBar(title: Text(name ?? 'Chat')),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load messages'),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet. Say hello!',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    final reversed = _messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: reversed.length,
      itemBuilder: (context, index) => _Bubble(message: reversed[index]),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Type a message'),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
              color: AppColors.gold,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final t = message.sentAt;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: mine ? AppColors.gold : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.body,
              style: TextStyle(
                color: mine ? AppColors.black : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: mine ? AppColors.black : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}