import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/talent.dart';
import 'talent_provider.dart';

class TalentPage extends ConsumerStatefulWidget {
  const TalentPage({super.key});

  @override
  ConsumerState<TalentPage> createState() => _TalentPageState();
}

class _TalentPageState extends ConsumerState<TalentPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(talentFilterProvider.notifier).setQuery(value.trim());
    });
  }

  Future<void> _openSkillsSheet() async {
    final current = ref.read(talentFilterProvider).skills;
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SkillsSheet(initial: current),
    );
    if (selected != null && mounted) {
      ref.read(talentFilterProvider.notifier).setSkills(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(talentFilterProvider);
    final resultsAsync = ref.watch(talentResultsProvider);
    final notifier = ref.read(talentFilterProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search by name or role',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _roleChip('All', filter.role == null, () => notifier.setRole(null)),
              for (final r in talentRoles)
                _roleChip(r, filter.role == r, () => notifier.setRole(r)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: _openSkillsSheet,
                icon: const Icon(Icons.tune, size: 18),
                label: Text(
                  filter.skills.isEmpty
                      ? 'Skills'
                      : 'Skills (${filter.skills.length})',
                ),
              ),
              const Spacer(),
              if (filter.hasFilters)
                TextButton(
                  onPressed: notifier.clearFilters,
                  child: const Text('Clear filters'),
                ),
            ],
          ),
        ),
        Expanded(
          child: resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load talent'),
                  TextButton(
                    onPressed: () => ref.invalidate(talentResultsProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
            data: (people) {
              if (people.isEmpty) {
                return const Center(
                  child: Text(
                    'No talent matches your search',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: people.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _TalentCard(talent: people[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _roleChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.gold,
        labelStyle: TextStyle(
          color: selected ? AppColors.black : AppColors.textPrimary,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _TalentCard extends StatelessWidget {
  final Talent talent;

  const _TalentCard({required this.talent});

  @override
  Widget build(BuildContext context) {
    final t = talent;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/talent-profile/${t.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.gold,
              child: Text(
                t.initials,
                style: const TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          t.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (t.isVerified) ...const [
                        SizedBox(width: 6),
                        Icon(Icons.verified, size: 16, color: AppColors.gold),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${t.role} · ${t.location}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  if (t.skills.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      t.skills.take(3).join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SkillsSheet extends StatefulWidget {
  final Set<String> initial;

  const _SkillsSheet({required this.initial});

  @override
  State<_SkillsSheet> createState() => _SkillsSheetState();
}

class _SkillsSheetState extends State<_SkillsSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by skills',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in talentSkills)
                  FilterChip(
                    label: Text(s),
                    selected: _selected.contains(s),
                    selectedColor: AppColors.gold,
                    checkmarkColor: AppColors.black,
                    labelStyle: TextStyle(
                      color: _selected.contains(s)
                          ? AppColors.black
                          : AppColors.textPrimary,
                    ),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selected.add(s);
                        } else {
                          _selected.remove(s);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}