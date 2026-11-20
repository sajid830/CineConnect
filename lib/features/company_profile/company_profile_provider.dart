import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/company_profile.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/media_repository.dart';

class CompanyProfileNotifier extends AsyncNotifier<CompanyProfile> {
  @override
  Future<CompanyProfile> build() {
    return ref.read(companyRepositoryProvider).getProfile();
  }

  Future<void> save({
    required String companyName,
    required String description,
    required String location,
    required String specialization,
    String? tagline,
    String? website,
    String? contactEmail,
    String? companyType,
  }) async {
    final updated = await ref.read(companyRepositoryProvider).updateProfile(
          companyName: companyName,
          description: description,
          location: location,
          specialization: specialization,
          tagline: tagline,
          website: website,
          contactEmail: contactEmail,
          companyType: companyType,
        );
    state = AsyncData(updated);
  }

  /// Uploads the picture, then saves its URL on the profile.
  Future<void> uploadLogo({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final url = await ref.read(mediaRepositoryProvider).uploadImage(
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        );
    final updated = await ref.read(companyRepositoryProvider).setLogo(url);
    state = AsyncData(updated);
  }

  Future<void> removeLogo() async {
    final updated = await ref.read(companyRepositoryProvider).setLogo(null);
    state = AsyncData(updated);
  }
}

final companyProfileProvider =
    AsyncNotifierProvider<CompanyProfileNotifier, CompanyProfile>(
  CompanyProfileNotifier.new,
);