import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/features/production_house/data/models/talent.dart';
import 'package:cineconnect/features/production_house/data/repositories/talent_repository.dart';

class TalentFilter {
  final String query;
  final String? role;
  final Set<String> skills;

  const TalentFilter({this.query = '', this.role, this.skills = const {}});

  bool get hasFilters => role != null || skills.isNotEmpty;

  TalentFilter copyWith({
    String? query,
    String? role,
    bool clearRole = false,
    Set<String>? skills,
  }) {
    return TalentFilter(
      query: query ?? this.query,
      role: clearRole ? null : (role ?? this.role),
      skills: skills ?? this.skills,
    );
  }
}

class TalentFilterNotifier extends Notifier<TalentFilter> {
  @override
  TalentFilter build() => const TalentFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setRole(String? role) =>
      state = state.copyWith(role: role, clearRole: role == null);

  void setSkills(Set<String> skills) =>
      state = state.copyWith(skills: skills);

  void clearFilters() =>
      state = TalentFilter(query: state.query);
}

final talentFilterProvider =
    NotifierProvider<TalentFilterNotifier, TalentFilter>(
  TalentFilterNotifier.new,
);

final talentResultsProvider = FutureProvider<List<Talent>>((ref) {
  final filter = ref.watch(talentFilterProvider);
  return ref.read(talentRepositoryProvider).searchTalent(
        query: filter.query,
        role: filter.role,
        skills: filter.skills,
      );
});

final talentDetailProvider =
    FutureProvider.family<Talent, String>((ref, id) {
  return ref.read(talentRepositoryProvider).getTalent(id);
});