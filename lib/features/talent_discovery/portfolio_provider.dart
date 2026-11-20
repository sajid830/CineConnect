import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/portfolio_item.dart';
import '../../data/repositories/portfolio_repository.dart';

final portfolioProvider =
    FutureProvider.family<List<PortfolioItem>, String>((ref, userId) {
  return ref.read(portfolioRepositoryProvider).getPortfolio(userId);
});