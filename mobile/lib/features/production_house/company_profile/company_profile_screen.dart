import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/models/craft_models.dart';
import 'package:cineconnect/core/network/api_client.dart';
import 'package:cineconnect/core/network/api_endpoints.dart';
import 'package:cineconnect/core/utils/formatters.dart';
import 'package:cineconnect/features/production_house/data/models/company_profile.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/features/production_house/data/repositories/media_repository.dart';
import 'package:cineconnect/shared/widgets/app_card.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/shared/widgets/status_pill.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'package:cineconnect/features/production_house/collaboration/collaborations_provider.dart';
import 'package:cineconnect/features/production_house/home/home_provider.dart';
import 'package:cineconnect/features/production_house/notifications/notifications_provider.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_provider.dart';
import 'package:cineconnect/features/production_house/projects/projects_provider.dart';
import 'package:cineconnect/features/production_house/talent_discovery/talent_provider.dart';
import 'company_logo.dart';
import 'company_profile_provider.dart';

/// Provider for studio feed posts
final studioPostsProvider = FutureProvider.autoDispose.family<List<CineFeedPost>, String>((ref, studioId) async {
  final client = ApiClient();
  try {
    final res = await client.get(ApiEndpoints.postsCollection);
    if (res is List) {
      return res.map((e) => CineFeedPost.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (_) {}
  return [];
});

/// Clears and invalidates all user-specific Production House state and caches.
void invalidateProductionHouseState(WidgetRef ref) {
  ref.invalidate(companyProfileProvider);
  ref.invalidate(dashboardSummaryProvider);
  ref.invalidate(projectsProvider);
  ref.invalidate(opportunitiesProvider);
  ref.invalidate(applicationsProvider);
  ref.invalidate(applicationFilterProvider);
  ref.invalidate(collaborationsProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(talentFilterProvider);
  ref.invalidate(talentResultsProvider);
}

/// Clears and invalidates all user-specific Production House state on a ProviderContainer directly.
void invalidateProductionHouseContainer(ProviderContainer container) {
  container.invalidate(companyProfileProvider);
  container.invalidate(dashboardSummaryProvider);
  container.invalidate(projectsProvider);
  container.invalidate(opportunitiesProvider);
  container.invalidate(applicationsProvider);
  container.invalidate(applicationFilterProvider);
  container.invalidate(collaborationsProvider);
  container.invalidate(notificationsProvider);
  container.invalidate(talentFilterProvider);
  container.invalidate(talentResultsProvider);
}

class CompanyProfileScreen extends ConsumerWidget {
  final Future<void> Function()? onSignOut;

  const CompanyProfileScreen({super.key, this.onSignOut});

  void _openSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit studio profile'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/company-profile/edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Log out',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                try {
                  if (onSignOut != null) {
                    await onSignOut!();
                  } else {
                    await Supabase.instance.client.auth.signOut();
                  }
                  // Invalidate user-specific Production House providers before navigating
                  invalidateProductionHouseState(ref);

                  if (context.mounted) {
                    context.go('/role-selection');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.surface,
                        content: Text(
                          'Logged out of CineConnect',
                          style: TextStyle(color: AppColors.gold),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text(
                          'Sign out failed: ${e.toString()}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(companyProfileProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          profileAsync.valueOrNull?.companyName ?? 'Studio profile',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context, ref),
          ),
        ],
      ),
      body: AsyncBody<CompanyProfile>(
        value: profileAsync,
        errorMessage: 'Could not load your profile',
        onRetry: () => ref.invalidate(companyProfileProvider),
        data: (profile) => _ProfileView(profile: profile),
      ),
    );
  }
}

class _ProfileView extends ConsumerStatefulWidget {
  final CompanyProfile profile;

  const _ProfileView({required this.profile});

  @override
  ConsumerState<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<_ProfileView> {
  static const _tabs = ['Projects', 'Posts', 'Reels'];
  static const MethodChannel _nativeShareChannel = MethodChannel('cineconnect/native_share');

  final _picker = ImagePicker();
  bool _uploading = false;
  bool _bioExpanded = false;
  int _tab = 0;

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------- logo upload ----------

  String _contentTypeFor(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.startsWith('image/')) return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _chooseLogoAction([CompanyProfile? profile]) async {
    final currentProfile = profile ?? ref.read(companyProfileProvider).valueOrNull ?? widget.profile;
    final hasLogo = currentProfile.logoUrl != null && currentProfile.logoUrl!.trim().isNotEmpty;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppColors.border),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.gold),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Remove logo / picture',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () => Navigator.of(sheetContext).pop('remove'),
            ),
          ],
        ),
      ),
    );
    if (action == 'gallery') {
      await _pickAndUpload();
    } else if (action == 'remove') {
      if (!hasLogo) {
        if (mounted) _say('No logo to remove');
      } else {
        await _removeLogo();
      }
    }
  }

  Future<void> _pickAndUpload() async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) _say('Could not open your photos');
      return;
    }
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) _say('That image is too large (5 MB maximum)');
        return;
      }
      await ref.read(companyProfileProvider.notifier).uploadLogo(
            bytes: bytes,
            filename: file.name,
            contentType: _contentTypeFor(file),
          );
      if (mounted) _say('Logo updated');
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException
            ? e.message
            : (e.toString().contains('SocketException')
                ? 'Could not connect to storage server'
                : 'Could not upload the logo: $e');
        _say(msg);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeLogo() async {
    setState(() => _uploading = true);
    try {
      await ref.read(companyProfileProvider.notifier).removeLogo();
      ref.invalidate(companyProfileProvider);
      if (mounted) _say('Logo removed');
    } catch (e) {
      if (mounted) {
        final msg = e is ApiException ? e.message : 'Could not remove the logo';
        _say(msg);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ---------- actions ----------

  Future<void> _share(CompanyProfile p) async {
    final link = 'https://cineconnect.app/studio/${p.username ?? p.id}';
    final shareText = 'Check out ${p.companyName} on CineConnect:\n$link';
    try {
      await _nativeShareChannel.invokeMethod('shareText', {
        'text': shareText,
        'title': 'Share Studio Profile',
      });
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) _say('Profile link copied to clipboard');
    }
  }

  Future<void> _openCreatePostDialog(BuildContext context, CompanyProfile p) async {
    final textController = TextEditingController();
    XFile? attachedImage;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.movie_creation_outlined, color: AppColors.gold, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.companyName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Text(
                              'Share an update, casting call, or announcement',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "What's happening at ${p.companyName}? Write your post here...",
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (attachedImage != null)
                    Stack(
                      children: [
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                            image: DecorationImage(
                              image: FileImage(File(attachedImage!.path)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setSheetState(() => attachedImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final img = await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (img != null) {
                                  setSheetState(() => attachedImage = img);
                                }
                              },
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                        label: Text(attachedImage == null ? 'Add Photo' : 'Change Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gold,
                          side: const BorderSide(color: AppColors.gold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final text = textController.text.trim();
                                if (text.isEmpty && attachedImage == null) {
                                  _say('Please write some text or attach a photo');
                                  return;
                                }
                                setSheetState(() => isSubmitting = true);
                                try {
                                  String? uploadedUrl;
                                  if (attachedImage != null) {
                                    final bytes = await attachedImage!.readAsBytes();
                                    uploadedUrl = await ref.read(mediaRepositoryProvider).uploadImage(
                                          bytes: bytes,
                                          filename: attachedImage!.name,
                                          contentType: _contentTypeFor(attachedImage!),
                                        );
                                  }
                                  final client = ApiClient();
                                  final finalCaption = text.isNotEmpty
                                      ? text
                                      : (attachedImage != null ? 'Studio update from ${p.companyName}' : '');
                                  await client.post(
                                    ApiEndpoints.postsCollection,
                                    body: {
                                      'caption': finalCaption,
                                      if (uploadedUrl != null) 'media_url': uploadedUrl,
                                      'video_slate_title': p.companyName,
                                      'tags': ['Production', 'StudioUpdate'],
                                    },
                                  );
                                  if (mounted && sheetCtx.mounted) {
                                    Navigator.of(sheetCtx).pop();
                                    _say('Post published to cinema feed!');
                                    ref.invalidate(studioPostsProvider);
                                    setState(() => _tab = 1);
                                  }
                                } catch (e) {
                                  setSheetState(() => isSubmitting = false);
                                  final msg = e is ApiException ? e.message : 'Could not publish post: $e';
                                  _say(msg);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- pieces ----------

  Widget _logoWithBadge(CompanyProfile p) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _uploading ? null : () => _chooseLogoAction(p),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Stack(
              children: [
                CompanyLogo(profile: p, size: 84),
                if (_uploading)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: const ColoredBox(
                        color: Color(0x99000000),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: GestureDetector(
            onTap: _uploading ? null : () => _chooseLogoAction(p),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.black, width: 2),
              ),
              child: const Icon(
                Icons.photo_camera,
                size: 14,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statsCard(CompanyProfile p) {
    final projects = ref.watch(projectsProvider).valueOrNull;
    final openRoles = ref
        .watch(opportunitiesProvider)
        .valueOrNull
        ?.where((o) => o.status == OpportunityStatus.open)
        .length;

    final stats = [
      _Stat(projects == null ? '-' : '${projects.length}', 'Projects'),
      _Stat(openRoles == null ? '-' : '$openRoles', 'Open roles'),
      _Stat(formatCount(p.followersCount), 'Followers'),
      _Stat(formatCount(p.followingCount), 'Following'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 28, color: AppColors.border),
            Expanded(child: stats[i]),
          ],
        ],
      ),
    );
  }

  Widget _bio(String text) {
    final isLong = text.length > 130;
    return GestureDetector(
      onTap: isLong ? () => setState(() => _bioExpanded = !_bioExpanded) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: _bioExpanded ? null : 3,
            overflow: _bioExpanded ? null : TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
          if (isLong)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _bioExpanded ? 'Show less' : 'Show more',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
    const pad = EdgeInsets.symmetric(horizontal: 6);
    return Expanded(
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: pad,
              ),
              child: content,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: pad,
              ),
              child: content,
            ),
    );
  }

  Widget _tabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _tab == i ? AppColors.gold : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _tabs[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _tab == i ? AppColors.gold : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabContent(CompanyProfile p) {
    switch (_tab) {
      case 0:
        return const _ProjectsTab();
      case 1:
        return _PostsTab(
          companyProfile: p,
          onNewPost: () => _openCreatePostDialog(context, p),
        );
      case 2:
      default:
        return const EmptyState(
          message: 'No reels yet',
          icon: Icons.video_collection_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(companyProfileProvider).valueOrNull ?? widget.profile;
    final infoItems = <_InfoItem>[
      _InfoItem(Icons.location_on_outlined, p.location),
      if (p.website != null)
        _InfoItem(
          Icons.language,
          p.website!.replaceFirst(RegExp(r'^https?://'), ''),
        ),
      _InfoItem(Icons.mail_outline, p.shownEmail),
      if (p.companyType != null)
        _InfoItem(Icons.business_outlined, p.companyType!),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _logoWithBadge(p),
              const SizedBox(width: 14),
              Expanded(child: _statsCard(p)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Flexible(
                child: Text(
                  p.companyName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (p.isVerified) ...const [
                SizedBox(width: 8),
                Icon(Icons.verified, color: AppColors.gold, size: 22),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (p.isVerified)
                const StatusPill(label: 'VERIFIED STUDIO', color: AppColors.gold),
              if (p.publicId != null)
                StatusPill(label: 'ID: ${p.publicId}', color: AppColors.gold),
            ],
          ),
          if (p.username != null) ...[
            const SizedBox(height: 10),
            Text(
              '@${p.username}',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (p.tagline != null) ...[
            const SizedBox(height: 10),
            Text(
              p.tagline!,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 8),
          _bio(p.description),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: infoItems,
          ),
          if (!p.isVerified) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold),
              ),
              child: const Text(
                'Your studio is not verified yet. Verified studios earn more trust from talent.',
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _actionButton(
                icon: Icons.edit_outlined,
                label: 'Edit Studio',
                onPressed: () => context.push('/company-profile/edit'),
              ),
              const SizedBox(width: 8),
              _actionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onPressed: () => _share(p),
              ),
              const SizedBox(width: 8),
              _actionButton(
                icon: Icons.add_photo_alternate_outlined,
                label: 'Post',
                filled: true,
                onPressed: () => _openCreatePostDialog(context, p),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _tabBar(),
          const SizedBox(height: 16),
          _tabContent(p),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _PostsTab extends ConsumerWidget {
  final CompanyProfile companyProfile;
  final VoidCallback onNewPost;

  const _PostsTab({required this.companyProfile, required this.onNewPost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(studioPostsProvider(companyProfile.id));

    return postsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Row(
        children: [
          const Expanded(
            child: Text(
              'Could not load posts',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(studioPostsProvider(companyProfile.id)),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return EmptyState(
            message: 'No posts yet',
            icon: Icons.article_outlined,
            actionLabel: 'Create a post',
            onAction: onNewPost,
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final post = posts[i];
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                        child: Text(
                          post.authorAvatar.isNotEmpty ? post.authorAvatar : 'CC',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              post.timestamp,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(label: post.guildBadge, color: AppColors.gold),
                    ],
                  ),
                  if (post.contentText.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      post.contentText,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.thumb_up_alt_outlined, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${post.likes}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(width: 16),
                      const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${post.comments}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const Spacer(),
                      Wrap(
                        spacing: 6,
                        children: post.taggedCrafts.take(2).map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(fontSize: 10, color: AppColors.gold),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProjectsTab extends ConsumerWidget {
  const _ProjectsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectsProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Row(
        children: [
          const Expanded(
            child: Text(
              'Could not load projects',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(projectsProvider),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return EmptyState(
            message: 'No projects yet',
            icon: Icons.movie_creation_outlined,
            actionLabel: 'Create a project',
            onAction: () => context.push('/projects/new'),
          );
        }
        return Column(
          children: [
            for (final p in projects) ...[
              AppCard(
                onTap: () => context.push('/projects/${p.id}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Starts ${formatDate(p.startDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(label: p.status.label, color: AppColors.gold),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}