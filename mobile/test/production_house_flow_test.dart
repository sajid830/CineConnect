import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/app/router/app_router.dart';
import 'package:cineconnect/app/theme.dart';
import 'package:cineconnect/features/production_house/data/models/application.dart';
import 'package:cineconnect/features/production_house/data/models/dashboard_summary.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/features/production_house/data/models/project.dart';
import 'package:cineconnect/features/production_house/data/models/talent.dart';
import 'package:cineconnect/features/production_house/data/repositories/application_repository.dart';
import 'package:cineconnect/features/production_house/data/repositories/dashboard_repository.dart';
import 'package:cineconnect/features/production_house/data/repositories/opportunity_repository.dart';
import 'package:cineconnect/features/production_house/data/repositories/project_repository.dart';
import 'package:cineconnect/features/production_house/data/repositories/talent_repository.dart';
import 'package:cineconnect/features/production_house/dashboard/dashboard_screen.dart';
import 'package:cineconnect/features/production_house/home/home_page.dart';
import 'package:cineconnect/features/production_house/home/home_provider.dart';
import 'package:cineconnect/features/production_house/projects/projects_page.dart';
import 'package:cineconnect/features/production_house/projects/projects_provider.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_page.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_provider.dart';
import 'package:cineconnect/features/production_house/applications/applications_page.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'package:cineconnect/features/production_house/talent_discovery/talent_page.dart';
import 'package:cineconnect/features/production_house/talent_discovery/talent_provider.dart';
import 'package:cineconnect/features/production_house/notifications/notification_bell.dart';
import 'package:cineconnect/features/production_house/notifications/notifications_provider.dart';

Widget _buildTestApp(Widget child, [List<Override> overrides = const []]) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: child,
    ),
  );
}

class _SyncProjectsNotifier extends ProjectsNotifier {
  final List<Project> _items;
  _SyncProjectsNotifier(this._items);
  @override
  Future<List<Project>> build() async => _items;
}

class _SyncOpportunitiesNotifier extends OpportunitiesNotifier {
  final List<Opportunity> _items;
  _SyncOpportunitiesNotifier(this._items);
  @override
  Future<List<Opportunity>> build() async => _items;
}

class _SyncApplicationsNotifier extends ApplicationsNotifier {
  final List<JobApplication> _items;
  _SyncApplicationsNotifier(this._items);
  @override
  Future<List<JobApplication>> build() async => _items;
}

class UnreadCountNotifierMock extends UnreadCountNotifier {
  final UnreadCountState _initial;
  UnreadCountNotifierMock(this._initial);

  @override
  UnreadCountState build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockTalent = Talent(
    id: 't1',
    fullName: 'Aarav Mehta',
    role: 'Actor',
    location: 'Mumbai',
    bio: 'Lead actor with stunt experience',
    experienceYears: 6,
    isVerified: true,
    skills: const ['Action', 'Dance'],
  );

  final mockProject = Project(
    id: 'p1',
    title: 'Midnight Express',
    description: 'A thriller shot across three cities.',
    status: ProjectStatus.upcoming,
    startDate: DateTime(2026, 9, 1),
  );

  final mockOpportunity = Opportunity(
    id: 'o1',
    projectId: 'p1',
    title: 'Lead Actress — Maya',
    requirements: 'Age 24-30.',
    deadline: DateTime(2026, 12, 1),
    status: OpportunityStatus.open,
  );

  final mockApp = JobApplication(
    id: 'a1',
    opportunityId: 'o1',
    status: ApplicationStatus.received,
    coverLetter: 'Passionate about cinema.',
    appliedAt: DateTime(2026, 11, 14),
    talent: mockTalent,
  );

  final defaultOverrides = <Override>[
    projectsProvider.overrideWith(() => _SyncProjectsNotifier([mockProject])),
    opportunitiesProvider.overrideWith(() => _SyncOpportunitiesNotifier([mockOpportunity])),
    applicationsProvider.overrideWith(() => _SyncApplicationsNotifier([mockApp])),
    talentResultsProvider.overrideWith((ref) => Future.value([mockTalent])),
    unreadCountProvider.overrideWith(
      () => UnreadCountNotifierMock(const UnreadCountState(count: 0)),
    ),
    dashboardSummaryProvider.overrideWith(
      (ref) => Future.value(
        DashboardSummary(
          activeProjects: 2,
          openCastingCalls: 4,
          newApplications: 3,
          shortlisted: 1,
          recentApplications: [mockApp],
        ),
      ),
    ),
  ];

