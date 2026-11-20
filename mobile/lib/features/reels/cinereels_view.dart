import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';

class CineReelsView extends StatefulWidget {
  final CineAppState appState;

  const CineReelsView({super.key, required this.appState});

  @override
  State<CineReelsView> createState() => _CineReelsViewState();
}

class _CineReelsViewState extends State<CineReelsView> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  final Map<String, bool> _likedReels = {};
  final Map<String, bool> _savedReels = {};
  bool _showHeartAnimation = false;
  Offset _heartAnimPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDoubleTap(TapDownDetails details, CineReelItem reel) {
    setState(() {
      _likedReels[reel.id] = true;
      _showHeartAnimation = true;
      _heartAnimPos = details.localPosition;
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showHeartAnimation = false;
        });
      }
    });
  }

  void _showCollaborateSheet(CineReelItem reel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111218),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: CineColors.gold),
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
                  Row(
                    children: [
                      const Icon(Icons.handshake_outlined, color: CineColors.gold, size: 24),
                      const SizedBox(width: 8),
                      Text('Craft Collaboration Inquiry',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CineColors.textPrimary)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: CineColors.textMuted),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Showreel: "${reel.title}"',
                style: const TextStyle(fontSize: 12.5, color: CineColors.goldLight),
              ),
              const SizedBox(height: 6),
              Text(
                'Connect directly with ${reel.creatorName} (${reel.creatorCraft}) for cinematography, action choreography, lighting, or sound collaboration on upcoming cinema slates.',
                style: const TextStyle(fontSize: 12, color: CineColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _savedReels[reel.id] = !(_savedReels[reel.id] ?? false);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: CineColors.surfaceElevated,
                            content: Text('Reel saved to your Digital Slate Portfolio!', style: TextStyle(color: CineColors.gold)),
                          ),
                        );
                      },
                      child: Text((_savedReels[reel.id] ?? false) ? '✓ Saved' : 'Save Reel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: CineColors.surfaceElevated,
                            content: Text(
                              'Collaboration request sent to ${reel.creatorName}!',
                              style: const TextStyle(color: CineColors.gold),
                            ),
                          ),
                        );
                      },
                      child: const Text('Send Connect Request'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.appState.reels.length,
      itemBuilder: (context, index) {
        final reel = widget.appState.reels[index];
        final isLiked = _likedReels[reel.id] ?? reel.isLiked;
        final isSaved = _savedReels[reel.id] ?? reel.isBookmarked;

        return GestureDetector(
          onDoubleTapDown: (details) => _onDoubleTap(details, reel),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 9:16 Video Canvas Simulation
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1B1B26),
                      Color(0xFF0F1018),
                      Color(0xFF060608),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CineColors.gold.withOpacity(0.12),
                          border: Border.all(color: CineColors.gold.withOpacity(0.4), width: 1.5),
                        ),
                        child: const Icon(Icons.movie_creation_outlined, size: 54, color: CineColors.gold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        reel.reelType.toUpperCase(),
                        style: const TextStyle(
                          color: CineColors.goldLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reel.craftSpecialty,
                        style: const TextStyle(
                          color: CineColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Double-Tap Radiant Gold Heart Burst Animation
              if (_showHeartAnimation)
                Positioned(
                  left: _heartAnimPos.dx - 40,
                  top: _heartAnimPos.dy - 40,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.2, end: 1.4),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 80,
                          color: CineColors.gold,
                        ),
                      );
                    },
                  ),
                ),

              // Top Gradient & Reel Type Tag
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: CineColors.gold.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.videocam_outlined, size: 14, color: CineColors.gold),
                            const SizedBox(width: 4),
                            Text(
                              'CINEREEL • 9:16 MASTER',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: CineColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'TC ${reel.smpteTimecode}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: CineColors.goldLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right-Side Interaction Rail
              Positioned(
                right: 12,
                bottom: 120,
                child: Column(
                  children: [
                    // Like Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _likedReels[reel.id] = !isLiked;
                        });
                      },
                      child: Column(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isLiked ? CineColors.gold : Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(reel.likesCount + (isLiked ? 1 : 0)) ~/ 1000}k',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Comments / Critique Notes
                    GestureDetector(
                      onTap: () {},
                      child: Column(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 28),
                          const SizedBox(height: 4),
                          Text(
                            '${reel.commentsCount}',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Collaborate / Connect Button
                    GestureDetector(
                      onTap: () => _showCollaborateSheet(reel),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [CineColors.goldLight, CineColors.gold],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: CineColors.gold.withOpacity(0.5),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.handshake_rounded, color: Colors.black, size: 20),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'CONNECT',
                            style: TextStyle(fontSize: 9, color: CineColors.gold, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Bookmark / Save Reel
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _savedReels[reel.id] = !isSaved;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: CineColors.surfaceElevated,
                            content: Text(
                              isSaved ? 'Removed from saved reels' : 'Saved showreel to your Digital Slate!',
                              style: const TextStyle(color: CineColors.gold),
                            ),
                          ),
                        );
                      },
                      child: Icon(
                        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: isSaved ? CineColors.gold : Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Metadata (Creator, Audio Track, Title)
              Positioned(
                left: 16,
                right: 75,
                bottom: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Creator Info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: CineColors.gold,
                          child: Text(
                            reel.creatorAvatar,
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          reel.creatorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: CineColors.gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: CineColors.gold, width: 0.6),
                          ),
                          child: Text(
                            reel.creatorCraft,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: CineColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Title
                    Text(
                      reel.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Audio Track Info
                    Row(
                      children: [
                        const Icon(Icons.music_note_rounded, color: CineColors.gold, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            reel.audioTrack,
                            style: const TextStyle(
                              color: CineColors.textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
