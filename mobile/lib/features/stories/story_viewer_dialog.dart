import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/craft_models.dart';

class OnSetStoryViewerDialog extends StatelessWidget {
  final OnSetStory story;
  final VoidCallback onClose;

  const OnSetStoryViewerDialog({
    super.key,
    required this.story,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1015),
            border: Border.all(color: CineColors.gold.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: CineColors.gold.withOpacity(0.25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Progress Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: CineColors.gold,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Author Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: CineColors.gold,
                      child: Text(
                        story.initials,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                story.creatorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: CineColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• ${story.timeAgo}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CineColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            story.craftBadge,
                            style: const TextStyle(
                              fontSize: 11,
                              color: CineColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: CineColors.textPrimary),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),

              // Soundstage Location Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: CineColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 12, color: CineColors.gold),
                        const SizedBox(width: 4),
                        Text(
                          story.location,
                          style: const TextStyle(
                            fontSize: 11,
                            color: CineColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Simulated Live Monitor Viewport
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CineColors.border),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Video Simulation Canvas
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF1A1A24),
                              Color(0xFF0E0E14),
                            ],
                          ),
                        ),
                      ),
                      // Viewfinder Frame Lines
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ViewfinderOverlayPainter(),
                        ),
                      ),
                      // Center Camera Info
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_rounded, size: 48, color: CineColors.gold),
                          const SizedBox(height: 12),
                          const Text(
                            'SOUNDSTAGE LIVE FEED',
                            style: TextStyle(
                              color: CineColors.goldLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '● REC  24 FPS  ISO 800  5600K',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Bottom Caption
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CineColors.border),
                          ),
                          child: Text(
                            story.storyCaption,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Interaction Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: CineColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: CineColors.border),
                        ),
                        child: const Text(
                          'Reply to slate story...',
                          style: TextStyle(fontSize: 12, color: CineColors.textMuted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.favorite_rounded, color: CineColors.gold),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: CineColors.textPrimary),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewfinderOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CineColors.gold.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const cornerLength = 20.0;
    const padding = 16.0;

    // Top-left
    canvas.drawLine(const Offset(padding, padding), const Offset(padding + cornerLength, padding), paint);
    canvas.drawLine(const Offset(padding, padding), const Offset(padding, padding + cornerLength), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding - cornerLength, padding), paint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + cornerLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerLength, size.height - padding), paint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding, size.height - padding - cornerLength), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding - cornerLength, size.height - padding), paint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding, size.height - padding - cornerLength), paint);

    // Center crosshair
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(Offset(center.dx - 10, center.dy), Offset(center.dx + 10, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - 10), Offset(center.dx, center.dy + 10), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
