import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/app/theme.dart';

/// Screen allowing the user to select their role in the CineConnect ecosystem:
/// "Talent" or "Production Hub".
class UserTypeSelectionScreen extends StatelessWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.movie_filter_rounded,
                        size: 40,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // CineConnect Title
                  Text(
                    'CineConnect',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Screen Title
                  Text(
                    'Choose Your Path',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle
                  Text(
                    'Select how you want to experience the premier cinema network.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Card 1: Talent
                  _UserTypeCard(
                    title: 'Talent',
                    subtitle: 'Find roles, showcase your portfolio',
                    badge: 'Actors • Crew • Creators',
                    icon: Icons.star_rounded,
                    accentColor: AppColors.gold,
                    onTap: () => context.go('/login/talent'),
                  ),
                  const SizedBox(height: 20),

                  // Card 2: Production Hub
                  _UserTypeCard(
                    title: 'Production Hub',
                    subtitle: 'Post jobs, hire top talent',
                    badge: 'Studios • Producers • Casting',
                    icon: Icons.movie_creation_rounded,
                    accentColor: AppColors.goldLight,
                    onTap: () => context.go('/login/production'),
                  ),
                  const SizedBox(height: 40),

                  // Footer note
                  Text(
                    'You can seamlessly switch or link roles later in settings.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTypeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_UserTypeCard> createState() => _UserTypeCardState();
}

class _UserTypeCardState extends State<_UserTypeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.surfaceElevated : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered ? widget.accentColor : AppColors.border,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.accentColor.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.25),
              blurRadius: _isHovered ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: widget.accentColor.withValues(alpha: 0.12),
            highlightColor: widget.accentColor.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Row(
                children: [
                  // Icon Avatar
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 30,
                      color: widget.accentColor,
                    ),
                  ),
                  const SizedBox(width: 18),

                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.badge.toUpperCase(),
                            style: TextStyle(
                              color: widget.accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Title
                        Text(
                          widget.title,
                          style: textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Subtitle
                        Text(
                          widget.subtitle,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Arrow Indicator
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isHovered
                            ? widget.accentColor.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color:
                          _isHovered ? widget.accentColor : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
