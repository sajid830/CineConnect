import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/talent.dart';

abstract class TalentRepository {
  Future<List<Talent>> searchTalent({
    String query = '',
    String? role,
    Set<String> skills = const {},
  });

  Future<Talent> getTalent(String id);
}

class MockTalentRepository implements TalentRepository {
  static const _all = [
    Talent(
      id: 't1',
      fullName: 'Aarav Mehta',
      role: 'Actor',
      location: 'Mumbai',
      bio: 'Lead actor with six years in thrillers and action films. Trained in stunt work.',
      experienceYears: 6,
      isVerified: true,
      skills: ['Action', 'Dance'],
    ),
    Talent(
      id: 't2',
      fullName: 'Priya Nair',
      role: 'Actor',
      location: 'Kochi',
      bio: 'Stage and screen actor working in Malayalam and Tamil cinema.',
      experienceYears: 4,
      isVerified: true,
      skills: ['Dance', 'Dubbing'],
    ),
    Talent(
      id: 't3',
      fullName: 'Rohan Iyer',
      role: 'Cinematographer',
      location: 'Chennai',
      bio: 'Director of photography for feature films and ad campaigns.',
      experienceYears: 9,
      isVerified: true,
      skills: ['Colour grading', 'Drone shooting'],
    ),
    Talent(
      id: 't4',
      fullName: 'Meera Kapoor',
      role: 'Director',
      location: 'Mumbai',
      bio: 'Independent filmmaker with two festival-selected short films.',
      experienceYears: 7,
      isVerified: false,
      skills: ['Screenwriting', 'Editing'],
    ),
    Talent(
      id: 't5',
      fullName: 'Karthik Raja',
      role: 'Editor',
      location: 'Hyderabad',
      bio: 'Picture editor and colourist. Fast turnaround, remote friendly.',
      experienceYears: 5,
      isVerified: true,
      skills: ['Editing', 'Colour grading'],
    ),
    Talent(
      id: 't6',
      fullName: 'Sana Sheikh',
      role: 'Makeup Artist',
      location: 'Mumbai',
      bio: 'Prosthetics and period makeup for film and web series.',
      experienceYears: 8,
      isVerified: true,
      skills: [],
    ),
    Talent(
      id: 't7',
      fullName: 'Vikram Rao',
      role: 'Music Composer',
      location: 'Bengaluru',
      bio: 'Composer and sound designer for feature films.',
      experienceYears: 10,
      isVerified: false,
      skills: ['Sound design'],
    ),
    Talent(
      id: 't8',
      fullName: 'Ananya Das',
      role: 'Actor',
      location: 'Kolkata',
      bio: 'Actor and voice artist. Dubbing experience in four languages.',
      experienceYears: 3,
      isVerified: true,
      skills: ['Dubbing', 'Dance'],
    ),
  ];

  @override
  Future<List<Talent>> searchTalent({
    String query = '',
    String? role,
    Set<String> skills = const {},
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final q = query.toLowerCase();
    return _all.where((t) {
      final matchesQuery = q.isEmpty ||
          t.fullName.toLowerCase().contains(q) ||
          t.role.toLowerCase().contains(q);
      final matchesRole = role == null || t.role == role;
      final matchesSkills = skills.every(t.skills.contains);
      return matchesQuery && matchesRole && matchesSkills;
    }).toList();
  }

  @override
  Future<Talent> getTalent(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _all.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Talent not found'),
    );
  }
}

final talentRepositoryProvider = Provider<TalentRepository>((ref) {
  return MockTalentRepository();
});