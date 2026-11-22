import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cineconnect/app/theme.dart';

/// Modal dialog providing in-app video playback for candidate audition self-tapes.
///
/// Features:
/// - Connects to authorized temporary presigned download URLs.
/// - Full lifecycle management with clean [VideoPlayerController.dispose()].
/// - Play, pause, seek slider, and jump forward/backward (+/- 10s).
/// - Position and total duration time indicators.
/// - Graceful playback error handling with a refresh/retry callback for expired URLs.
/// - Optional external launcher via [url_launcher] for external player viewing.
class AuditionVideoPlayerDialog extends StatefulWidget {
  final String downloadUrl;
  final String candidateName;
  final String projectTitle;
  final Future<String> Function()? onRefreshUrl;

  const AuditionVideoPlayerDialog({
    super.key,
    required this.downloadUrl,
    required this.candidateName,
    required this.projectTitle,
    this.onRefreshUrl,
  });

  @override
  State<AuditionVideoPlayerDialog> createState() =>
      _AuditionVideoPlayerDialogState();
}

class _AuditionVideoPlayerDialogState extends State<AuditionVideoPlayerDialog> {
  late VideoPlayerController _controller;
  late String _activeUrl;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _activeUrl = widget.downloadUrl;
    _initPlayer(_activeUrl);
  }

  void _initPlayer(String url) {
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..addListener(_playerListener)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _hasError = false;
            _errorMessage = null;
          });
          _controller.play();
        }
      }).catchError((err) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage =
                'Unable to play audition video.\nThe secure link may have expired or the media format is not supported.';
          });
        }
      });
  }

  void _playerListener() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshAndRetry() async {
    if (widget.onRefreshUrl == null) {
      _controller.removeListener(_playerListener);
      _controller.dispose();
      _initPlayer(_activeUrl);
      return;
    }
    setState(() => _isRefreshing = true);
    try {
      final freshUrl = await widget.onRefreshUrl!();
      _activeUrl = freshUrl;
      _controller.removeListener(_playerListener);
      await _controller.dispose();
      _initPlayer(freshUrl);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to refresh video download link: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_playerListener);
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final position = _controller.value.position;
    final duration = _controller.value.duration;
    final isPlaying = _controller.value.isPlaying;

    return Dialog(
      backgroundColor: const Color(0xFF13141C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.gold, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.black45,
                child: Row(
                  children: [
                    const Icon(
                      Icons.video_library_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Audition Tape: ${widget.candidateName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.projectTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.goldLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Video Player Display Area
              Container(
                color: Colors.black,
                constraints: const BoxConstraints(maxHeight: 400),
                child: _hasError
                    ? Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFFF8B8B),
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage ?? 'Playback error occurred',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFF8B8B),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _isRefreshing ? null : _refreshAndRetry,
                              icon: _isRefreshing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.refresh, size: 16),
                              label: const Text('Refresh Link & Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      )
                    : !_isInitialized
                        ? const Padding(
                            padding: EdgeInsets.all(48.0),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: AppColors.gold),
                                  SizedBox(height: 12),
                                  Text(
                                    'Loading audition video stream...',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: _controller.value.aspectRatio > 0
                                ? _controller.value.aspectRatio
                                : 16 / 9,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_controller),
                                // Centered Play/Pause toggle on tap
                                GestureDetector(
                                  onTap: () {
                                    if (isPlaying) {
                                      _controller.pause();
                                    } else {
                                      _controller.play();
                                    }
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Center(
                                      child: AnimatedOpacity(
                                        opacity: isPlaying ? 0.0 : 0.85,
                                        duration: const Duration(milliseconds: 200),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 40,
                                            color: AppColors.gold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),

              // Playback Controls Bar
              if (_isInitialized && !_hasError) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: const Color(0xFF191B24),
                  child: Column(
                    children: [
                      // Slider & Time
                      Row(
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                activeTrackColor: AppColors.gold,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: AppColors.gold,
                              ),
                              child: Slider(
                                value: position.inMilliseconds
                                    .toDouble()
                                    .clamp(0.0, duration.inMilliseconds.toDouble()),
                                max: duration.inMilliseconds.toDouble() > 0
                                    ? duration.inMilliseconds.toDouble()
                                    : 1.0,
                                onChanged: (val) {
                                  _controller.seekTo(
                                    Duration(milliseconds: val.toInt()),
                                  );
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      // Controls row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: AppColors.gold,
                                  size: 26,
                                ),
                                onPressed: () {
                                  if (isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.replay_10_rounded,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () {
                                  final newPos = position - const Duration(seconds: 10);
                                  _controller.seekTo(
                                    newPos > Duration.zero ? newPos : Duration.zero,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.forward_10_rounded,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () {
                                  final newPos = position + const Duration(seconds: 10);
                                  _controller.seekTo(
                                    newPos < duration ? newPos : duration,
                                  );
                                },
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(_activeUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.open_in_new, size: 14, color: AppColors.goldLight),
                            label: const Text(
                              'Open externally',
                              style: TextStyle(fontSize: 11, color: AppColors.goldLight),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
