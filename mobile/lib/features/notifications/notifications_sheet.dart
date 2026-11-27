import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';
import '../chat/chat_sheet.dart';

class NotificationsSheet extends StatefulWidget {
  final CineAppState appState;

  const NotificationsSheet({super.key, required this.appState});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    // Refresh notifications and user collaborations when the sheet opens
    widget.appState.loadNotifications(forceRefresh: true);
    widget.appState.loadMyCollaborations();
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'shortlist':
        return Icons.star_rounded;
      case 'castingmatch':
      case 'application':
        return Icons.auto_awesome_rounded;
      case 'auditionstatus':
        return Icons.movie_filter_rounded;
      case 'hold':
        return Icons.calendar_today_rounded;
      case 'endorsement':
      case 'connection':
        return Icons.verified_rounded;
      case 'collaboration':
        return Icons.group_outlined;
      case 'message':
        return Icons.chat_bubble_outline;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'shortlist':
        return CineColors.gold;
      case 'castingmatch':
      case 'application':
        return CineColors.goldLight;
      case 'auditionstatus':
        return const Color(0xFF60A5FA);
      case 'hold':
        return const Color(0xFF34D399);
      case 'endorsement':
      case 'connection':
        return const Color(0xFFA78BFA);
      case 'collaboration':
        return const Color(0xFFF59E0B);
      case 'message':
        return const Color(0xFF38BDF8);
      default:
        return CineColors.gold;
    }
  }

  bool _matchesFilter(CineNotification notif) {
    final t = notif.type.toLowerCase();
    switch (_filter) {
      case 'Casting':
        return t == 'castingmatch' ||
            t == 'auditionstatus' ||
            t == 'application' ||
            t.contains('casting') ||
            t.contains('audition');
      case 'Activity':
        return t == 'shortlist' ||
            t == 'hold' ||
            t == 'endorsement' ||
            t == 'connection' ||
            t == 'collaboration' ||
            t == 'message' ||
            t.contains('collab') ||
            t.contains('message');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.appState;
    final filtered = state.notifications.where(_matchesFilter).toList();
    final unread = filtered.where((n) => !n.isRead).toList();
    final earlier = filtered.where((n) => n.isRead).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: CineColors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: CineColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (state.unreadNotificationsCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: CineColors.gold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${state.unreadNotificationsCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (state.unreadNotificationsCount > 0)
                  TextButton(
                    onPressed: () async {
                      try {
                        await state.markNotificationsAsRead();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not mark all notifications as read')),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: CineColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ['All', 'Casting', 'Activity'].map((label) {
                final selected = _filter == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _filter = label),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? CineColors.gold : CineColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? CineColors.gold : CineColors.border,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.black : CineColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: CineColors.border),
          Expanded(
            child: state.isLoadingNotifications && state.notifications.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: CineColors.gold),
                  )
                : state.notificationsError != null && state.notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 44,
                              color: CineColors.textMuted,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Could not load notifications',
                              style: TextStyle(color: CineColors.textMuted),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => state.loadNotifications(forceRefresh: true),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: CineColors.gold),
                              ),
                              child: const Text(
                                'Try again',
                                style: TextStyle(color: CineColors.gold),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: CineColors.gold,
                        backgroundColor: CineColors.surfaceElevated,
                        onRefresh: () => state.loadNotifications(forceRefresh: true),
                        child: filtered.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.notifications_none_rounded,
                                          size: 46,
                                          color: CineColors.textMuted,
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'No notifications yet',
                                          style: TextStyle(color: CineColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 24),
                                children: [
                                  if (unread.isNotEmpty) ...[
                                    _sectionLabel('New'),
                                    ...unread.map((n) => _notificationTile(n)),
                                  ],
                                  if (earlier.isNotEmpty) ...[
                                    _sectionLabel('Earlier'),
                                    ...earlier.map((n) => _notificationTile(n)),
                                  ],
                                ],
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: CineColors.textPrimary,
        ),
      ),
    );
  }

  Future<void> _handleAcceptCollaboration(CineNotification notif) async {
    final collabId = notif.collaborationId;
    if (collabId == null) return;

    // Instant optimistic visual feedback (0ms)
    widget.appState.acceptedCollabIds.add(collabId);
    widget.appState.declinedCollabIds.remove(collabId);
    widget.appState.markNotificationAsRead(notif.id);
    if (mounted) setState(() {});

    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: CineColors.surfaceElevated,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Collaboration accepted! You can now chat.',
            style: TextStyle(color: CineColors.gold, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    try {
      await widget.appState.acceptCollaboration(collabId);
    } catch (e) {
      if (mounted) setState(() {});
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text('Could not accept invitation: $e', style: const TextStyle(color: CineColors.error)),
          ),
        );
      }
    }
  }

  Future<void> _handleRejectCollaboration(CineNotification notif) async {
    final collabId = notif.collaborationId;
    if (collabId == null) return;

    // Instant optimistic visual feedback (0ms)
    widget.appState.declinedCollabIds.add(collabId);
    widget.appState.acceptedCollabIds.remove(collabId);
    widget.appState.markNotificationAsRead(notif.id);
    if (mounted) setState(() {});

    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: CineColors.surfaceElevated,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Collaboration invitation declined.',
            style: TextStyle(color: CineColors.textMuted),
          ),
        ),
      );
    }

    try {
      await widget.appState.rejectCollaboration(collabId);
    } catch (e) {
      if (mounted) setState(() {});
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text('Could not decline invitation: $e', style: const TextStyle(color: CineColors.error)),
          ),
        );
      }
    }
  }

  Widget _notificationTile(CineNotification notif) {
    final color = _colorForType(notif.type);

    return InkWell(
      onTap: () async {
        if (!notif.isRead) {
          try {
            await widget.appState.markNotificationAsRead(notif.id);
          } catch (_) {
            if (mounted && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not mark notification as read')),
              );
            }
          }
        }
      },
      child: Container(
        color: notif.isRead ? Colors.transparent : CineColors.gold.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.32), CineColors.surfaceElevated],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: color.withValues(alpha: 0.5)),
                  ),
                  child: Center(
                    child: Text(
                      notif.avatarInitials,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(color: CineColors.surface, width: 2),
                    ),
                    child: Icon(
                      _iconForType(notif.type),
                      size: 11,
                      color: Colors.black,
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: notif.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: notif.isRead ? CineColors.textPrimary : CineColors.gold,
                          ),
                        ),
                        TextSpan(
                          text: '  ${notif.timeAgo}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: CineColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.cleanDescription,
                    maxLines: notif.collaborationId != null ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CineColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                  if (notif.collaborationId != null) ...[
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final isAccepted = widget.appState.acceptedCollabIds.contains(notif.collaborationId);
                        final isDeclined = widget.appState.declinedCollabIds.contains(notif.collaborationId);

                        if (isAccepted) {
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                                    SizedBox(width: 4),
                                    Text('Accepted', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => ChatSheet(appState: widget.appState),
                                  );
                                },
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                                label: const Text('Message', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: CineColors.gold,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          );
                        }

                        if (isDeclined) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: CineColors.border),
                            ),
                            child: const Text('Declined', style: TextStyle(fontSize: 11.5, color: CineColors.textMuted)),
                          );
                        }

                        return Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _handleAcceptCollaboration(notif),
                              icon: const Icon(Icons.check_rounded, size: 14),
                              label: const Text(
                                'Accept Invite',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CineColors.gold,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _handleRejectCollaboration(notif),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: CineColors.textMuted,
                                side: const BorderSide(color: CineColors.border),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Decline', style: TextStyle(fontSize: 11.5)),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!notif.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: CineColors.gold,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: CineColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
