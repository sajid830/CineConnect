import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/portfolio_item.dart';
import 'package:cineconnect/features/production_house/data/repositories/portfolio_repository.dart';
import 'package:cineconnect/features/production_house/applications/audition_video_player_dialog.dart';
import 'package:cineconnect/shared/widgets/app_card.dart';
import 'portfolio_provider.dart';

IconData _iconFor(PortfolioType type) {
  switch (type) {
    case PortfolioType.film:
      return Icons.movie_outlined;
    case PortfolioType.showreel:
      return Icons.play_circle_outline;
    case PortfolioType.photo:
      return Icons.photo_library_outlined;
    case PortfolioType.audio:
      return Icons.graphic_eq;
    case PortfolioType.other:
      return Icons.folder_open_outlined;
  }
}

class PortfolioSection extends ConsumerWidget {
  final String talentId;

  const PortfolioSection({super.key, required this.talentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(portfolioProvider(talentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Portfolio',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Row(
            children: [
              const Expanded(
                child: Text(
                  'Could not load portfolio',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(portfolioProvider(talentId)),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Text(
                'No portfolio items yet',
                style: TextStyle(color: AppColors.textMuted),
              );
            }
            return Column(
              children: [
                for (final item in items) ...[
                  _PortfolioCard(item: item),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PortfolioCard extends ConsumerWidget {
  final PortfolioItem item;

  const _PortfolioCard({required this.item});

  void _showDetails(BuildContext context, WidgetRef ref) {
    final activeMediaUrl = item.playbackUrl ?? item.mediaUrl;
    final isVideo = item.type == PortfolioType.showreel || item.type == PortfolioType.film;
    final isPhoto = item.type == PortfolioType.photo;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
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
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle(item),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (item.description.isNotEmpty) ...[
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
              ],
              if (isPhoto && activeMediaUrl != null && activeMediaUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 280),
                    width: double.infinity,
                    color: AppColors.surface,
                    child: Image.network(
                      activeMediaUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (ctx, error, stackTrace) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Unable to load photo preview',
                            style: TextStyle(color: AppColors.textMuted),
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
                      Navigator.of(context).pop();
                      _openVideoPlayer(context, ref, activeMediaUrl);
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
                    label: const Text('Play Showreel / Video'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
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
              if (item.mediaUrl != null && item.mediaUrl!.isNotEmpty) ...[
                const Text(
                  'Asset Link',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  item.mediaUrl!,
                  style: const TextStyle(color: AppColors.goldLight, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openVideoPlayer(BuildContext context, WidgetRef ref, String initialUrl) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AuditionVideoPlayerDialog(
        downloadUrl: initialUrl,
        candidateName: item.title,
        projectTitle: item.role ?? 'Portfolio Video',
        onRefreshUrl: () async {
          final repo = ref.read(portfolioRepositoryProvider);
          final fresh = await repo.getDownloadUrl(item.id);
          return fresh ?? initialUrl;
        },
      ),
    );
  }

  static String _subtitle(PortfolioItem item) {
    final parts = [
      item.type.label,
      '${item.year}',
      if (item.role != null && item.role!.isNotEmpty) item.role!,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoOrThumbUrl = item.thumbnailUrl ?? ((item.type == PortfolioType.photo) ? (item.playbackUrl ?? item.mediaUrl) : null);

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _showDetails(context, ref),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: photoOrThumbUrl == null
                  ? _IconTile(type: item.type)
                  : Image.network(
                      photoOrThumbUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _IconTile(type: item.type),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final PortfolioType type;

  const _IconTile({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.black,
      child: Icon(_iconFor(type), color: AppColors.gold, size: 28),
    );
  }
}