import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/state/app_state.dart';
import 'story_viewer_dialog.dart';

class StoryStatusBar extends StatelessWidget {
  final CineAppState state;

  const StoryStatusBar({super.key, required this.state});

  void _showAddStoryDialog(BuildContext context, CineAppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => _PublishStoryDialog(appState: appState),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        itemCount: state.stories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final story = state.stories[index];
          final isYou = index == 0;
          final isPlaceholder = story.id == 'your-story-placeholder';

          return GestureDetector(
            onTap: () {
              if (isYou && isPlaceholder) {
                _showAddStoryDialog(context, state);
              } else {
                state.openStory(story);
                showDialog(
                  context: context,
                  builder: (ctx) => OnSetStoryViewerDialog(
                    story: story,
                    appState: state,
                    onClose: () {
                      state.closeStory();
                      Navigator.of(ctx).pop();
                    },
                  ),
                );
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: (isYou && isPlaceholder)
                            ? null
                            : const SweepGradient(
                                colors: [
                                  CineColors.gold,
                                  CineColors.goldLight,
                                  Color(0xFFF59E0B),
                                  CineColors.gold,
                                ],
                              ),
                        border: (isYou && isPlaceholder)
                            ? Border.all(color: CineColors.border, width: 1.5)
                            : null,
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: CineColors.surface,
                        ),
                        child: Center(
                          child: Text(
                            story.initials,
                            style: TextStyle(
                              fontSize: isYou ? 11 : 14,
                              fontWeight: FontWeight.w800,
                              color: (isYou && isPlaceholder)
                                  ? CineColors.textMuted
                                  : CineColors.gold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isYou)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showAddStoryDialog(context, state),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: CineColors.gold,
                              border: Border.all(color: CineColors.surface, width: 1.5),
                            ),
                            child: const Icon(Icons.add, size: 13, color: Colors.black),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 62,
                  child: Text(
                    isYou ? 'Your Story' : story.creatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isYou ? FontWeight.w500 : FontWeight.w700,
                      color: isYou ? CineColors.textMuted : CineColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PublishStoryDialog extends StatefulWidget {
  final CineAppState appState;

  const _PublishStoryDialog({required this.appState});

  @override
  State<_PublishStoryDialog> createState() => _PublishStoryDialogState();
}

class _PublishStoryDialogState extends State<_PublishStoryDialog> {
  late final TextEditingController _captionController;
  late final TextEditingController _locationController;
  late final TextEditingController _craftController;
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedFile;
  String? _selectedFileName;
  int? _selectedFileSizeBytes;
  String? _selectedFileMimeType;
  String? _cachedUploadedMediaUrl;

  bool _isUploading = false;
  String? _uploadStatusMessage;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
    _locationController = TextEditingController(
      text: widget.appState.myProfile?.hubLocation ?? 'Stage 4, Annapurna Studios',
    );
    _craftController = TextEditingController(
      text: widget.appState.myProfile?.primaryCraft ?? 'Cinematographer (ISC)',
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _craftController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(bool isVideo) async {
    if (_isUploading) return;
    try {
      final XFile? file = isVideo
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);

      if (file == null) {
        // Picker cancelled -> preserve existing selection
        return;
      }

      final length = await file.length();
      if (length > 100 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: CineColors.surfaceElevated,
              content: Text(
                'Media exceeds the 100 MB limit for on-set stories.',
                style: TextStyle(color: CineColors.error),
              ),
            ),
          );
        }
        return;
      }

      final mime = MediaUploadService.resolveMimeType(file.name);
      if (!mime.startsWith('image/') && !mime.startsWith('video/')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: CineColors.surfaceElevated,
              content: Text(
                'Unsupported format. Please select an image (JPG, PNG, WebP) or video (MP4, MOV, WebM).',
                style: TextStyle(color: CineColors.error),
              ),
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedFile = file;
        _selectedFileName = file.name;
        _selectedFileSizeBytes = length;
        _selectedFileMimeType = mime;
        _cachedUploadedMediaUrl = null; // Selecting a new file clears old upload cache
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text('Could not access gallery: $e', style: const TextStyle(color: CineColors.error)),
          ),
        );
      }
    }
  }

  void _removeSelectedMedia() {
    if (_isUploading) return;
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _selectedFileSizeBytes = null;
      _selectedFileMimeType = null;
      _cachedUploadedMediaUrl = null;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _handleBroadcast() async {
    if (_selectedFile == null && _cachedUploadedMediaUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: CineColors.surfaceElevated,
          content: Text('Please select an image or video for your story.', style: TextStyle(color: CineColors.error)),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusMessage = _cachedUploadedMediaUrl != null
          ? 'Broadcasting story...'
          : 'Streaming media to MinIO storage...';
    });

    String mediaUrl;
    if (_cachedUploadedMediaUrl != null) {
      mediaUrl = _cachedUploadedMediaUrl!;
    } else {
      try {
        final uploadResult = await widget.appState.apiService.uploadPublicXFile(
          file: _selectedFile!,
          contentType: _selectedFileMimeType!,
        );
        mediaUrl = uploadResult.publicUrl;
        _cachedUploadedMediaUrl = mediaUrl; // Retain cached reference in case Story creation fails
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadStatusMessage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: CineColors.surfaceElevated,
              content: Text('Media upload failed: $e', style: const TextStyle(color: CineColors.error)),
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _uploadStatusMessage = 'Broadcasting 24-hour on-set story...';
      });
    }

    try {
      await widget.appState.publishStory(
        mediaUrl: mediaUrl,
        caption: _captionController.text.trim(),
        location: _locationController.text.trim(),
        craftBadge: _craftController.text.trim(),
      );
      _cachedUploadedMediaUrl = null; // Clear cache on confirmed success
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text(
              'On-Set Story broadcast successfully! Visible for 24 hours.',
              style: TextStyle(color: CineColors.gold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text(
              'Failed to publish story: $e. Your media is saved, tap Broadcast Live to retry.',
              style: const TextStyle(color: CineColors.error),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CineColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CineColors.border),
      ),
      title: const Row(
        children: [
          Icon(Icons.video_camera_back_rounded, color: CineColors.gold, size: 22),
          SizedBox(width: 8),
          Text(
            'Publish On-Set Story',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: CineColors.textPrimary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Broadcast an ephemeral 24-hour on-set production update to your cinema network.',
              style: TextStyle(fontSize: 11.5, color: CineColors.textMuted),
            ),
            const SizedBox(height: 14),

            // Soundstage Location
            const Text('Soundstage / Location:', style: TextStyle(fontSize: 11, color: CineColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _locationController,
              enabled: !_isUploading,
              style: const TextStyle(color: CineColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Stage 4, Ramoji Film City',
                filled: true,
                fillColor: CineColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: CineColors.border),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Craft Badge
            const Text('Craft Badge:', style: TextStyle(fontSize: 11, color: CineColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _craftController,
              enabled: !_isUploading,
              style: const TextStyle(color: CineColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Cinematography / Camera Operator',
                filled: true,
                fillColor: CineColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: CineColors.border),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Production Caption
            const Text('Production Caption / Slate:', style: TextStyle(fontSize: 11, color: CineColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: _captionController,
              enabled: !_isUploading,
              maxLines: 2,
              style: const TextStyle(color: CineColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Master shot rehearsed with 35mm anamorphic prime.',
                filled: true,
                fillColor: CineColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: CineColors.border),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Media Selection Section
            const Text('Story Media (Image or Video):', style: TextStyle(fontSize: 11, color: CineColors.textMuted)),
            const SizedBox(height: 6),

            if (_selectedFile == null && _cachedUploadedMediaUrl == null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CineColors.gold,
                        side: const BorderSide(color: CineColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isUploading ? null : () => _pickMedia(false),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Add Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CineColors.gold,
                        side: const BorderSide(color: CineColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isUploading ? null : () => _pickMedia(true),
                      icon: const Icon(Icons.videocam_outlined, size: 18),
                      label: const Text('Add Video', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: CineColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CineColors.gold.withValues(alpha: 0.6), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      (_selectedFileMimeType?.startsWith('video/') ?? false)
                          ? Icons.videocam_rounded
                          : Icons.image_rounded,
                      color: CineColors.gold,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName ?? 'Uploaded Story Media',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: CineColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (_selectedFileSizeBytes != null)
                                Text(
                                  _formatFileSize(_selectedFileSizeBytes!),
                                  style: const TextStyle(fontSize: 10, color: CineColors.textMuted),
                                ),
                              if (_cachedUploadedMediaUrl != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade900.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.green.shade400, width: 0.6),
                                  ),
                                  child: const Text(
                                    'MinIO Uploaded',
                                    style: TextStyle(fontSize: 8.5, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!_isUploading) ...[
                      TextButton(
                        onPressed: () => _pickMedia(_selectedFileMimeType?.startsWith('video/') ?? false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Change', style: TextStyle(color: CineColors.gold, fontSize: 11)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: CineColors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _removeSelectedMedia,
                      ),
                    ],
                  ],
                ),
              ),
            ],

            if (_isUploading) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(CineColors.gold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _uploadStatusMessage ?? 'Processing...',
                      style: const TextStyle(fontSize: 11, color: CineColors.gold),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: CineColors.gold,
            foregroundColor: Colors.black,
            disabledBackgroundColor: CineColors.gold.withValues(alpha: 0.4),
          ),
          onPressed: _isUploading ? null : _handleBroadcast,
          child: const Text('Broadcast Live', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
