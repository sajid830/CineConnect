import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/application.dart';
import 'talent_repository.dart';

abstract class ApplicationRepository {
  Future<List<JobApplication>> getApplications();

  Future<void> updateStatus(String id, ApplicationStatus status);
}

class _Record {
  final String id;
  final String talentId;
  final String opportunityId;
  ApplicationStatus status;
  final String coverLetter;
  final DateTime appliedAt;

  _Record({
    required this.id,
    required this.talentId,
    required this.opportunityId,
    required this.status,
    required this.coverLetter,
    required this.appliedAt,
  });
}

class MockApplicationRepository implements ApplicationRepository {
  final TalentRepository _talentRepository;

  MockApplicationRepository(this._talentRepository);

  final List<_Record> _records = [
    _Record(
      id: 'a1',
      talentId: 't1',
      opportunityId: 'o1',
      status: ApplicationStatus.received,
      coverLetter:
          'I have six years of experience in thrillers and trained in stunt work. I would love to audition for this role.',
      appliedAt: DateTime(2026, 11, 14),
    ),
    _Record(
      id: 'a2',
      talentId: 't2',
      opportunityId: 'o1',
      status: ApplicationStatus.underReview,
      coverLetter:
          'I work in Malayalam and Tamil cinema and am comfortable with Hindi and English dialogue.',
      appliedAt: DateTime(2026, 11, 12),
    ),
    _Record(
      id: 'a3',
      talentId: 't8',
      opportunityId: 'o1',
      status: ApplicationStatus.shortlisted,
      coverLetter:
          'Actor and voice artist with dubbing experience in four languages. Available from December.',
      appliedAt: DateTime(2026, 11, 10),
    ),
    _Record(
      id: 'a4',
      talentId: 't3',
      opportunityId: 'o2',
      status: ApplicationStatus.received,
      coverLetter:
          'Nine years as a director of photography. My showreel covers features and ad films.',
      appliedAt: DateTime(2026, 11, 15),
    ),
    _Record(
      id: 'a5',
      talentId: 't5',
      opportunityId: 'o2',
      status: ApplicationStatus.rejected,
      coverLetter:
          'I am mainly an editor, but I have shot a few short films and would like to move into camera work.',
      appliedAt: DateTime(2026, 11, 9),
    ),
  ];

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
}

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return MockApplicationRepository(ref.watch(talentRepositoryProvider));
});