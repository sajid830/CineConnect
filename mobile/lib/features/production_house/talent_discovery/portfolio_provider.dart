import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cineconnect/features/production_house/data/models/portfolio_item.dart';
import 'package:cineconnect/features/production_house/data/repositories/portfolio_repository.dart';

final portfolioProvider =
    FutureProvider.family<List<PortfolioItem>, String>((ref, userId) {
  return ref.read(portfolioRepositoryProvider).getPortfolio(userId);
});