import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/services/media_upload_service.dart';
import '../../core/state/app_state.dart';

class CreateActionSheet extends StatefulWidget {
  final CineAppState appState;

  const CreateActionSheet({super.key, required this.appState});

  @override
  State<CreateActionSheet> createState() => _CreateActionSheetState();
}

class _CreateActionSheetState extends State<CreateActionSheet> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedVideoFile;
  String? _selectedVideoFileName;
  int? _selectedVideoSizeBytes;
  String? _selectedVideoMimeType;
  String? _cachedUploadedMediaUrl;

  bool _isUploading = false;
  String? _uploadStatusMessage;

  bool _shareToFeed = true;
  bool _shareToStory = false;
  String _selectedAudio = 'Original audio';

  static const List<String> _audioOptions = [
    'Original audio',
    'Cinematic Score — A.R. Rahman',
    'Lo-fi Night Drive',
    'On-Set Ambience',
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _selectVideo() async {
    if (_isUploading) return;
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) {
        // User cancelled picker -> preserve existing selection
        return;
      }

      final length = await video.length();
      if (length > 100 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF3B1212),
              content: Text('Video exceeds the 100 MB maximum size limit.'),
            ),
          );
        }
        return;
      }

      final mimeType = MediaUploadService.resolveMimeType(video.name);
      if (!mimeType.startsWith('video/')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF3B1212),
              content: Text('Please select a valid video file (MP4, MOV, MKV, or WEBM).'),
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedVideoFile = video;
        _selectedVideoFileName = video.name;
        _selectedVideoSizeBytes = length;
        _selectedVideoMimeType = mimeType;
        _cachedUploadedMediaUrl = null; // Selecting a different video invalidates previous video cache
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B1212),
            content: Text('Could not access video picker: $e'),
          ),
        );
      }
    }
  }

  void _removeSelectedVideo() {
    if (_isUploading) return;
    setState(() {
      _selectedVideoFile = null;
      _selectedVideoFileName = null;
      _selectedVideoSizeBytes = null;
      _selectedVideoMimeType = null;
      _cachedUploadedMediaUrl = null;
    });
  }

  void _cycleAudio() {
    final index = _audioOptions.indexOf(_selectedAudio);
    setState(() {
      _selectedAudio = _audioOptions[(index + 1) % _audioOptions.length];
    });
  }

  Future<void> _shareReel() async {
    if (_isUploading) return;

    if (_selectedVideoFile == null && _cachedUploadedMediaUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: CineColors.surfaceElevated,
          content: Text(
            'Select a video for your reel first',
            style: TextStyle(color: CineColors.gold),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusMessage = _cachedUploadedMediaUrl != null
          ? 'Reusing uploaded media...'
          : 'Streaming video to MinIO storage...';
    });

    try {
      String? uploadedUrl = _cachedUploadedMediaUrl;
      if (uploadedUrl == null && _selectedVideoFile != null) {
        final uploadService = MediaUploadService();
        final uploadRes = await uploadService.uploadXFile(
          file: _selectedVideoFile!,
          contentType: _selectedVideoMimeType ?? 'video/mp4',
          purpose: 'public',
        );
        uploadedUrl = uploadRes.publicUrl;
        _cachedUploadedMediaUrl = uploadRes.publicUrl;
      }

      if (mounted) {
        setState(() {
          _uploadStatusMessage = 'Publishing showreel to cinema ledger...';
        });
      }

      final caption = _captionController.text.trim();
      final title = caption.isEmpty ? 'Cinematography Showreel' : caption;

      await widget.appState.addReel(
        title: title,
        mediaUrl: uploadedUrl!,
        caption: caption.isNotEmpty ? caption : null,
        audioTrack: _selectedAudio,
        smpteTimecode: '00:00:30:00',
        craftSpecialty: widget.appState.myProfile?.primaryCraft ?? 'Cinematography / DOP',
        reelType: 'Cinematography Showreel',
      );

      // On successful creation: clear retry cache, close modal and show success
      _cachedUploadedMediaUrl = null;

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text(
              'Reel published successfully!',
              style: TextStyle(color: CineColors.gold, fontWeight: FontWeight.w700),
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
            backgroundColor: const Color(0xFF3B1212),
            content: Text('Failed to publish reel: $e. Tap Share to retry.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedVideoFile != null || _cachedUploadedMediaUrl != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
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
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                padding: const EdgeInsets.fromLTRB(8, 2, 12, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: CineColors.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'New reel',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: CineColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    if (_isUploading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(CineColors.gold),
                        ),
                      )
                    else
                      TextButton(
                        onPressed: _shareReel,
                        child: const Text(
                          'Share',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: CineColors.gold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: CineColors.border),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _selectVideo,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 290,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: hasSelection
                                  ? [const Color(0xFF2A2412), const Color(0xFF0D0E12)]
                                  : [CineColors.surfaceElevated, const Color(0xFF0D0E12)],
                            ),
                            border: Border.all(
                              color: hasSelection ? CineColors.gold : CineColors.border,
                              width: hasSelection ? 1.5 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '9:16',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: CineColors.gold,
                                    ),
                                  ),
                                ),
                              ),
                              if (hasSelection && !_isUploading)
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: GestureDetector(
                                    onTap: _removeSelectedVideo,
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                                      ),
                                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                                    ),
                                  ),
                                ),
                              Center(
                                child: _isUploading
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(CineColors.gold),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            _uploadStatusMessage ?? 'Processing video...',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: CineColors.goldLight,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: CineColors.gold.withValues(alpha: 0.15),
                                              border: Border.all(
                                                color: CineColors.gold.withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Icon(
                                              hasSelection
                                                  ? Icons.movie_creation_rounded
                                                  : Icons.add_rounded,
                                              color: CineColors.gold,
                                              size: 30,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            child: Text(
                                              hasSelection
                                                  ? (_selectedVideoFileName ?? 'Video selected')
                                                  : 'Tap to select a reel',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: CineColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            hasSelection
                                                ? '${(_selectedVideoSizeBytes != null ? (_selectedVideoSizeBytes! / (1024 * 1024)).toStringAsFixed(1) : '0')} MB • ${_cachedUploadedMediaUrl != null ? 'Uploaded (Cached)' : 'Tap again to replace'}'
                                                : 'Choose a 9:16 clip from your gallery (up to 100 MB)',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: CineColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _captionController,
                        maxLines: 3,
                        maxLength: 220,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: CineColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Write a caption for your reel...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: CineColors.textMuted,
                          ),
                          counterStyle: TextStyle(
                            fontSize: 10,
                            color: CineColors.textMuted,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildOptionRow(
                        icon: Icons.music_note_rounded,
                        title: 'Audio',
                        value: _selectedAudio,
                        onTap: _cycleAudio,
                      ),
                      const SizedBox(height: 8),
                      _buildOptionRow(
                        icon: Icons.person_add_alt_1_rounded,
                        title: 'Tag people',
                        value: 'Collaborators & crew',
                        onTap: () => _showInfo('People tagging'),
                      ),
                      const SizedBox(height: 8),
                      _buildOptionRow(
                        icon: Icons.location_on_outlined,
                        title: 'Add location',
                        value: 'Film city, stage or hub',
                        onTap: () => _showInfo('Location tagging'),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: CineColors.gold,
                          title: const Text(
                            'Also share to feed',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: CineColors.textPrimary,
                            ),
                          ),
                          value: _shareToFeed,
                          onChanged: (value) => setState(() => _shareToFeed = value),
                        ),
                      ),
                      Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: CineColors.gold,
                          title: const Text(
                            'Add to your story',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: CineColors.textPrimary,
                            ),
                          ),
                          value: _shareToStory,
                          onChanged: (value) => setState(() => _shareToStory = value),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUploading ? null : _shareReel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CineColors.gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _isUploading ? 'Uploading showreel...' : 'Share reel',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: CineColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CineColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: CineColors.gold),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: CineColors.textPrimary,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: CineColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 4),
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

  void _showInfo(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CineColors.surfaceElevated,
        content: Text(
          '$feature coming soon',
          style: const TextStyle(color: CineColors.gold),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
