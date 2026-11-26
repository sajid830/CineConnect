import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';
import '../../core/services/media_upload_service.dart';
import '../production_house/data/models/portfolio_item.dart';
import '../production_house/applications/audition_video_player_dialog.dart';

class DigitalSlateProfileView extends StatefulWidget {
  final CineAppState appState;

  const DigitalSlateProfileView({super.key, required this.appState});

  @override
  State<DigitalSlateProfileView> createState() => _DigitalSlateProfileViewState();
}

class _DigitalSlateProfileViewState extends State<DigitalSlateProfileView> {
  int _activeTab = 0;
  File? _localAvatarFile;

  void _showProfilePhotoPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CineColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CineColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CineColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: CineColors.gold),
                title: const Text('Take Photo', style: TextStyle(color: CineColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: const Text('Capture with device camera', style: TextStyle(color: CineColors.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: CineColors.gold),
                title: const Text('Choose from Gallery', style: TextStyle(color: CineColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: const Text('Select photo from mobile device gallery', style: TextStyle(color: CineColors.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: CineColors.error),
                title: const Text('Remove Picture', style: TextStyle(color: CineColors.error, fontWeight: FontWeight.w600)),
                subtitle: const Text('Delete current profile photo', style: TextStyle(color: CineColors.textMuted, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeProfileAvatar();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfileAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      if (!mounted) return;

      setState(() {
        _localAvatarFile = File(picked.path);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: CineColors.surfaceElevated,
          content: Text('Updating profile photo...', style: TextStyle(color: CineColors.gold)),
        ),
      );

      final mime = MediaUploadService.resolveMimeType(picked.name);
      final uploadRes = await widget.appState.apiService.uploadPublicXFile(
        file: picked,
        contentType: mime,
      );

      await widget.appState.updateMyProfile({'avatar_url': uploadRes.publicUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text('Profile photo updated successfully!', style: TextStyle(color: CineColors.gold)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text('Could not upload photo: $e', style: const TextStyle(color: CineColors.error)),
          ),
        );
      }
    }
  }

  Future<void> _removeProfileAvatar() async {
    try {
      final currentAvatar = widget.appState.myProfile?.avatarUrl;
      final hasLocal = _localAvatarFile != null;
      final hasRemote = currentAvatar != null && currentAvatar.trim().isNotEmpty && !currentAvatar.trim().startsWith(RegExp(r'^[A-Z]{1,2}$'));
      if (!hasLocal && !hasRemote) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: CineColors.surfaceElevated,
              content: Text('No profile photo to remove.', style: TextStyle(color: CineColors.textMuted)),
            ),
          );
        }
        return;
      }

      setState(() {
        _localAvatarFile = null;
      });

      await widget.appState.updateMyProfile({'avatar_url': ''});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text('Profile photo removed.', style: TextStyle(color: CineColors.gold)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text('Could not remove photo: $e', style: const TextStyle(color: CineColors.error)),
          ),
        );
      }
    }
  }

  void _showShareProfileSheet(TalentProfile talent) {
    final profileUrl = 'https://cineconnect.app/@${talent.handle.replaceAll('@', '')}';
    showModalBottomSheet(
      context: context,
      backgroundColor: CineColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CineColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Share Profile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CineColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CineColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CineColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: CineColors.gold,
                      child: Text(
                        talent.avatarUrl.length <= 3 ? talent.avatarUrl : 'SA',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(talent.fullName, style: const TextStyle(fontWeight: FontWeight.bold, color: CineColors.textPrimary, fontSize: 13)),
                          Text(talent.handle, style: const TextStyle(color: CineColors.textMuted, fontSize: 11)),
                          Text(profileUrl, style: const TextStyle(color: CineColors.gold, fontSize: 11), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.link_rounded, color: CineColors.gold),
                title: const Text('Copy Profile Link', style: TextStyle(color: CineColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: const Text('Copy link to clipboard to share anywhere', style: TextStyle(color: CineColors.textMuted, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(sCtx);
                  await Clipboard.setData(ClipboardData(text: profileUrl));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: CineColors.surfaceElevated,
                        content: Text('Profile link copied to clipboard!', style: TextStyle(color: CineColors.gold)),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: CineColors.gold),
                title: const Text('Share via Apps / WhatsApp', style: TextStyle(color: CineColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: const Text('Open device apps (WhatsApp, Instagram, etc.) to share', style: TextStyle(color: CineColors.textMuted, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(sCtx);
                  final shareText = 'Check out ${talent.fullName} (${talent.primaryCraft}) on CineConnect: $profileUrl';
                  await _shareViaNativeApps(
                    text: shareText,
                    title: 'Share Profile via',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const MethodChannel _nativeShareChannel = MethodChannel('cineconnect/native_share');

  Future<void> _shareViaNativeApps({required String text, String title = 'Share Profile'}) async {
    try {
      await _nativeShareChannel.invokeMethod('shareText', {
        'text': text,
        'title': title,
      });
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: CineColors.surfaceElevated,
            content: Text('Profile link copied to clipboard!', style: TextStyle(color: CineColors.gold)),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.appState.myProfile == null) {
      widget.appState.loadMyProfile();
    }
    widget.appState.loadMyPortfolio();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.appState.isLoadingProfile && widget.appState.myProfile == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: CircularProgressIndicator(color: CineColors.gold),
        ),
      );
    }

    final talent = widget.appState.myProfile;
    if (talent == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline_rounded, size: 48, color: CineColors.gold),
              const SizedBox(height: 12),
              const Text(
                'Could not load profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CineColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please check your network connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: CineColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => widget.appState.loadMyProfile(refresh: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CineColors.gold,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final postsCount = widget.appState.reels.length + widget.appState.feedPosts.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showProfilePhotoPickerSheet,
                  child: Stack(
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: [
                              CineColors.gold,
                              CineColors.goldLight,
                              Color(0xFFF59E0B),
                              CineColors.gold,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CineColors.gold.withValues(alpha: 0.25),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: CineColors.surface,
                          ),
                          child: ClipOval(
                            child: _localAvatarFile != null
                                ? Image.file(_localAvatarFile!, fit: BoxFit.cover, width: 80, height: 80)
                                : (talent.avatarUrl.startsWith('http')
                                    ? Image.network(
                                        talent.avatarUrl,
                                        fit: BoxFit.cover,
                                        width: 80,
                                        height: 80,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            talent.avatarUrl.length <= 3 ? talent.avatarUrl : 'SA',
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w900,
                                              color: CineColors.gold,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          talent.avatarUrl,
                                          style: const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            color: CineColors.gold,
                                          ),
                                        ),
                                      )),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CineColors.gold,
                            border: Border.all(color: CineColors.surface, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('$postsCount', 'posts'),
                      _stat('${talent.connectionsCount}', 'followers'),
                      _stat(talent.endorsementsCount != null ? '${talent.endorsementsCount}' : '0', 'following'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    talent.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: CineColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.verified, size: 14, color: CineColors.gold),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Text(
              talent.primaryCraft,
              style: const TextStyle(fontSize: 12, color: CineColors.goldLight),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              talent.headline,
              style: const TextStyle(
                fontSize: 12,
                color: CineColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 13, color: CineColors.textMuted),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    '${talent.hubLocation} • ${talent.immediateAvailability}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: CineColors.textMuted),
                  ),
                ),
                Text(
                  talent.dailyCallSheetRate,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CineColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openAddPortfolioMediaDialog(context),
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 14),
                    label: const Text(
                      'Add Media',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CineColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openEditProfileDialog(context, talent),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CineColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Edit profile',
                      style: TextStyle(fontSize: 12, color: CineColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showShareProfileSheet(talent),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CineColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Share profile',
                      style: TextStyle(fontSize: 12, color: CineColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: CineColors.border, width: 0.8),
                bottom: BorderSide(color: CineColors.border, width: 0.8),
              ),
            ),
            child: Row(
              children: [
                _tab(Icons.grid_on_rounded, 0),
                _tab(Icons.play_circle_outline_rounded, 1),
              ],
            ),
          ),
          _buildGrid(talent),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: CineColors.textPrimary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: CineColors.textMuted),
        ),
      ],
    );
  }

  Widget _tab(IconData icon, int index) {
    final selected = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? CineColors.gold : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? CineColors.gold : CineColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(TalentProfile talent) {
    if (_activeTab == 0) {
      if (widget.appState.isLoadingPortfolio && widget.appState.myPortfolio.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(CineColors.gold),
            ),
          ),
        );
      }
      final portfolio = widget.appState.myPortfolio;
      if (portfolio.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.photo_library_outlined, size: 48, color: CineColors.textMuted),
                const SizedBox(height: 12),
                const Text(
                  'No portfolio media yet',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: CineColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add acting showreels, headshots, or production stills to showcase your craft.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: CineColors.textMuted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openAddPortfolioMediaDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Portfolio Media'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CineColors.gold,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 0.85,
        ),
        itemCount: portfolio.length,
        itemBuilder: (context, index) {
          final item = portfolio[index];
          final isVideo = item.type == PortfolioType.showreel || item.type == PortfolioType.film;
          final thumbOrPhoto = item.thumbnailUrl ?? ((item.type == PortfolioType.photo) ? (item.playbackUrl ?? item.mediaUrl) : null);

          return GestureDetector(
            onTap: () => _showPortfolioMediaDetails(item),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141419),
                border: Border.all(color: CineColors.border, width: 0.5),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbOrPhoto != null)
                    Image.network(
                      thumbOrPhoto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultPortfolioTile(item),
                    )
                  else
                    _defaultPortfolioTile(item),
                  if (isVideo)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: CineColors.gold, size: 24),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 12, 5, 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: CineColors.textPrimary,
                            ),
                          ),
                          Text(
                            item.type.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 8,
                              color: CineColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    if (_activeTab == 1) {
      final reels = widget.appState.reels;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 0.72,
        ),
        itemCount: reels.length,
        itemBuilder: (context, index) {
          final reel = reels[index];
          return _gridTile(
            icon: Icons.play_arrow_rounded,
            title: reel.title,
            subtitle: reel.reelType,
            colors: [const Color(0xFF2A2412), const Color(0xFF141419)],
            onTap: () => _showInfo(reel.title),
          );
        },
      );
    }

    if (_activeTab == 2) {
      final credits = widget.appState.myFilmography.isNotEmpty
          ? widget.appState.myFilmography
          : talent.filmography;
      if (credits.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_edu_rounded, size: 48, color: CineColors.gold),
                const SizedBox(height: 12),
                const Text(
                  'No Film Credits Yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CineColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add verified film projects and productions to your slate.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: CineColors.textMuted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openAddFilmCreditDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Film Credit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CineColors.gold,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Verified Filmography (${credits.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CineColors.gold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openAddFilmCreditDialog(context),
                  icon: const Icon(Icons.add, size: 16, color: CineColors.gold),
                  label: const Text('Add Credit', style: TextStyle(color: CineColors.gold, fontSize: 12)),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: credits.length,
            itemBuilder: (context, index) {
              final credit = credits[index];
              return _gridTile(
                icon: Icons.verified_rounded,
                title: credit.filmTitle,
                subtitle: '${credit.releaseYear}',
                colors: [const Color(0xFF102A2A), const Color(0xFF141419)],
                onTap: () => _showCreditActionsSheet(context, credit),
              );
            },
          ),
        ],
      );
    }

    final posts = widget.appState.feedPosts;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _gridTile(
          icon: Icons.movie_creation_outlined,
          title: post.videoSlateTitle,
          subtitle: post.authorCraft,
          colors: [const Color(0xFF1A1A2A), const Color(0xFF141419)],
          onTap: () => _showInfo(post.videoSlateTitle),
        );
      },
    );
  }

  Widget _gridTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(color: CineColors.border, width: 0.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(icon, size: 28, color: CineColors.gold),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 14, 5, 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: CineColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8,
                        color: CineColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultPortfolioTile(PortfolioItem item) {
    IconData icon;
    switch (item.type) {
      case PortfolioType.film:
        icon = Icons.movie_outlined;
        break;
      case PortfolioType.showreel:
        icon = Icons.play_circle_outline;
        break;
      case PortfolioType.photo:
        icon = Icons.photo_library_outlined;
        break;
      case PortfolioType.audio:
        icon = Icons.graphic_eq;
        break;
      case PortfolioType.other:
        icon = Icons.folder_open_outlined;
        break;
    }
    return Container(
      color: const Color(0xFF181922),
      child: Center(
        child: Icon(icon, color: CineColors.gold, size: 30),
      ),
    );
  }

  void _showPortfolioMediaDetails(PortfolioItem item) {
    final activeMediaUrl = item.playbackUrl ?? item.mediaUrl;
    final isVideo = item.type == PortfolioType.showreel || item.type == PortfolioType.film;
    final isPhoto = item.type == PortfolioType.photo;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13141C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: CineColors.gold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.type.label} • ${item.year}',
                          style: const TextStyle(color: CineColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: CineColors.textMuted),
                    onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (item.description.isNotEmpty) ...[
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 14, color: CineColors.textPrimary, height: 1.4),
                ),
                const SizedBox(height: 16),
              ],
              if (isPhoto && activeMediaUrl != null && activeMediaUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    width: double.infinity,
                    color: const Color(0xFF1A1B24),
                    child: Image.network(
                      activeMediaUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(CineColors.gold),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (ctx, error, stackTrace) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Unable to load photo preview',
                            style: TextStyle(color: CineColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (isVideo && activeMediaUrl != null && activeMediaUrl.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(bottomSheetCtx).pop();
                      showDialog<void>(
                        context: context,
                        barrierDismissible: true,
                        builder: (_) => AuditionVideoPlayerDialog(
                          downloadUrl: activeMediaUrl,
                          candidateName: item.title,
                          projectTitle: 'Portfolio Showreel',
                          onRefreshUrl: () async {
                            final fresh = await widget.appState.refreshPortfolioDownloadUrl(item.id);
                            return fresh ?? activeMediaUrl;
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
                    label: const Text('Play Showreel / Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CineColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF13141C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: CineColors.gold, width: 1),
                        ),
                        title: const Text('Delete Portfolio Asset', style: TextStyle(color: CineColors.textPrimary)),
                        content: const Text(
                          'Are you sure you want to delete this media asset from your portfolio? It will be removed from your digital slate and unreferenced media files will be cleaned up.',
                          style: TextStyle(color: CineColors.textMuted),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dCtx).pop(false),
                            child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(dCtx).pop(true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      if (bottomSheetCtx.mounted) {
                        Navigator.of(bottomSheetCtx).pop();
                      }
                      try {
                        await widget.appState.deletePortfolioItem(item.id);
                        _showInfo('Portfolio asset removed');
                      } catch (e) {
                        _showInfo('Failed to delete asset: $e');
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                  label: const Text('Delete from Slate', style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 0.8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddPortfolioMediaDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String mediaType = 'video';
    XFile? selectedFile;
    String? selectedFileName;
    int? selectedFileSize;
    String? selectedMimeType;
    bool isUploading = false;
    String? uploadError;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickMedia() async {
            if (isUploading) return;
            try {
              XFile? file;
              if (mediaType == 'video') {
                file = await picker.pickVideo(source: ImageSource.gallery);
              } else {
                file = await picker.pickImage(source: ImageSource.gallery);
              }
              if (file == null) return;

              final length = await file.length();
              final maxBytes = (mediaType == 'video') ? 100 * 1024 * 1024 : 25 * 1024 * 1024;
              if (length > maxBytes) {
                setDialogState(() {
                  uploadError = (mediaType == 'video')
                      ? 'Video exceeds 100 MB maximum size limit.'
                      : 'Image exceeds 25 MB maximum size limit.';
                });
                return;
              }

              final mime = MediaUploadService.resolveMimeType(file.name);
              if (mediaType == 'video' && !mime.startsWith('video/')) {
                setDialogState(() {
                  uploadError = 'Please select a valid video file (MP4, MOV, MKV, or WEBM).';
                });
                return;
              }
              if (mediaType == 'image' && !mime.startsWith('image/')) {
                setDialogState(() {
                  uploadError = 'Please select a valid image file (JPG, PNG, or WEBP).';
                });
                return;
              }

              final pickedFile = file;
              setDialogState(() {
                selectedFile = pickedFile;
                selectedFileName = pickedFile.name;
                selectedFileSize = length;
                selectedMimeType = mime;
                uploadError = null;
              });
            } catch (e) {
              setDialogState(() {
                uploadError = 'Failed to select media: $e';
              });
            }
          }

          Future<void> submit() async {
            final title = titleCtrl.text.trim();
            if (title.isEmpty) {
              setDialogState(() => uploadError = 'Please enter a title for this portfolio asset.');
              return;
            }
            if (selectedFile == null) {
              setDialogState(() => uploadError = 'Please select a media file to upload.');
              return;
            }

            setDialogState(() {
              isUploading = true;
              uploadError = null;
            });

            try {
              final mediaUploadService = MediaUploadService();
              final uploadResult = await mediaUploadService.uploadXFile(
                file: selectedFile!,
                contentType: selectedMimeType ?? (mediaType == 'video' ? 'video/mp4' : 'image/jpeg'),
                purpose: 'public', // REQUIRED: Portfolio must be public storage
              );

              await widget.appState.addPortfolioItem(
                title: title,
                mediaUrl: uploadResult.publicUrl,
                description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                mediaType: mediaType,
              );

              if (ctx.mounted) {
                Navigator.of(dialogCtx).pop();
                _showInfo('Portfolio asset added successfully!');
              }
            } catch (e) {
              if (ctx.mounted) {
                setDialogState(() {
                  isUploading = false;
                  uploadError = 'Upload or creation failed: $e';
                });
              }
            }
          }

          final sizeMb = selectedFileSize != null ? (selectedFileSize! / (1024 * 1024)).toStringAsFixed(1) : null;

          return AlertDialog(
            backgroundColor: const Color(0xFF13141C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: CineColors.gold, width: 1.2),
            ),
            title: const Row(
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: CineColors.gold),
                SizedBox(width: 8),
                Text(
                  'Add Portfolio Media',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CineColors.textPrimary),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Video / Showreel'),
                        selected: mediaType == 'video',
                        selectedColor: CineColors.gold,
                        labelStyle: TextStyle(
                          color: mediaType == 'video' ? Colors.black : CineColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: isUploading ? null : (selected) {
                          if (selected) {
                            setDialogState(() {
                              mediaType = 'video';
                              selectedFile = null;
                              selectedFileName = null;
                              selectedFileSize = null;
                              uploadError = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Photo / Still'),
                        selected: mediaType == 'image',
                        selectedColor: CineColors.gold,
                        labelStyle: TextStyle(
                          color: mediaType == 'image' ? Colors.black : CineColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: isUploading ? null : (selected) {
                          if (selected) {
                            setDialogState(() {
                              mediaType = 'image';
                              selectedFile = null;
                              selectedFileName = null;
                              selectedFileSize = null;
                              uploadError = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    enabled: !isUploading,
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      hintText: mediaType == 'video' ? 'e.g. Acting Showreel 2026' : 'e.g. Character Headshot',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    enabled: !isUploading,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Brief context, role details, or festival highlights...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: isUploading ? null : pickMedia,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1C26),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedFile != null ? CineColors.gold : CineColors.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFile != null
                                ? (mediaType == 'video' ? Icons.videocam : Icons.image)
                                : Icons.upload_file,
                            color: selectedFile != null ? CineColors.gold : CineColors.textMuted,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedFileName ?? (mediaType == 'video' ? 'Select Video File (max 100 MB)' : 'Select Image File (max 25 MB)'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selectedFile != null ? FontWeight.bold : FontWeight.normal,
                                    color: selectedFile != null ? CineColors.textPrimary : CineColors.textMuted,
                                  ),
                                ),
                                if (sizeMb != null)
                                  Text(
                                    '$sizeMb MB • Ready to upload',
                                    style: const TextStyle(fontSize: 11, color: CineColors.gold),
                                  ),
                              ],
                            ),
                          ),
                          if (selectedFile != null && !isUploading)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: CineColors.textMuted),
                              onPressed: () => setDialogState(() {
                                selectedFile = null;
                                selectedFileName = null;
                                selectedFileSize = null;
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (uploadError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      uploadError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                  if (isUploading) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: CineColors.gold),
                        ),
                        SizedBox(width: 10),
                        Text('Streaming to CineConnect storage...', style: TextStyle(fontSize: 12, color: CineColors.gold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: isUploading ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CineColors.gold,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                child: Text(isUploading ? 'Uploading...' : 'Save to Slate'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CineColors.surfaceElevated,
        content: Text(message, style: const TextStyle(color: CineColors.gold)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openEditProfileDialog(BuildContext context, TalentProfile talent) {
    final nameCtrl = TextEditingController(text: talent.fullName);
    final handleCtrl = TextEditingController(text: talent.handle);
    final headlineCtrl = TextEditingController(text: talent.headline);
    final craftCtrl = TextEditingController(text: talent.primaryCraft);
    final guildCtrl = TextEditingController(text: talent.guildId);
    final locationCtrl = TextEditingController(text: talent.hubLocation);
    final rateCtrl = TextEditingController(text: talent.dailyCallSheetRate);
    final availCtrl = TextEditingController(text: talent.immediateAvailability);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13141C),
        title: const Text(
          'Edit Slate Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CineColors.gold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: handleCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Handle (@username)', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: craftCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Primary Craft', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: headlineCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Headline', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: guildCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Guild ID (e.g. ISC-9021)', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Location / Hub', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rateCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Call-Sheet Rate', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: availCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Availability', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CineColors.gold, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await widget.appState.updateMyProfile({
                  'full_name': nameCtrl.text.trim(),
                  'handle': handleCtrl.text.trim(),
                  'role': craftCtrl.text.trim(),
                  'headline': headlineCtrl.text.trim(),
                  'guild_id': guildCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'daily_call_sheet_rate': rateCtrl.text.trim(),
                  'immediate_availability': availCtrl.text.trim(),
                });
                if (context.mounted && mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update profile: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openAddFilmCreditDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: '${DateTime.now().year}');
    final roleCtrl = TextEditingController(text: widget.appState.myProfile?.primaryCraft ?? '');
    final dirCtrl = TextEditingController();
    final studioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13141C),
        title: const Text(
          'Add Verified Film Credit',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CineColors.gold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Film Title *', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Release Year *', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: roleCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Craft Role *', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dirCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Director Name', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: studioCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Studio / Production Banner', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CineColors.gold, foregroundColor: Colors.black),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty || roleCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill title and role')),
                );
                return;
              }
              Navigator.of(ctx).pop();
              try {
                await widget.appState.addFilmCredit({
                  'film_title': titleCtrl.text.trim(),
                  'release_year': int.tryParse(yearCtrl.text.trim()) ?? DateTime.now().year,
                  'craft_role': roleCtrl.text.trim(),
                  'director_name': dirCtrl.text.trim().isNotEmpty ? dirCtrl.text.trim() : null,
                  'studio_banner': studioCtrl.text.trim().isNotEmpty ? studioCtrl.text.trim() : null,
                  'verified_by_guild': false,
                });
                if (context.mounted && mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Film credit added to your slate!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add credit: $e')),
                  );
                }
              }
            },
            child: const Text('Add Credit'),
          ),
        ],
      ),
    );
  }

  void _openEditFilmCreditDialog(BuildContext context, VerifiedFilmCredit credit) {
    final titleCtrl = TextEditingController(text: credit.filmTitle);
    final yearCtrl = TextEditingController(text: '${credit.releaseYear}');
    final roleCtrl = TextEditingController(text: credit.craftRole);
    final dirCtrl = TextEditingController(text: credit.directorName);
    final studioCtrl = TextEditingController(text: credit.studioBanner);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13141C),
        title: const Text(
          'Edit Film Credit',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CineColors.gold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Film Title *', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Release Year *', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: roleCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Craft Role *', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dirCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Director Name', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: studioCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Studio / Production Banner', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CineColors.gold, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await widget.appState.updateFilmCredit(credit.id, {
                  'film_title': titleCtrl.text.trim(),
                  'release_year': int.tryParse(yearCtrl.text.trim()) ?? credit.releaseYear,
                  'craft_role': roleCtrl.text.trim(),
                  'director_name': dirCtrl.text.trim().isNotEmpty ? dirCtrl.text.trim() : null,
                  'studio_banner': studioCtrl.text.trim().isNotEmpty ? studioCtrl.text.trim() : null,
                });
                if (context.mounted && mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Film credit updated!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update credit: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCreditActionsSheet(BuildContext context, VerifiedFilmCredit credit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    credit.filmTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CineColors.gold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CineColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${credit.releaseYear}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CineColors.gold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Role: ${credit.craftRole}',
              style: const TextStyle(fontSize: 13, color: CineColors.textPrimary),
            ),
            if (credit.directorName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Director: ${credit.directorName}',
                style: const TextStyle(fontSize: 12, color: CineColors.textMuted),
              ),
            ],
            if (credit.studioBanner.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Studio / Banner: ${credit.studioBanner}',
                style: const TextStyle(fontSize: 12, color: CineColors.textMuted),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  credit.verifiedByGuild ? Icons.verified : Icons.hourglass_top_rounded,
                  size: 14,
                  color: credit.verifiedByGuild ? CineColors.success : CineColors.gold,
                ),
                const SizedBox(width: 4),
                Text(
                  credit.verifiedByGuild ? 'Guild Verified' : 'Guild Verification Pending',
                  style: TextStyle(
                    fontSize: 11,
                    color: credit.verifiedByGuild ? CineColors.success : CineColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openEditFilmCreditDialog(context, credit);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CineColors.gold,
                      side: const BorderSide(color: CineColors.gold),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _confirmDeleteFilmCredit(context, credit);
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CineColors.error,
                      side: const BorderSide(color: CineColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFilmCredit(BuildContext context, VerifiedFilmCredit credit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13141C),
        title: const Text(
          'Delete Film Credit?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CineColors.error),
        ),
        content: Text(
          'Are you sure you want to remove "${credit.filmTitle}" from your verified slate?',
          style: const TextStyle(fontSize: 13, color: CineColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CineColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await widget.appState.deleteFilmCredit(credit.id);
                if (context.mounted && mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed "${credit.filmTitle}" from slate')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete credit: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
