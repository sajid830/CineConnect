import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';

class OnSetStoryViewerDialog extends StatefulWidget {
  final OnSetStory story;
  final VoidCallback onClose;
  final CineAppState? appState;

  const OnSetStoryViewerDialog({
    super.key,
    required this.story,
    required this.onClose,
    this.appState,
  });

  @override
  State<OnSetStoryViewerDialog> createState() => _OnSetStoryViewerDialogState();
}

class _OnSetStoryViewerDialogState extends State<OnSetStoryViewerDialog> {
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isRefreshingUrl = false;
  String? _activeUrl;

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.story.playbackUrl ?? widget.story.mediaUrl;
    _checkAndInitMedia();
  }

  void _checkAndInitMedia() {
    final url = _activeUrl ?? '';
    if (url.isEmpty) return;

    final lower = url.toLowerCase();
    _isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mkv') ||
        lower.contains('video/');

    if (_isVideo) {
      _initVideoPlayer(url);
    }
  }

  void _initVideoPlayer(String url) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController!.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        _videoController!.setLooping(true);
        _videoController!.play();
      }
    }).catchError((err) async {
      // If presigned URL expired or initialization failed, attempt to fetch fresh playback URL
      if (!_isRefreshingUrl &&
          widget.appState != null &&
          widget.story.id.isNotEmpty &&
          !widget.story.id.startsWith('story-') &&
          !widget.story.id.startsWith('your-')) {
        _isRefreshingUrl = true;
        final freshUrl = await widget.appState!.getStoryPlaybackUrl(widget.story.id);
        _isRefreshingUrl = false;
        if (freshUrl != null && freshUrl.isNotEmpty && freshUrl != url && mounted) {
          _activeUrl = freshUrl;
          _initVideoPlayer(freshUrl);
          return;
        }
      }

      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isInitialized) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CineColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CineColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: CineColors.error, size: 22),
            SizedBox(width: 8),
            Text(
              'Delete Story?',
              style: TextStyle(
                color: CineColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently remove this on-set story broadcast? This action cannot be undone.',
          style: TextStyle(color: CineColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CineColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && widget.appState != null) {
      try {
        await widget.appState!.deleteStory(widget.story.id);
        widget.onClose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: CineColors.surfaceElevated,
              content: Text(
                'Story deleted successfully.',
                style: TextStyle(color: CineColors.gold),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: CineColors.surfaceElevated,
              content: Text(
                'Failed to delete story: $e',
                style: const TextStyle(color: CineColors.error),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = widget.appState?.myProfile?.id;
    final isOwner = (myUserId != null && widget.story.userId == myUserId) ||
        widget.story.creatorName == 'Your Story';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1015),
            border: Border.all(color: CineColors.gold.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: CineColors.gold.withValues(alpha: 0.25),
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
                          color: Colors.white.withValues(alpha: 0.2),
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
                        widget.story.initials,
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
                              Flexible(
                                child: Text(
                                  widget.story.creatorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: CineColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• ${widget.story.timeAgo}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CineColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            widget.story.craftBadge,
                            style: const TextStyle(
                              fontSize: 11,
                              color: CineColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOwner && !widget.story.id.startsWith('your-'))
                      IconButton(
                        tooltip: 'Delete Story',
                        icon: const Icon(Icons.delete_outline_rounded, color: CineColors.error, size: 20),
                        onPressed: _confirmDelete,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: CineColors.textPrimary),
                      onPressed: widget.onClose,
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
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: CineColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 12, color: CineColors.gold),
                        const SizedBox(width: 4),
                        Text(
                          widget.story.location,
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

              // Viewport Container with Real Media and Viewfinder Overlays
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CineColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: _isVideo ? _togglePlayPause : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Base Media Layer
                          if (_isVideo) ...[
                            if (_isInitialized && _videoController != null)
                              SizedBox.expand(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _videoController!.value.size.width,
                                    height: _videoController!.value.size.height,
                                    child: VideoPlayer(_videoController!),
                                  ),
                                ),
                              )
                            else if (_hasError)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam_off_rounded, color: CineColors.error, size: 40),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Video unavailable or link expired',
                                      style: TextStyle(color: CineColors.textMuted, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () {
                                        if (_activeUrl != null) _initVideoPlayer(_activeUrl!);
                                      },
                                      icon: const Icon(Icons.refresh_rounded, size: 16, color: CineColors.gold),
                                      label: const Text('Retry', style: TextStyle(color: CineColors.gold, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(CineColors.gold),
                                  ),
                                ),
                              ),
                          ] else if (_activeUrl != null && _activeUrl!.isNotEmpty) ...[
                            Image.network(
                              _activeUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(CineColors.gold),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFF14151C),
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.broken_image_rounded, color: CineColors.textMuted, size: 40),
                                        SizedBox(height: 8),
                                        Text('Image unavailable', style: TextStyle(color: CineColors.textMuted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else ...[
                            // Fallback cinematic canvas
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
                          ],

                          // Overlay Layer 1: Viewfinder Frame Lines
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ViewfinderOverlayPainter(),
                            ),
                          ),

                          // Overlay Layer 2: Center Watermark & Play/Pause State
                          if (!_isVideo || !_isInitialized || !_videoController!.value.isPlaying)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isVideo && _isInitialized && !_videoController!.value.isPlaying)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: CineColors.gold, width: 1.5),
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, size: 36, color: CineColors.gold),
                                  )
                                else
                                  const Icon(Icons.videocam_rounded, size: 44, color: CineColors.gold),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'SOUNDSTAGE LIVE FEED',
                                    style: TextStyle(
                                      color: CineColors.goldLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.85),
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

                          // Overlay Layer 3: Bottom Caption
                          if (widget.story.storyCaption.isNotEmpty)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: CineColors.border),
                                ),
                                child: Text(
                                  widget.story.storyCaption,
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
      ..color = CineColors.gold.withValues(alpha: 0.4)
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
