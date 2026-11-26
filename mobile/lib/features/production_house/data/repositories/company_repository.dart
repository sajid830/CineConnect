import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/company_profile.dart';

abstract class CompanyRepository {
  Future<CompanyProfile> getProfile();

  Future<CompanyProfile> updateProfile({
    required String companyName,
    required String description,
    required String location,
    required String specialization,
    String? tagline,
    String? website,
    String? contactEmail,
    String? companyType,
  });

  /// Saves the logo URL on the profile. Pass null to remove the logo.
  Future<CompanyProfile> setLogo(String? logoUrl);
}

class MockCompanyRepository implements CompanyRepository {
  CompanyProfile _profile = const CompanyProfile(
    id: '',
    companyName: '',
    description: '',
    location: '',
    specialization: '',
    email: '',
    isVerified: false,
  );

  @override
  Future<CompanyProfile> getProfile() async {
    return _profile;
  }

  @override
  Future<CompanyProfile> updateProfile({
    required String companyName,
    required String description,
    required String location,
    required String specialization,
    String? tagline,
    String? website,
    String? contactEmail,
    String? companyType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _profile = CompanyProfile(
      id: _profile.id,
      companyName: companyName,
      description: description,
      location: location,
      specialization: specialization,
      email: _profile.email,
      isVerified: _profile.isVerified,
      logoUrl: _profile.logoUrl,
      username: _profile.username,
      publicId: _profile.publicId,
      tagline: tagline,
      website: website,
      contactEmail: contactEmail,
      companyType: companyType,
      followersCount: _profile.followersCount,
      followingCount: _profile.followingCount,
    );
    return _profile;
  }

  @override
  Future<CompanyProfile> setLogo(String? logoUrl) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _profile = CompanyProfile(
      id: _profile.id,
      companyName: _profile.companyName,
      description: _profile.description,
      location: _profile.location,
      specialization: _profile.specialization,
      email: _profile.email,
      isVerified: _profile.isVerified,
      logoUrl: logoUrl,
      username: _profile.username,
      publicId: _profile.publicId,
      tagline: _profile.tagline,
      website: _profile.website,
      contactEmail: _profile.contactEmail,
      companyType: _profile.companyType,
      followersCount: _profile.followersCount,
      followingCount: _profile.followingCount,
    );
    return _profile;
  }
}

class RemoteCompanyRepository implements CompanyRepository {
  final ApiClient _client;
  CompanyProfile? _cachedProfile;

  RemoteCompanyRepository({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<CompanyProfile> getProfile() async {
    try {
      final res = await _client.get(ApiEndpoints.productionHouseMe);
      if (res is Map<String, dynamic>) {
        final profile = CompanyProfile.fromJson(res);
        _cachedProfile = profile;
        return profile;
      }
      throw ApiException(statusCode: 500, message: 'Invalid profile response from server');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // Production house profile has not yet been created for this account.
        // Return an initial profile structure with the authenticated user's email/metadata
        // so the user can seamlessly view or edit their profile to create it.
        final user = Supabase.instance.client.auth.currentUser;
        final email = user?.email ?? '';
        final initialName = (user?.userMetadata?['company_name'] as String?) ??
            (user?.userMetadata?['full_name'] as String?) ??
            '';
        final initialProfile = CompanyProfile(
          id: '',
          companyName: initialName,
          description: '',
          location: '',
          specialization: '',
          email: email,
          isVerified: false,
        );
        _cachedProfile = initialProfile;
        return initialProfile;
      }
      rethrow;
    }
  }

  @override
  Future<CompanyProfile> updateProfile({
    required String companyName,
    required String description,
    required String location,
    required String specialization,
    String? tagline,
    String? website,
    String? contactEmail,
    String? companyType,
  }) async {
    final payload = {
      'company_name': companyName,
      'description': description,
      'location': location,
      'specialization': specialization,
      if (website != null && website.isNotEmpty) 'website': website,
      if (_cachedProfile?.logoUrl != null) 'logo_url': _cachedProfile!.logoUrl,
    };

    dynamic res;
    // If the profile does not exist on the backend yet, use POST to create it.
    // If it exists, use PUT to update it.
    if (_cachedProfile == null || _cachedProfile!.id.isEmpty) {
      try {
        res = await _client.put(ApiEndpoints.productionHouseMe, body: payload);
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          res = await _client.post(ApiEndpoints.productionHousesCollection, body: payload);
        } else {
          rethrow;
        }
      }
    } else {
      res = await _client.put(ApiEndpoints.productionHouseMe, body: payload);
    }

    if (res is Map<String, dynamic>) {
      final updated = CompanyProfile.fromJson(res).copyWith(
        tagline: tagline ?? _cachedProfile?.tagline,
        contactEmail: contactEmail ?? _cachedProfile?.contactEmail,
        companyType: companyType ?? _cachedProfile?.companyType,
      );
      _cachedProfile = updated;
      return updated;
    }
    throw ApiException(statusCode: 500, message: 'Invalid response from server on profile update');
  }

  @override
  Future<CompanyProfile> setLogo(String? logoUrl) async {
    final current = _cachedProfile ?? await getProfile();
    final payload = {
      'company_name': current.companyName,
      'description': current.description,
      'location': current.location,
      'specialization': current.specialization,
      if (current.website != null && current.website!.isNotEmpty) 'website': current.website,
      'logo_url': logoUrl,
    };

    dynamic res;
    if (current.id.isEmpty) {
      res = await _client.post(ApiEndpoints.productionHousesCollection, body: payload);
    } else {
      res = await _client.put(ApiEndpoints.productionHouseMe, body: payload);
    }

    if (res is Map<String, dynamic>) {
      final updated = CompanyProfile.fromJson(res).copyWith(
        tagline: current.tagline,
        contactEmail: current.contactEmail,
        companyType: current.companyType,
      );
      _cachedProfile = updated;
      return updated;
    }
    throw ApiException(statusCode: 500, message: 'Invalid response from server on logo update');
  }
}

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return RemoteCompanyRepository();
});