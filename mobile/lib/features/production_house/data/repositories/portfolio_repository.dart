import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/portfolio_item.dart';

abstract class PortfolioRepository {
  Future<List<PortfolioItem>> getPortfolio(String userId);
  Future<String?> getDownloadUrl(String mediaId);
}

class RemotePortfolioRepository implements PortfolioRepository {
  final ApiClient _client;

  RemotePortfolioRepository({ApiClient? client})
      : _client = client ?? ApiClient();

  @override
  Future<List<PortfolioItem>> getPortfolio(String userId) async {
    final res = await _client.get(ApiEndpoints.userPortfolio(userId));
    if (res is List) {
      return res
          .whereType<Map<String, dynamic>>()
          .map(PortfolioItem.fromJson)
          .toList();
    }
    return [];
  }

  @override
  Future<String?> getDownloadUrl(String mediaId) async {
    try {
      final res = await _client.get(ApiEndpoints.portfolioDownloadUrl(mediaId));
      if (res is Map<String, dynamic> && res['playback_url'] != null) {
        return res['playback_url'].toString();
      }
    } catch (_) {}
    return null;
  }
}

class MockPortfolioRepository implements PortfolioRepository {
  static const _byUser = <String, List<PortfolioItem>>{
        'ph1': [
      PortfolioItem(
        id: 'ph1a',
        title: 'Midnight Express',
        type: PortfolioType.film,
        year: 2026,
        genre: 'Thriller',
        highlight: 'Official Selection: Mumbai Film Festival',
        description: 'A thriller shot across three cities.',
      ),
      PortfolioItem(
        id: 'ph1b',
        title: 'The Last Reel',
        type: PortfolioType.film,
        year: 2025,
        genre: 'Short Drama',
        highlight: 'Winner: Best Short Film, Chennai Indie Awards',
        description: 'A short film about an old projectionist.',
      ),
      PortfolioItem(
        id: 'ph1c',
        title: 'Monsoon Diaries',
        type: PortfolioType.film,
        year: 2024,
        genre: 'Romance',
        highlight: 'Nominated: Best Cinematography',
        description: 'A romantic drama set in the Western Ghats.',
      ),
      PortfolioItem(
        id: 'ph1d',
        title: 'Salt Roads',
        type: PortfolioType.film,
        year: 2023,
        genre: 'Road Drama',
        description: 'Two strangers, one coastal highway.',
      ),
    ],
    't1': [
      PortfolioItem(
        id: 'pf1',
        title: 'Night Chase',
        type: PortfolioType.film,
        year: 2025,
        role: 'Lead',
        description:
            'A feature thriller shot over 40 nights. Performed all stunts in the rooftop sequence.',
      ),
      PortfolioItem(
        id: 'pf2',
        title: 'Acting showreel 2026',
        type: PortfolioType.showreel,
        year: 2026,
        description: 'Three minutes of dramatic and action scenes.',
        mediaUrl: 'https://example.com/showreel',
      ),
    ],
    't3': [
      PortfolioItem(
        id: 'pf3',
        title: 'Monsoon Light',
        type: PortfolioType.film,
        year: 2024,
        role: 'Director of photography',
        description:
            'A romantic drama shot entirely on location in the Western Ghats with natural light.',
      ),
      PortfolioItem(
        id: 'pf4',
        title: 'Colour grading reel',
        type: PortfolioType.showreel,
        year: 2025,
        role: 'Colourist',
        description: 'Before and after grades from four feature films.',
      ),
      PortfolioItem(
        id: 'pf5',
        title: 'Location stills',
        type: PortfolioType.photo,
        year: 2023,
        description: 'Reference photography from recce trips across South India.',
      ),
    ],
  };

  @override
  Future<List<PortfolioItem>> getPortfolio(String userId) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _byUser[userId] ?? const [];
  }

  @override
  Future<String?> getDownloadUrl(String mediaId) async => null;
}

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return RemotePortfolioRepository();
});