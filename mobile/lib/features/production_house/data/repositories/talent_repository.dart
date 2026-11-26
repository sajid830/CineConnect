import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/talent.dart';

abstract class TalentRepository {
  Future<List<Talent>> searchTalent({
    String query = '',
    String? role,
    Set<String> skills = const {},
  });

  Future<Talent> getTalent(String id);
}

class RemoteTalentRepository implements TalentRepository {
  final ApiClient _client;

  RemoteTalentRepository({ApiClient? client})
      : _client = client ?? ApiClient();

  @override
  Future<List<Talent>> searchTalent({
    String query = '',
    String? role,
    Set<String> skills = const {},
  }) async {
    final queryParams = <String, dynamic>{
      'account_type': 'talent',
      'limit': 50,
    };
    if (query.trim().isNotEmpty) {
      queryParams['q'] = query.trim();
    }
    if (role != null && role.isNotEmpty && role != 'All') {
      queryParams['role'] = role;
    }

    final res = await _client.get(ApiEndpoints.searchUsers, queryParams: queryParams);

    List<dynamic> items = [];
    if (res is Map<String, dynamic> && res['items'] is List) {
      items = res['items'] as List;
    } else if (res is List) {
      items = res;
    }

    final talents = items
        .whereType<Map<String, dynamic>>()
        .map(Talent.fromJson)
        .where((t) {
          if (skills.isEmpty) return true;
          return skills.every((s) => t.skills.contains(s));
        })
        .toList();

    return talents;
  }

  @override
  Future<Talent> getTalent(String id) async {
    final res = await _client.get(ApiEndpoints.userPublicProfile(id));
    if (res is Map<String, dynamic>) {
      return Talent.fromJson(res);
    }
    throw Exception('Talent not found');
  }
}

class MockTalentRepository implements TalentRepository {
  @override
  Future<List<Talent>> searchTalent({
    String query = '',
    String? role,
    Set<String> skills = const {},
  }) async {
    return [];
  }

  @override
  Future<Talent> getTalent(String id) async {
    throw Exception('Talent not found');
  }
}

final talentRepositoryProvider = Provider<TalentRepository>((ref) {
  return RemoteTalentRepository();
});