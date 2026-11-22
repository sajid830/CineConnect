import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';

class NotificationsSheet extends StatefulWidget {
  final CineAppState appState;

  const NotificationsSheet({super.key, required this.appState});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  String _filter = 'All';

  IconData _iconForType(String type) {
    switch (type) {
      case 'shortlist':
        return Icons.star_rounded;
      case 'castingMatch':
        return Icons.auto_awesome_rounded;
      case 'auditionStatus':
        return Icons.movie_filter_rounded;
      case 'hold':
        return Icons.calendar_today_rounded;
      case 'endorsement':
        return Icons.verified_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'shortlist':
        return CineColors.gold;
      case 'castingMatch':
        return CineColors.goldLight;
      case 'auditionStatus':
        return const Color(0xFF60A5FA);
      case 'hold':
        return const Color(0xFF34D399);
      case 'endorsement':
        return const Color(0xFFA78BFA);
      default:
        return CineColors.gold;
    }
  }

  bool _matchesFilter(CineNotification notif) {
    switch (_filter) {
      case 'Casting':
        return notif.type == 'castingMatch' || notif.type == 'auditionStatus';
      case 'Activity':
        return notif.type == 'shortlist' ||
            notif.type == 'hold' ||
            notif.type == 'endorsement';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.appState.notifications.where(_matchesFilter).toList();
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
                if (widget.appState.unreadNotificationsCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: CineColors.gold,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.appState.unreadNotificationsCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (widget.appState.unreadNotificationsCount > 0)
                  TextButton(
                    onPressed: widget.appState.markNotificationsAsRead,
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
            child: filtered.isEmpty
                ? const Center(
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
                  )
                : ListView(
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

  Widget _notificationTile(CineNotification notif) {
    final color = _colorForType(notif.type);

    return InkWell(
      onTap: () => widget.appState.markNotificationAsRead(notif.id),
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
                    notif.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CineColors.textMuted,
                      height: 1.35,
                    ),
                  ),
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
