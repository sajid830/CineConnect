import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/application.dart';
import 'talent_repository.dart';

abstract class ApplicationRepository {
  Future<List<JobApplication>> getApplications();

  Future<void> updateStatus(String id, ApplicationStatus status);

  Future<String> getResumeDownloadUrl(String applicationId);

  Future<String> getReelDownloadUrl(String applicationId);
}

class _Record {
  final String id;
  final String talentId;
  final String opportunityId;
  ApplicationStatus status;
  final String coverLetter;
  final DateTime appliedAt;
  final String? resumeUrl;
  final String? reelUrl;

  _Record({
    required this.id,
    required this.talentId,
    required this.opportunityId,
    required this.status,
    required this.coverLetter,
    required this.appliedAt,
  })  : resumeUrl = null,
        reelUrl = null;
}

class MockApplicationRepository implements ApplicationRepository {
  final TalentRepository _talentRepository;

  MockApplicationRepository(this._talentRepository);

  final List<_Record> _records = [];

  @override
  Future<List<JobApplication>> getApplications() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final result = await Future.wait(
      _records.map((r) async {
        final talent = await _talentRepository.getTalent(r.talentId);
        return JobApplication(
          id: r.id,
          opportunityId: r.opportunityId,
          status: r.status,
          coverLetter: r.coverLetter,
          appliedAt: r.appliedAt,
          talent: talent,
          resumeUrl: r.resumeUrl,
          reelUrl: r.reelUrl,
        );
      }),
    );
    result.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return result;
  }

  @override
  Future<void> updateStatus(String id, ApplicationStatus status) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final record = _records.firstWhere((r) => r.id == id);
    record.status = status;
  }

  @override
  Future<String> getResumeDownloadUrl(String applicationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final record = _records.where((r) => r.id == applicationId).firstOrNull;
    if (record?.resumeUrl == null) {
      throw ApiException(statusCode: 404, message: 'Application does not have a resume attached.');
    }
    return record!.resumeUrl!;
  }

  @override
  Future<String> getReelDownloadUrl(String applicationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final record = _records.where((r) => r.id == applicationId).firstOrNull;
    if (record?.reelUrl == null) {
      throw ApiException(statusCode: 404, message: 'Application does not have an audition reel attached.');
    }
    return record!.reelUrl!;
  }
}

class RemoteApplicationRepository implements ApplicationRepository {
  final ApiClient _client;

  RemoteApplicationRepository({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<List<JobApplication>> getApplications() async {
    try {
      final res = await _client.get(ApiEndpoints.applicationsCollection);
      if (res is List) {
        return res.map((item) {
          if (item is Map) {
            return JobApplication.fromJson(Map<String, dynamic>.from(item));
          }
          throw const FormatException('Expected application item to be a map');
        }).toList();
      }
      return [];
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return [];
      }
      rethrow;
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Failed to load applications: $e');
    }
  }

  @override
  Future<void> updateStatus(String id, ApplicationStatus status) async {
    final body = {'status': status.apiValue};
    await _client.patch(ApiEndpoints.applicationStatus(id), body: body);
  }

  /// Helper to fetch applications specifically for a given opportunity
  Future<List<JobApplication>> getApplicationsForOpportunity(String opportunityId) async {
    try {
      final res = await _client.get(
        ApiEndpoints.applicationsCollection,
        queryParams: {'opportunity_id': opportunityId},
      );
      if (res is List) {
        return res.map((item) {
          if (item is Map) {
            return JobApplication.fromJson(Map<String, dynamic>.from(item));
          }
          throw const FormatException('Expected application item to be a map');
        }).toList();
      }
      return [];
    } on ApiException catch (e) {
      if (e.statusCode == 404) return [];
      rethrow;
    } catch (e) {
      throw ApiException(statusCode: 0, message: 'Failed to load opportunity applications: $e');
    }
  }

  /// Helper to fetch a single application by ID
  Future<JobApplication?> getApplicationById(String id) async {
    try {
      final res = await _client.get(ApiEndpoints.applicationDetails(id));
      if (res is Map) {
        return JobApplication.fromJson(Map<String, dynamic>.from(res));
      }
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<String> getResumeDownloadUrl(String applicationId) async {
    try {
      final res = await _client.get(ApiEndpoints.applicationResumeDownloadUrl(applicationId));
      if (res is Map && res['download_url'] != null) {
        return res['download_url'].toString();
      }
      throw ApiException(
        statusCode: 500,
        message: 'Invalid response from resume download endpoint',
        details: res,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'Failed to retrieve resume download URL: $e');
    }
  }

  @override
  Future<String> getReelDownloadUrl(String applicationId) async {
    try {
      final res = await _client.get(ApiEndpoints.applicationReelDownloadUrl(applicationId));
      if (res is Map && res['download_url'] != null) {
        return res['download_url'].toString();
      }
      throw ApiException(
        statusCode: 500,
        message: 'Invalid response from reel download endpoint',
        details: res,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'Failed to retrieve reel download URL: $e');
    }
  }
}

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return RemoteApplicationRepository();
});