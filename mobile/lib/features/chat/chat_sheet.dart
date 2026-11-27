import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';

class ChatSheet extends StatefulWidget {
  final CineAppState appState;

  const ChatSheet({super.key, required this.appState});

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  String? _selectedThreadId;
  String _searchQuery = '';
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    widget.appState.initChatService();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return;
      if (_selectedThreadId != null) {
        widget.appState.loadThreadMessages(_selectedThreadId!);
      } else {
        widget.appState.loadConversations();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    widget.appState.clearActiveThread();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String threadId) {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    widget.appState.sendChatMessage(threadId, text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _openThread(CineChatThread thread) {
    widget.appState.loadThreadMessages(thread.id);
    widget.appState.markChatThreadAsRead(thread.id);
    setState(() => _selectedThreadId = thread.id);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final activeThread = _selectedThreadId != null
        ? widget.appState.chatThreads.firstWhere(
            (t) => t.id == _selectedThreadId,
            orElse: () => widget.appState.chatThreads.first,
          )
        : null;

    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: CineColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
          ),
          border: Border(
            top: BorderSide(color: CineColors.border, width: 1.5),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CineColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildHeader(activeThread),
            const Divider(height: 1, color: CineColors.border),
            Expanded(
              child: _selectedThreadId == null
                  ? _buildInbox()
                  : _buildConversationView(activeThread!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(CineChatThread? activeThread) {
    if (activeThread != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 8, 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: CineColors.textPrimary),
              onPressed: () {
                widget.appState.clearActiveThread();
                setState(() => _selectedThreadId = null);
              },
            ),
            Stack(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: CineColors.surfaceElevated,
                  child: Text(
                    activeThread.avatar,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: CineColors.gold,
                    ),
                  ),
                ),
                if (activeThread.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981),
                        border: Border.all(color: CineColors.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeThread.participantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: CineColors.textPrimary,
                    ),
                  ),
                  Text(
                    activeThread.isOnline ? 'Active now' : activeThread.participantCraft,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: activeThread.isOnline
                          ? const Color(0xFF10B981)
                          : CineColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.call_outlined, color: CineColors.textPrimary, size: 20),
              onPressed: () => _showComingSoon('Voice calls'),
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined, color: CineColors.textPrimary, size: 22),
              onPressed: () => _showComingSoon('Video calls'),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: CineColors.textMuted),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: CineColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Chats',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: CineColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit_square, color: CineColors.textPrimary, size: 21),
            onPressed: () => _showComingSoon('New message'),
          ),
        ],
      ),
    );
  }

  Widget _buildInbox() {
    final onlineThreads = widget.appState.chatThreads.where((t) => t.isOnline).toList();
    final q = _searchQuery.toLowerCase().trim();
    final threads = widget.appState.chatThreads.where((t) {
      if (q.isEmpty) return true;
      return t.participantName.toLowerCase().contains(q) ||
          t.participantCraft.toLowerCase().contains(q) ||
          t.lastMessage.toLowerCase().contains(q);
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(fontSize: 13, color: CineColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search messages',
              hintStyle: const TextStyle(fontSize: 12.5, color: CineColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 19, color: CineColors.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 17, color: CineColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: CineColors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (q.isEmpty && onlineThreads.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Active now',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: CineColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: onlineThreads.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final thread = onlineThreads[index];
                return GestureDetector(
                  onTap: () => _openThread(thread),
                  child: SizedBox(
                    width: 58,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: CineColors.surfaceElevated,
                              child: Text(
                                thread.avatar,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: CineColors.gold,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 1,
                              right: 1,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF10B981),
                                  border: Border.all(color: CineColors.surface, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          thread.participantName.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: CineColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],
        InkWell(
          onTap: () => _showComingSoon('Message requests'),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: CineColors.surfaceElevated,
                  child: Icon(Icons.mark_email_unread_outlined, color: CineColors.gold, size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Message requests',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: CineColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: CineColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
        const Divider(height: 1, indent: 68, color: CineColors.border),
        if (threads.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No messages found',
                style: TextStyle(color: CineColors.textMuted, fontSize: 13),
              ),
            ),
          )
        else
          ...threads.map((thread) => _threadTile(thread)),
      ],
    );
  }

  Widget _threadTile(CineChatThread thread) {
    return InkWell(
      onTap: () => _openThread(thread),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: CineColors.surfaceElevated,
                  child: Text(
                    thread.avatar,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: CineColors.gold,
                    ),
                  ),
                ),
                if (thread.isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981),
                        border: Border.all(color: CineColors.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.participantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: thread.unreadCount > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: CineColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        thread.lastMessageTime,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: CineColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: thread.unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: thread.unreadCount > 0
                                ? CineColors.textPrimary
                                : CineColors.textMuted,
                          ),
                        ),
                      ),
                      if (thread.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: CineColors.gold,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${thread.unreadCount}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationView(CineChatThread thread) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            itemCount: thread.messages.length,
            itemBuilder: (context, index) {
              final msg = thread.messages[index];
              return Align(
                alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.76,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: msg.isMe ? CineColors.gold : CineColors.surfaceElevated,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(msg.isMe ? 18 : 4),
                      bottomRight: Radius.circular(msg.isMe ? 4 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text,
                        style: TextStyle(
                          fontSize: 13,
                          color: msg.isMe ? Colors.black : CineColors.textPrimary,
                          fontWeight: msg.isMe ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        msg.time,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: msg.isMe
                              ? Colors.black.withValues(alpha: 0.55)
                              : CineColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(
              color: CineColors.surface,
              border: Border(top: BorderSide(color: CineColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: CineColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CineColors.gold, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: CineColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: TextStyle(color: CineColors.textMuted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(thread.id),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send, color: CineColors.gold, size: 22),
                  onPressed: () => _sendMessage(thread.id),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CineColors.surfaceElevated,
        content: Text(
          '$feature coming soon',
          style: const TextStyle(color: CineColors.gold),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
