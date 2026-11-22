import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';

class CreateActionSheet extends StatefulWidget {
  final CineAppState appState;

  const CreateActionSheet({super.key, required this.appState});

  @override
  State<CreateActionSheet> createState() => _CreateActionSheetState();
}

class _CreateActionSheetState extends State<CreateActionSheet> {
  final TextEditingController _captionController = TextEditingController();
  bool _hasSelectedVideo = false;
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

  void _selectVideo() {
    setState(() => _hasSelectedVideo = true);
  }

  void _cycleAudio() {
    final index = _audioOptions.indexOf(_selectedAudio);
    setState(() {
      _selectedAudio = _audioOptions[(index + 1) % _audioOptions.length];
    });
  }

  void _shareReel() {
    if (!_hasSelectedVideo) {
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

    final caption = _captionController.text.trim();
    final reel = CineReelItem(
      id: 'reel-${DateTime.now().millisecondsSinceEpoch}',
      creatorName: 'You (DOP / Talent)',
      creatorCraft: 'Cinematographer (ISC)',
      creatorAvatar: 'YOU',
      title: caption.isEmpty ? 'New reel from the set' : caption,
      audioTrack: _selectedAudio,
      smpteTimecode: 'TC 00:00:30:00',
      craftSpecialty: 'Cinematography / DOP',
      likesCount: 0,
      commentsCount: 0,
      reelType: 'Reel',
    );

    widget.appState.addReel(reel);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: CineColors.surfaceElevated,
        content: Text(
          'Reel shared to your profile',
          style: TextStyle(color: CineColors.gold, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                              colors: _hasSelectedVideo
                                  ? [const Color(0xFF2A2412), const Color(0xFF0D0E12)]
                                  : [CineColors.surfaceElevated, const Color(0xFF0D0E12)],
                            ),
                            border: Border.all(
                              color: _hasSelectedVideo ? CineColors.gold : CineColors.border,
                              width: _hasSelectedVideo ? 1.5 : 1,
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
                              Center(
                                child: Column(
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
                                        _hasSelectedVideo
                                            ? Icons.movie_creation_rounded
                                            : Icons.add_rounded,
                                        color: CineColors.gold,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _hasSelectedVideo
                                          ? 'Reel selected • 00:30'
                                          : 'Tap to select a reel',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: CineColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _hasSelectedVideo
                                          ? 'Tap again to replace'
                                          : 'Choose a 9:16 clip from your camera roll',
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
                          onPressed: _shareReel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CineColors.gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Share reel',
                            style: TextStyle(
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
