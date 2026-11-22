import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';

class CineBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreatePressed;
  final int opportunitiesBadgeCount;

  const CineBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onCreatePressed,
    this.opportunitiesBadgeCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CineColors.surface,
        border: const Border(
          top: BorderSide(
            color: CineColors.border,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Home
              _buildNavItem(
                index: 0,
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),

              // 2. Opportunities
              _buildNavItem(
                index: 1,
                label: 'Opportunities',
                icon: Icons.work_outline_rounded,
                activeIcon: Icons.work_rounded,
                isSelected: currentIndex == 1,
                badgeCount: opportunitiesBadgeCount,
                onTap: () => onTap(1),
              ),

              // 3. Create (+) - Highlighted Gold Center Action Button
              _buildCreateButton(
                onTap: onCreatePressed,
              ),

              // 4. Search
              _buildNavItem(
                index: 3,
                label: 'Search',
                icon: Icons.search_rounded,
                activeIcon: Icons.search_rounded,
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),

              // 5. Profile
              _buildNavItem(
                index: 4,
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                isSelected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isSelected,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: CineColors.gold.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 24,
                  color: isSelected ? CineColors.gold : CineColors.textMuted,
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: -6,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CineColors.gold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? CineColors.gold : CineColors.textMuted,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton({required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [CineColors.goldLight, CineColors.gold],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CineColors.gold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.black,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Create',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: CineColors.gold,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
