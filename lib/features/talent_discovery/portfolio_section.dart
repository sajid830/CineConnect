import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/portfolio_item.dart';
import '../../shared/widgets/app_card.dart';
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

class _PortfolioCard extends StatelessWidget {
  final PortfolioItem item;

  const _PortfolioCard({required this.item});

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 16),
              Text(item.description),
              if (item.mediaUrl != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Link',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  item.mediaUrl!,
                  style: const TextStyle(color: AppColors.goldLight),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(PortfolioItem item) {
    final parts = [item.type.label, '${item.year}', ?item.role];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _showDetails(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: item.thumbnailUrl == null
                  ? _IconTile(type: item.type)
                  : Image.network(
                      item.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _IconTile(type: item.type),
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