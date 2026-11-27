import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/state/app_state.dart';

class CineAppHeader extends StatelessWidget {
  final CineAppState state;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenChat;
  final VoidCallback? onBack;
  final bool showActions;
  final Widget? trailing;

  const CineAppHeader({
    super.key,
    required this.state,
    required this.onOpenNotifications,
    required this.onOpenChat,
    this.onBack,
    this.showActions = true,
    this.trailing,
  });

  Widget _buildTopAction({
    required String label,
    required VoidCallback onTap,
    required Widget icon,
    required bool showBadge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                icon,
                if (showBadge)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CineColors.gold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: CineColors.textMuted,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CineColors.background,
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: CineColors.textPrimary,
                size: 22,
              ),
              splashRadius: 20,
              onPressed: onBack,
            )
          else
            const SizedBox(width: 6),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [CineColors.goldLight, CineColors.gold],
              ),
              boxShadow: [
                BoxShadow(
                  color: CineColors.gold.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.camera_rounded,
                color: Colors.black,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'CineConnect',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: CineColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            trailing!
          else if (showActions) ...[
            _buildTopAction(
              label: 'Notifications',
              onTap: onOpenNotifications,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: CineColors.textPrimary,
                size: 22,
              ),
              showBadge: state.unreadNotificationsCount > 0,
            ),
            const SizedBox(width: 2),
            _buildTopAction(
              label: 'Chat',
              onTap: onOpenChat,
              icon: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: CineColors.textPrimary,
                size: 20,
              ),
              showBadge: state.unreadChatCount > 0,
            ),
          ],
        ],
      ),
    );
  }
}