  group('Production House Navigation & Layout Tests', () {
    testWidgets('Dashboard renders 5 tabs and single-line "Apps" label on 360x800', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(const DashboardScreen(), defaultOverrides));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Casting'), findsOneWidget);
      expect(find.text('Apps'), findsOneWidget);
      expect(find.text('Talent'), findsOneWidget);
      expect(find.text('Applications'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Home page displays dashboard summary and quick stats', (tester) async {
      await tester.pumpWidget(_buildTestApp(HomePage(onOpenTab: (_) {}), defaultOverrides));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Active projects'), findsOneWidget);
      expect(find.text('Open casting calls'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Projects tab displays project card and New project action', (tester) async {
      await tester.pumpWidget(_buildTestApp(const ProjectsPage(), defaultOverrides));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Midnight Express'), findsOneWidget);
      expect(find.text('New project'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Opportunities tab displays casting call card and New casting action', (tester) async {
      await tester.pumpWidget(_buildTestApp(const OpportunitiesPage(), defaultOverrides));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lead Actress — Maya'), findsOneWidget);
      expect(find.text('New casting call'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Applications tab displays received application and talent name', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const Scaffold(body: ApplicationsPage()), defaultOverrides),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Aarav Mehta'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Talent tab displays discovery cards', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(const Scaffold(body: TalentPage()), defaultOverrides),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Aarav Mehta'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('Notification Bell Badge Tests', () {
    testWidgets('Badge is shown when unread count > 0', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Scaffold(body: NotificationBell()),
          [
            unreadCountProvider.overrideWith(
              () => UnreadCountNotifierMock(const UnreadCountState(count: 3)),
            ),
          ],
        ),
      );
      await tester.pump();
      final badgeFinder = find.byType(Badge);
      expect(badgeFinder, findsOneWidget);
      final badgeWidget = tester.widget<Badge>(badgeFinder);
      expect(badgeWidget.isLabelVisible, isTrue);
      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Badge is hidden when unread count is 0', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Scaffold(body: NotificationBell()),
          [
            unreadCountProvider.overrideWith(
              () => UnreadCountNotifierMock(const UnreadCountState(count: 0)),
            ),
          ],
        ),
      );
      await tester.pump();
      final badgeFinder = find.byType(Badge);
      expect(badgeFinder, findsOneWidget);
      final badgeWidget = tester.widget<Badge>(badgeFinder);
      expect(badgeWidget.isLabelVisible, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('Badge is hidden on error (no red "!" shown)', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Scaffold(body: NotificationBell()),
          [
            unreadCountProvider.overrideWith(
              () => UnreadCountNotifierMock(
                const UnreadCountState(count: null, error: 'Network failure'),
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      final badgeFinder = find.byType(Badge);
      expect(badgeFinder, findsOneWidget);
      final badgeWidget = tester.widget<Badge>(badgeFinder);
      expect(badgeWidget.isLabelVisible, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('GoRouter Error and PH Routes Resolution', () {
    testWidgets('errorBuilder renders "Page Not Found" with Return Home button',
        (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/error-page',
        routes: [
          GoRoute(
            path: '/error-page',
            builder: (context, state) => appRouterErrorBuilder(context, state),
          ),
          GoRoute(
            path: '/role-selection',
            builder: (context, state) => const Scaffold(body: Text('ROLE_SELECTION')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
      await tester.pumpAndSettle();

      expect(find.text('Page Not Found'), findsWidgets);
      expect(find.text('Return Home'), findsOneWidget);

      await tester.tap(find.text('Return Home'));
      await tester.pumpAndSettle();
      expect(find.text('ROLE_SELECTION'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('Mock Repositories Standalone Unit Tests', () {
    test('MockProjectRepository loads projects', () async {
      final repo = MockProjectRepository();
      final projects = await repo.getProjects();
      expect(projects.length, equals(3));
      expect(projects.first.title, equals('Midnight Express'));
    });

    test('MockOpportunityRepository loads opportunities', () async {
      final repo = MockOpportunityRepository();
      final opportunities = await repo.getOpportunities();
      expect(opportunities.length, equals(2));
      expect(opportunities.first.title, contains('Lead Actress'));
    });

    test('MockTalentRepository searches talent', () async {
      final repo = MockTalentRepository();
      final talent = await repo.searchTalent();
      expect(talent.isNotEmpty, isTrue);
      expect(talent.any((t) => t.fullName == 'Aarav Mehta'), isTrue);
    });

    test('MockApplicationRepository loads applications with talent', () async {
      final talentRepo = MockTalentRepository();
      final appRepo = MockApplicationRepository(talentRepo);
      final applications = await appRepo.getApplications();
      expect(applications.length, equals(5));
      expect(applications.first.talent.fullName, isNotEmpty);
    });

    test('MockDashboardRepository computes accurate summary', () async {
      final projectRepo = MockProjectRepository();
      final oppRepo = MockOpportunityRepository();
      final talentRepo = MockTalentRepository();
      final appRepo = MockApplicationRepository(talentRepo);
      final dashboardRepo = MockDashboardRepository(projectRepo, oppRepo, appRepo);

      final summary = await dashboardRepo.getSummary();
      expect(summary.activeProjects, equals(2));
      expect(summary.openCastingCalls, equals(2));
      expect(summary.recentApplications.length, equals(3));
    });
  });
}
