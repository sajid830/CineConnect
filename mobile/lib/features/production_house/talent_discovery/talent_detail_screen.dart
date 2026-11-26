import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/core/models/craft_models.dart';
import 'package:cineconnect/core/network/api_client.dart';
import 'package:cineconnect/core/network/api_endpoints.dart';
import 'package:cineconnect/features/production_house/applications/audition_video_player_dialog.dart';
import 'package:cineconnect/features/production_house/data/models/talent.dart';
import 'package:cineconnect/shared/widgets/app_card.dart';
import 'package:cineconnect/shared/widgets/async_body.dart';
import 'package:cineconnect/shared/widgets/empty_state.dart';
import 'package:cineconnect/shared/widgets/initials_avatar.dart';
import 'package:cineconnect/features/production_house/collaboration/invite_button.dart';
import 'portfolio_section.dart';
import 'talent_provider.dart';

/// Provider for a specific talent's posts
final talentPostsProvider = FutureProvider.autoDispose.family<List<CineFeedPost>, String>((ref, talentId) async {
  final client = ApiClient();
  try {
    final res = await client.get(ApiEndpoints.userPosts(talentId));
    if (res is List) {
      return res.map((e) => CineFeedPost.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (_) {}
  return [];
});

/// Provider for a specific talent's video reels
final talentReelsProvider = FutureProvider.autoDispose.family<List<CineReelItem>, String>((ref, talentId) async {
  final client = ApiClient();
  try {
    final res = await client.get(ApiEndpoints.reelsCollection, queryParams: {'user_id': talentId});
    if (res is List) {
      return res.map((e) => CineReelItem.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (_) {}
  return [];
});

class TalentDetailScreen extends ConsumerWidget {
  final String talentId;

  const TalentDetailScreen({super.key, required this.talentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final talentAsync = ref.watch(talentDetailProvider(talentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Talent profile')),
      body: AsyncBody<Talent>(
        value: talentAsync,
        errorMessage: 'Could not load this profile',
        onRetry: () => ref.invalidate(talentDetailProvider(talentId)),
        data: (t) => _ProfileView(talent: t),
      ),
    );
  }
}

class _ProfileView extends StatefulWidget {
  final Talent talent;

  const _ProfileView({required this.talent});

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  static const _tabs = ['Portfolio', 'Posts', 'Reels'];
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final t = widget.talent;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: InitialsAvatar(initials: t.initials, radius: 46)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    t.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (t.isVerified) ...const [
                  SizedBox(width: 8),
                  Icon(Icons.verified, color: AppColors.gold),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t.role,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: AppColors.gold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  t.location,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(width: 20),
                const Icon(
                  Icons.work_outline,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  '${t.experienceYears} yrs experience',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (t.bio.isNotEmpty) ...[
              const Text(
                'About',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(t.bio),
              const SizedBox(height: 20),
            ],
            if (t.skills.isNotEmpty) ...[
              const Text(
                'Skills',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final s in t.skills) Chip(label: Text(s))],
              ),
              const SizedBox(height: 24),
            ],

            // Tabs: Portfolio, Posts, Reels
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _activeTab = i),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _activeTab == i ? AppColors.gold : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            _tabs[i],
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _activeTab == i ? AppColors.gold : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Content
            if (_activeTab == 0)
              PortfolioSection(talentId: t.id)
            else if (_activeTab == 1)
              _TalentPostsSection(talentId: t.id)
            else
              _TalentReelsSection(talentId: t.id, talentName: t.fullName),

            const SizedBox(height: 28),
            InviteButton(talent: t),
          ],
        ),
      ),
    );
  }
}

class _TalentPostsSection extends ConsumerWidget {
  final String talentId;

  const _TalentPostsSection({required this.talentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(talentPostsProvider(talentId));

    return postsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Row(
        children: [
          const Expanded(
            child: Text(
              'Could not load posts',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(talentPostsProvider(talentId)),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const EmptyState(
            message: 'No posts published yet',
            icon: Icons.article_outlined,
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
                        radius: 16,
                        backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                        child: Text(
                          post.authorAvatar.isNotEmpty ? post.authorAvatar : 'T',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              post.timestamp,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (post.contentText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(post.contentText, style: const TextStyle(fontSize: 13, height: 1.4)),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.thumb_up_alt_outlined, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${post.likes}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(width: 14),
                      const Icon(Icons.chat_bubble_outline, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${post.comments}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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

class _TalentReelsSection extends ConsumerWidget {
  final String talentId;
  final String talentName;

  const _TalentReelsSection({required this.talentId, required this.talentName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsAsync = ref.watch(talentReelsProvider(talentId));

    return reelsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Row(
        children: [
          const Expanded(
            child: Text(
              'Could not load reels',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => ref.invalidate(talentReelsProvider(talentId)),
            child: const Text('Try again'),
          ),
        ],
      ),
      data: (reels) {
        if (reels.isEmpty) {
          return const EmptyState(
            message: 'No video reels published yet',
            icon: Icons.video_collection_outlined,
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reels.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 160,
          ),
          itemBuilder: (context, i) {
            final reel = reels[i];
            return AppCard(
              padding: const EdgeInsets.all(8),
              onTap: () {
                final url = reel.playbackUrl ?? reel.mediaUrl;
                if (url != null && url.isNotEmpty) {
                  showDialog<void>(
                    context: context,
                    builder: (_) => AuditionVideoPlayerDialog(
                      downloadUrl: url,
                      candidateName: talentName,
                      projectTitle: reel.title,
                    ),
                  );
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.gold,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    reel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reel.craftSpecialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
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
