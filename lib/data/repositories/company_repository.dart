import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    id: 'ph1',
    companyName: 'Sunrise Films',
    username: 'sunrise_films',
    publicId: 'PH-882941',
    tagline: 'Independent thrillers and dramas from Chennai',
    description:
        'Independent production house making thrillers and dramas across South India. We cast and crew every project through open calls and champion new voices behind and in front of the camera.',
    location: 'Chennai, India',
    website: 'https://sunrisefilms.com',
    contactEmail: 'casting@sunrisefilms.com',
    companyType: 'Studio Signatory',
    specialization: 'Thriller, Drama, Romance',
    email: 'hello@sunrisefilms.com',
    isVerified: true,
    followersCount: 1400,
    followingCount: 380,
  );

  @override
  Future<CompanyProfile> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 600));
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

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return MockCompanyRepository();
});