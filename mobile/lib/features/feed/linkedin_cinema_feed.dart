import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';
import '../stories/story_status_bar.dart';

class LinkedInCinemaFeed extends StatefulWidget {
  final CineAppState appState;

  const LinkedInCinemaFeed({super.key, required this.appState});

  @override
  State<LinkedInCinemaFeed> createState() => _LinkedInCinemaFeedState();
}

class _LinkedInCinemaFeedState extends State<LinkedInCinemaFeed> {
  late final ScrollController _scrollController;
  final Set<String> _pendingLikeToggles = {};

  // Map of post IDs to their current aspect ratio (2.39:1 vs 16:9)
  final Map<String, bool> _isScopeMode = {};
  final Map<String, bool> _followedAuthors = {};
  final Map<String, bool> _bookmarkedPosts = {};
  final Set<String> _blockedAuthors = {};
  final Map<String, List<Map<String, dynamic>>> _postComments = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      widget.appState.loadMoreFeedPosts();
    }
  }

  List<Map<String, dynamic>> _getCommentsForPost(CineFeedPost post) {
    return _postComments.putIfAbsent(post.id, () {
      if (post.id == 'post-1') {
        return [
          {
            'author': 'Liam Rossi',
            'avatar': 'LR',
            'time': '2h ago',
            'text': 'The Cooke anamorphic roll-off in the deep shadows is cinematic perfection. Brilliant work Maya!',
            'likes': 14,
            'isLiked': false,
          },
          {
            'author': 'Elena Vance',
            'avatar': 'EV',
            'time': '1h ago',
            'text': 'Stunning frame composition! That 2.39:1 master shot is phenomenal.',
            'likes': 8,
            'isLiked': false,
          },
          {
            'author': 'Alex Chen',
            'avatar': 'AC',
            'time': '35m ago',
            'text': 'Tremendous discipline on this 38-night schedule! Pure dedication 🔥',
            'likes': 5,
            'isLiked': false,
          },
        ];
      } else {
        return [
          {
            'author': 'Maya Ray',
            'avatar': 'MR',
            'time': '4h ago',
            'text': 'Pure cinema! The one-take stunt was unbelievable Alex 👏',
            'likes': 12,
            'isLiked': false,
          },
          {
            'author': 'Karthik Raja',
            'avatar': 'KR',
            'time': '3h ago',
            'text': 'Color grade and shadow detail look crisp. Which camera package?',
            'likes': 6,
            'isLiked': false,
          },
        ];
      }
    });
  }

  void _openCreatorProfile(CineFeedPost post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatorProfileScreen(
          post: post,
          appState: widget.appState,
          isFollowed: _followedAuthors[post.id] ?? false,
          onToggleFollow: (val) {
            setState(() {
              _followedAuthors[post.id] = val;
            });
          },
        ),
      ),
    );
  }

  void _showPostOptionsSheet(CineFeedPost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CineColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CineColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: CineColors.error),
                title: Text(
                  'Block ${post.authorName}',
                  style: const TextStyle(
                    color: CineColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'You will no longer see posts or updates from ${post.authorName}.',
                  style: const TextStyle(color: CineColors.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _blockedAuthors.add(post.authorName);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: CineColors.surfaceElevated,
                      content: Text(
                        '${post.authorName} has been blocked and removed from your feed.',
                        style: const TextStyle(color: CineColors.error),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: CineColors.gold),
                title: const Text(
                  'Report Post',
                  style: TextStyle(
                    color: CineColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Report inappropriate content, spam, or copyright violation.',
                  style: TextStyle(color: CineColors.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog(post);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close_rounded, color: CineColors.textMuted),
                title: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(CineFeedPost post) {
    String selectedReason = 'Inappropriate or offensive content';
    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: CineColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: CineColors.border),
          ),
          title: const Row(
            children: [
              Icon(Icons.flag_outlined, color: CineColors.gold, size: 22),
              SizedBox(width: 8),
              Text(
                'Report Post',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CineColors.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Why are you reporting this post?',
                style: TextStyle(fontSize: 12, color: CineColors.textMuted),
              ),
              const SizedBox(height: 10),
              ...[
                'Inappropriate or offensive content',
                'Spam or misleading information',
                'Copyright or IP infringement',
                'Harassment or hate speech',
              ].map((reason) => RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: CineColors.gold,
                    title: Text(reason, style: const TextStyle(fontSize: 13, color: CineColors.textPrimary)),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedReason = val);
                    },
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CineColors.gold,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                Navigator.pop(dCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: CineColors.surfaceElevated,
                    content: Text(
                      'Thank you. Your report has been submitted to CineConnect Trust & Safety.',
                      style: TextStyle(color: CineColors.gold),
                    ),
                  ),
                );
              },
              child: const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showInstagramCommentsBottomSheet(CineFeedPost post) {
    final comments = _getCommentsForPost(post);
    final textController = TextEditingController();
    final scrollController = ScrollController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CineColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.70,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CineColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comments (${comments.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: CineColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: CineColors.textMuted, size: 20),
                          onPressed: () => Navigator.pop(bCtx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: CineColors.border, height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        final isLiked = c['isLiked'] as bool? ?? false;
                        final likes = c['likes'] as int? ?? 0;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: CineColors.surface,
                              child: Text(
                                c['avatar'] as String? ?? 'CC',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: CineColors.gold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c['author'] as String? ?? 'User',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: CineColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        c['time'] as String? ?? 'Just now',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: CineColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c['text'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: CineColors.textPrimary,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setSheetState(() {
                                  c['isLiked'] = !isLiked;
                                  c['likes'] = isLiked ? (likes - 1) : (likes + 1);
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  children: [
                                    Icon(
                                      isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      size: 16,
                                      color: isLiked ? CineColors.error : CineColors.textMuted,
                                    ),
                                    if (likes > 0)
                                      Text(
                                        '$likes',
                                        style: const TextStyle(fontSize: 10, color: CineColors.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(color: CineColors.border, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: CineColors.gold,
                          child: Text('YOU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: textController,
                            style: const TextStyle(color: CineColors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Add a comment for ${post.authorName}...',
                              hintStyle: const TextStyle(color: CineColors.textMuted, fontSize: 13),
                              filled: true,
                              fillColor: CineColors.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: CineColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: CineColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: CineColors.gold),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            final text = textController.text.trim();
                            if (text.isEmpty) return;
                            setSheetState(() {
                              comments.add({
                                'author': widget.appState.myProfile?.fullName ?? 'You',
                                'avatar': 'YOU',
                                'time': 'Just now',
                                'text': text,
                                'likes': 0,
                                'isLiked': false,
                              });
                            });
                            textController.clear();
                            widget.appState.addCommentToPost(post.id, text);
                            setState(() {});
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (scrollController.hasClients) {
                                scrollController.animateTo(
                                  scrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            });
                          },
                          child: const Text(
                            'Post',
                            style: TextStyle(
                              color: CineColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showInstagramShareBottomSheet(CineFeedPost post) {
    final searchController = TextEditingController();
    final sentRecipients = <String>{};

    final contacts = [
      {'name': 'Liam Rossi', 'craft': 'Director (DGA)', 'avatar': 'LR'},
      {'name': 'Elena Vance', 'craft': 'Cinematographer (ISC)', 'avatar': 'EV'},
      {'name': 'Alex Chen', 'craft': 'Lead Actor & Stunts', 'avatar': 'AC'},
      {'name': 'Priya Nair', 'craft': 'Actor & Producer', 'avatar': 'PN'},
      {'name': 'Karthik Raja', 'craft': 'DaVinci Colorist', 'avatar': 'KR'},
      {'name': 'Casting Studio', 'craft': 'Annapurna Talents', 'avatar': 'CS'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CineColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sCtx) => StatefulBuilder(
        builder: (context, setShareState) {
          final query = searchController.text.toLowerCase();
          final filtered = contacts
              .where((c) =>
                  c['name']!.toLowerCase().contains(query) ||
                  c['craft']!.toLowerCase().contains(query))
              .toList();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CineColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Share Post',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: CineColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: CineColors.textMuted, size: 20),
                          onPressed: () => Navigator.pop(sCtx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setShareState(() {}),
                      style: const TextStyle(color: CineColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: CineColors.textMuted),
                        hintText: 'Search contacts or crew...',
                        hintStyle: const TextStyle(color: CineColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: CineColors.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: CineColors.border),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        final isSent = sentRecipients.contains(c['name']);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: CineColors.surface,
                              child: Text(
                                c['avatar']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: CineColors.gold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c['name']!,
                              style: const TextStyle(fontSize: 10.5, color: CineColors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () {
                                setShareState(() {
                                  if (isSent) {
                                    sentRecipients.remove(c['name']);
                                  } else {
                                    sentRecipients.add(c['name']!);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSent ? CineColors.gold : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: CineColors.gold, width: 0.8),
                                ),
                                child: Text(
                                  isSent ? 'Sent ✓' : 'Send',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSent ? Colors.black : CineColors.gold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(color: CineColors.border, height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _shareActionButton(
                          icon: Icons.link_rounded,
                          label: 'Copy Link',
                          onTap: () async {
                            Navigator.pop(sCtx);
                            await Clipboard.setData(
                              ClipboardData(text: 'https://cineconnect.app/post/${post.id}'),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: CineColors.surfaceElevated,
                                  content: Text(
                                    'Post link copied to clipboard!',
                                    style: TextStyle(color: CineColors.gold),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        _shareActionButton(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Add to Story',
                          onTap: () {
                            Navigator.pop(sCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: CineColors.surfaceElevated,
                                content: Text(
                                  'Added ${post.authorName}\'s reel to your story draft!',
                                  style: const TextStyle(color: CineColors.gold),
                                ),
                              ),
                            );
                          },
                        ),
                        _shareActionButton(
                          icon: Icons.share_rounded,
                          label: 'Share via...',
                          onTap: () async {
                            Navigator.pop(sCtx);
                            await Clipboard.setData(
                              ClipboardData(
                                text: 'Check out ${post.authorName} on CineConnect: ${post.videoSlateTitle} https://cineconnect.app/post/${post.id}',
                              ),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: CineColors.surfaceElevated,
                                  content: Text(
                                    'Post details & link copied ready to share anywhere!',
                                    style: TextStyle(color: CineColors.gold),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _shareActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CineColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: CineColors.border),
              ),
              child: Icon(icon, color: CineColors.gold, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: CineColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  void _showTimecodeCritiqueDialog(CineFeedPost post) {
    final tcController = TextEditingController(text: post.smpteTimecode);
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14151C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CineColors.gold, width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: CineColors.gold, size: 20),
            SizedBox(width: 8),
            Text('Pin SMPTE Timecode Critique',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Post: ${post.authorName} • ${post.videoSlateTitle}',
                style:
                    const TextStyle(fontSize: 12, color: CineColors.textMuted)),
            const SizedBox(height: 12),
            const Text('Frame-Accurate Timecode (SMPTE 24fps):',
                style: TextStyle(fontSize: 11.5, color: CineColors.gold)),
            const SizedBox(height: 4),
            TextField(
              controller: tcController,
              style: const TextStyle(
                  fontFamily: 'monospace', fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Technical / Creative Critique Note:',
                style: TextStyle(fontSize: 11.5, color: CineColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Masterful shadow density at T2.0; subtle blue flare roll-off.',
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: CineColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final note = noteController.text.trim();
              final tc = tcController.text.trim();
              if (note.isNotEmpty) {
                widget.appState.addCommentToPost(post.id, note, timecode: tc);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: CineColors.surfaceElevated,
                  content: Text(
                    'Timecode critique pinned at $tc on 24fps Master Ledger!',
                    style: const TextStyle(color: CineColors.gold),
                  ),
                ),
              );
            },
            child: const Text('Pin to Master Ledger'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: CineColors.gold,
      backgroundColor: CineColors.surfaceElevated,
      onRefresh: () => widget.appState.loadFeedPosts(refresh: true),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
        // 24h Ephemeral On-Set Stories
        StoryStatusBar(state: widget.appState),
        const SizedBox(height: 4),

        // Section Header matching Screenshot 1
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.movie_filter_outlined,
                  color: CineColors.gold, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Talent Activity & Showreels',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: CineColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CineColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CineColors.border),
                ),
                child: Text(
                  '${widget.appState.feedPosts.length} Posts',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: CineColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Posts List
        ...widget.appState.feedPosts.where((post) => !_blockedAuthors.contains(post.authorName)).map((post) {
          final isScope = _isScopeMode[post.id] ?? true;
          final isLiked = post.isLiked;
          final isFollowed = _followedAuthors[post.id] ?? false;
          final isBookmarked = _bookmarkedPosts[post.id] ?? post.isBookmarked;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              color: CineColors.surfaceCard,
              border: Border(
                top: BorderSide(color: CineColors.border, width: 0.8),
                bottom: BorderSide(color: CineColors.border, width: 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author Header (Tapping avatar or name goes to profile like Instagram)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _openCreatorProfile(post),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: CineColors.surfaceElevated,
                                child: Text(
                                  post.authorAvatar,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: CineColors.gold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            post.authorName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: CineColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                                color: CineColors.gold
                                                    .withValues(alpha: 0.6),
                                                width: 0.8),
                                          ),
                                          child: Text(
                                            post.id == 'post-1'
                                                ? 'Method Actress'
                                                : 'Lead Actor & Stunts',
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: CineColors.gold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      post.id == 'post-1' ? '2h ago' : '5h ago',
                                      style: const TextStyle(
                                          fontSize: 11, color: CineColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // + Follow button (Matching Screenshot 1)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _followedAuthors[post.id] = !isFollowed;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFollowed
                                ? CineColors.gold
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: CineColors.gold, width: 0.9),
                          ),
                          child: Text(
                            isFollowed ? 'Following' : '+ Follow',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color:
                                  isFollowed ? Colors.black : CineColors.gold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded,
                            color: CineColors.textMuted),
                        onPressed: () => _showPostOptionsSheet(post),
                      ),
                    ],
                  ),
                ),

                // Post Body Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    post.contentText,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: CineColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Video / Slate Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CineColors.border),
                  ),
                  child: Column(
                    children: [
                      // Video Slate Area
                      Container(
                        height: isScope ? 175 : 195,
                        width: double.infinity,
                        color: const Color(0xFF0F1015),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Clapperboard watermark
                            Icon(
                              Icons.movie_creation_outlined,
                              size: 72,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            // Top Tag Pill
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: CineColors.gold
                                          .withValues(alpha: 0.7),
                                      width: 0.8),
                                ),
                                child: Text(
                                  post.id == 'post-1'
                                      ? 'WRAP PARTY & BTS'
                                      : 'AUDITION PREPARATION',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: CineColors.gold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            // Center Play Button & Timecode
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        CineColors.gold.withValues(alpha: 0.85),
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded,
                                      color: Colors.black, size: 28),
                                ),
                              ],
                            ),
                            // Bottom Title Bar
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 16, 12, 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.9),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.videoSlateTitle,
                                      style: const TextStyle(
                                        color: CineColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      post.id == 'post-1'
                                          ? 'Dir. Elena Vance • DP David Kim'
                                          : 'Sequence 12B • Choreography Rehearsal',
                                      style: const TextStyle(
                                        color: CineColors.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Icons Row: Heart, Comment, Share, Bookmark (Matching Screenshot 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      // Heart Like
                      InkWell(
                        onTap: _pendingLikeToggles.contains(post.id)
                            ? null
                            : () async {
                                setState(() {
                                  _pendingLikeToggles.add(post.id);
                                });
                                try {
                                  await widget.appState.toggleLikePost(post.id);
                                } catch (_) {
                                  if (mounted && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: CineColors.surfaceElevated,
                                        content: Text(
                                          'Failed to update like status. Please try again.',
                                          style: TextStyle(color: CineColors.error),
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _pendingLikeToggles.remove(post.id);
                                    });
                                  }
                                }
                              },
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 20,
                              color:
                                  isLiked ? CineColors.error : CineColors.gold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${post.likes}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CineColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Comment (Instagram style)
                      InkWell(
                        onTap: () => _showInstagramCommentsBottomSheet(post),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 19,
                              color: CineColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${post.comments}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CineColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Share Arrow (Instagram style)
                      InkWell(
                        onTap: () => _showInstagramShareBottomSheet(post),
                        child: const Icon(
                          Icons.send_rounded,
                          size: 19,
                          color: CineColors.textMuted,
                        ),
                      ),

                      const Spacer(),

                      // Crew ledger button
                      InkWell(
                        onTap: () => _showCrewLedgerBottomSheet(context, post),
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline_rounded,
                                size: 16, color: CineColors.gold),
                            const SizedBox(width: 4),
                            Text(
                              'Crew (${post.taggedCrafts.length})',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: CineColors.gold,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Bookmark
                      InkWell(
                        onTap: () {
                          setState(() {
                            _bookmarkedPosts[post.id] = !isBookmarked;
                          });
                          widget.appState.toggleBookmarkPost(post.id);
                        },
                        child: Icon(
                          isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 21,
                          color: isBookmarked
                              ? CineColors.gold
                              : CineColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),

        // Pagination state indicators
        if (widget.appState.isLoadingMoreFeed)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(CineColors.gold),
                ),
              ),
            ),
          )
        else if (widget.appState.feedPaginationError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Column(
              children: [
                Text(
                  widget.appState.feedPaginationError!,
                  style: const TextStyle(color: CineColors.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => widget.appState.loadMoreFeedPosts(),
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: CineColors.gold),
                  label: const Text(
                    'Retry Loading Feed',
                    style: TextStyle(
                      color: CineColors.gold,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (!widget.appState.hasMoreFeed && widget.appState.feedPosts.length >= 20)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                "You're all caught up on the Cinema Feed",
                style: TextStyle(color: CineColors.textMuted, fontSize: 11),
              ),
            ),
          ),
      ],
    ),
  );
  }

  void _showCrewLedgerBottomSheet(BuildContext context, CineFeedPost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: CineColors.border),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Verified Crew Credits Ledger',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: CineColors.gold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: CineColors.textMuted),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _crewCreditRow('Director', 'Karthik Subbaraj', 'DGA Verified'),
              _crewCreditRow(
                  'Cinematographer (DOP)', 'Maya Ray', 'ISC-9021 Verified'),
              _crewCreditRow(
                  '1st AC / Focus Puller', 'Rohan Patel', 'SICA-4401'),
              _crewCreditRow('Gaffer', 'Venkatesh Rao', 'Chief Tech Lighting'),
              _crewCreditRow('Colorist', 'Sameer Verma', 'DaVinci Certified'),
            ],
          ),
        );
      },
    );
  }

  Widget _crewCreditRow(String role, String name, String badge) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role,
                  style: const TextStyle(
                      fontSize: 11, color: CineColors.textMuted)),
              Text(name,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CineColors.textPrimary)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: CineColors.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: CineColors.border),
            ),
            child: Text(badge,
                style: const TextStyle(fontSize: 10, color: CineColors.gold)),
          ),
        ],
      ),
    );
  }
}

class CreatorProfileScreen extends StatefulWidget {
  final CineFeedPost post;
  final CineAppState appState;
  final bool isFollowed;
  final ValueChanged<bool> onToggleFollow;

  const CreatorProfileScreen({
    super.key,
    required this.post,
    required this.appState,
    required this.isFollowed,
    required this.onToggleFollow,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  late bool _isFollowed;

  @override
  void initState() {
    super.initState();
    _isFollowed = widget.isFollowed;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final handle = post.authorName.toLowerCase().replaceAll(' ', '.');

    return Scaffold(
      backgroundColor: CineColors.background,
      appBar: AppBar(
        backgroundColor: CineColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: CineColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CineColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.verified_rounded, color: CineColors.gold, size: 16),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, color: CineColors.textPrimary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: CineColors.surfaceElevated,
                  content: Text('Profile options for ${post.authorName}', style: const TextStyle(color: CineColors.gold)),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          CineColors.gold,
                          CineColors.goldLight,
                          Color(0xFFF59E0B),
                          CineColors.gold,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CineColors.surfaceElevated,
                      ),
                      child: Center(
                        child: Text(
                          post.authorAvatar,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: CineColors.gold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('18', 'Posts'),
                        _buildStatColumn('4.6K', 'Followers'),
                        _buildStatColumn('320', 'Following'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bio Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.authorName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: CineColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CineColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: CineColors.gold.withValues(alpha: 0.5), width: 0.8),
                        ),
                        child: Text(
                          post.authorCraft,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: CineColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'SAG-AFTRA / CINTAA',
                        style: TextStyle(fontSize: 11, color: CineColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lead talent in "${post.videoSlateTitle}". Passionate about authentic performance, method depth, and cinema collaboration. Based in Mumbai & Hyderabad.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: CineColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons (Follow, Message)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowed ? CineColors.surfaceElevated : CineColors.gold,
                        foregroundColor: _isFollowed ? CineColors.textPrimary : Colors.black,
                        side: _isFollowed ? const BorderSide(color: CineColors.border) : BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        setState(() {
                          _isFollowed = !_isFollowed;
                        });
                        widget.onToggleFollow(_isFollowed);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: CineColors.surfaceElevated,
                            content: Text(
                              _isFollowed ? 'You are now following ${post.authorName}' : 'Unfollowed ${post.authorName}',
                              style: const TextStyle(color: CineColors.gold),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        _isFollowed ? 'Following' : 'Follow',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CineColors.textPrimary,
                        side: const BorderSide(color: CineColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: CineColors.surfaceElevated,
                            content: Text('Direct message thread opened with ${post.authorName}', style: const TextStyle(color: CineColors.gold)),
                          ),
                        );
                      },
                      child: const Text('Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Bar (Grid of Posts / Showreels)
            const Divider(color: CineColors.border, height: 1),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Icon(Icons.grid_on_rounded, color: CineColors.gold, size: 22),
                  Icon(Icons.video_library_outlined, color: CineColors.textMuted, size: 22),
                  Icon(Icons.assignment_ind_outlined, color: CineColors.textMuted, size: 22),
                ],
              ),
            ),
            const Divider(color: CineColors.border, height: 1),

            // 3-Column Showreel Grid (Instagram style)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              children: List.generate(9, (idx) {
                return InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: CineColors.surfaceElevated,
                        title: Text('Showreel Take #${idx + 1}', style: const TextStyle(color: CineColors.gold, fontSize: 14)),
                        content: Text('Previewing video slate for ${post.authorName} (${post.currentAspect}).', style: const TextStyle(color: CineColors.textPrimary, fontSize: 12)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text('Close', style: TextStyle(color: CineColors.gold)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    color: CineColors.surfaceCard,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Icon(
                            idx.isEven ? Icons.movie_outlined : Icons.videocam_outlined,
                            color: CineColors.gold.withValues(alpha: 0.6),
                            size: 28,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: CineColors.gold, size: 14),
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Text(
                            idx == 0 ? post.currentAspect : (idx % 2 == 0 ? '2.39:1' : '16:9'),
                            style: const TextStyle(fontSize: 8.5, color: CineColors.textMuted, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: CineColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: CineColors.textMuted,
          ),
        ),
      ],
    );
  }
}
