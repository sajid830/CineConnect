import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cineconnect/core/state/app_state.dart';
import 'package:cineconnect/features/profile/profile_settings_screen.dart';
import 'package:cineconnect/features/production_house/company_profile/company_profile_screen.dart';
import 'package:cineconnect/features/production_house/company_profile/company_profile_provider.dart';
import 'package:cineconnect/features/production_house/home/home_provider.dart';
import 'package:cineconnect/features/production_house/projects/projects_provider.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_provider.dart';
import 'package:cineconnect/features/production_house/talent_discovery/portfolio_provider.dart';
import 'package:cineconnect/features/production_house/data/models/company_profile.dart';
import 'package:cineconnect/features/production_house/data/models/dashboard_summary.dart';
import 'package:cineconnect/features/production_house/data/models/project.dart';
import 'package:cineconnect/features/production_house/data/models/opportunity.dart';
import 'package:cineconnect/features/production_house/data/models/portfolio_item.dart';
import 'package:cineconnect/screens/auth_gate.dart';
import 'package:cineconnect/screens/role_selection_screen.dart';
import 'package:cineconnect/features/talent/presentation/talent_portal_screen.dart';
import 'package:cineconnect/app/router/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Talent Logout Flow Tests (profile_settings_screen.dart)', () {
    testWidgets('Tapping logout calls signOut, displays success SnackBar, and navigates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int signOutCalls = 0;
      final appState = CineAppState(autoCheckConnectivity: false);

      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => ProfileSettingsScreen(
              appState: appState,
              onSignOut: () async {
                signOutCalls++;
              },
            ),
          ),
          GoRoute(
            path: '/role-selection',
            builder: (context, state) => const Scaffold(
              body: Text('ROLE_SELECTION_SCREEN'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);
      await tester.drag(listFinder, const Offset(0, -800));
      await tester.pump();

      final logoutTileFinder = find.widgetWithText(ListTile, 'Log out');
      expect(logoutTileFinder, findsOneWidget);

      await tester.tap(logoutTileFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Log out of CineConnect?'), findsOneWidget);

      final confirmBtn = find.widgetWithText(TextButton, 'Log out');
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(signOutCalls, equals(1));
      expect(find.text('ROLE_SELECTION_SCREEN'), findsOneWidget);
      expect(find.text('Logged out of CineConnect'), findsOneWidget);
    });

    testWidgets('Failed signOut displays error message and does not navigate or report success',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int signOutCalls = 0;
      final appState = CineAppState(autoCheckConnectivity: false);

      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => ProfileSettingsScreen(
              appState: appState,
              onSignOut: () async {
                signOutCalls++;
                throw const AuthException('Network connectivity failure during revocation');
              },
            ),
          ),
          GoRoute(
            path: '/role-selection',
            builder: (context, state) => const Scaffold(
              body: Text('ROLE_SELECTION_SCREEN'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final listFinder = find.byType(ListView);
      await tester.drag(listFinder, const Offset(0, -800));
      await tester.pump();

      final logoutTileFinder = find.widgetWithText(ListTile, 'Log out');
      await tester.tap(logoutTileFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final confirmBtn = find.widgetWithText(TextButton, 'Log out');
      await tester.tap(confirmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(signOutCalls, equals(1));
      expect(find.text('ROLE_SELECTION_SCREEN'), findsNothing);
      expect(find.textContaining('Sign out failed:'), findsOneWidget);
      expect(find.text('Logged out of CineConnect'), findsNothing);
    });
  });

  group('2. Production House Logout Flow Tests (company_profile_screen.dart)', () {
    testWidgets('Production House logout calls signOut and navigates to role selection',
        (WidgetTester tester) async {
      int signOutCalls = 0;

      final router = GoRouter(
        initialLocation: '/company-profile',
        routes: [
          GoRoute(
            path: '/company-profile',
            builder: (context, state) => CompanyProfileScreen(
              onSignOut: () async {
                signOutCalls++;
              },
            ),
          ),
          GoRoute(
            path: '/role-selection',
            builder: (context, state) => const Scaffold(
              body: Text('ROLE_SELECTION_SCREEN'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            companyProfileProvider.overrideWith(
              () => _FakeCompanyProfileNotifier(
                const CompanyProfile(
                  id: 'ph-1',
                  companyName: 'Paramount India',
                  description: 'Studio description',
                  location: 'Mumbai',
                  specialization: 'Feature Films',
                  email: 'studio@paramount.com',
                  isVerified: true,
                ),
              ),
            ),
            projectsProvider.overrideWith(_FakeProjectsNotifier.new),
            opportunitiesProvider.overrideWith(_FakeOpportunitiesNotifier.new),
            portfolioProvider.overrideWith((ref, userId) async => const <PortfolioItem>[]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final settingsBtn = find.byTooltip('Settings');
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final logoutTile = find.widgetWithText(ListTile, 'Log out');
      expect(logoutTile, findsOneWidget);
      await tester.tap(logoutTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(signOutCalls, equals(1));
      expect(find.text('ROLE_SELECTION_SCREEN'), findsOneWidget);
      expect(find.text('Logged out of CineConnect'), findsOneWidget);
    });

    testWidgets('Production House failed signOut displays error and preserves screen',
        (WidgetTester tester) async {
      int signOutCalls = 0;

      final router = GoRouter(
        initialLocation: '/company-profile',
        routes: [
          GoRoute(
            path: '/company-profile',
            builder: (context, state) => CompanyProfileScreen(
              onSignOut: () async {
                signOutCalls++;
                throw const AuthException('Session revocation timed out');
              },
            ),
          ),
          GoRoute(
            path: '/role-selection',
            builder: (context, state) => const Scaffold(
              body: Text('ROLE_SELECTION_SCREEN'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            companyProfileProvider.overrideWith(
              () => _FakeCompanyProfileNotifier(
                const CompanyProfile(
                  id: 'ph-1',
                  companyName: 'Paramount India',
                  description: 'Studio description',
                  location: 'Mumbai',
                  specialization: 'Feature Films',
                  email: 'studio@paramount.com',
                  isVerified: true,
                ),
              ),
            ),
            projectsProvider.overrideWith(_FakeProjectsNotifier.new),
            opportunitiesProvider.overrideWith(_FakeOpportunitiesNotifier.new),
            portfolioProvider.overrideWith((ref, userId) async => const <PortfolioItem>[]),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final settingsBtn = find.byTooltip('Settings');
      await tester.tap(settingsBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final logoutTile = find.widgetWithText(ListTile, 'Log out');
      await tester.tap(logoutTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(signOutCalls, equals(1));
      expect(find.text('ROLE_SELECTION_SCREEN'), findsNothing);
      expect(find.textContaining('Sign out failed:'), findsOneWidget);
      expect(find.text('Logged out of CineConnect'), findsNothing);
    });
  });

  group('3. Riverpod State Invalidation Tests (invalidateProductionHouseContainer)', () {
    test('Invalidates all user-specific Production House providers on logout', () {
      int companyProfileBuilds = 0;
      int dashboardSummaryBuilds = 0;

      final container = ProviderContainer(
        overrides: [
          companyProfileProvider.overrideWith(
            () => _CountedCompanyProfileNotifier(() => companyProfileBuilds++),
          ),
          dashboardSummaryProvider.overrideWith((ref) {
            dashboardSummaryBuilds++;
            return const DashboardSummary(
              activeProjects: 2,
              openCastingCalls: 5,
              newApplications: 12,
              shortlisted: 3,
              recentApplications: [],
            );
          }),
        ],
      );

      container.read(companyProfileProvider);
      container.read(dashboardSummaryProvider);
      expect(companyProfileBuilds, equals(1));
      expect(dashboardSummaryBuilds, equals(1));

      invalidateProductionHouseContainer(container);

      container.read(companyProfileProvider);
      container.read(dashboardSummaryProvider);
      expect(companyProfileBuilds, equals(2));
      expect(dashboardSummaryBuilds, equals(2));
    });
  });

  group('4. AuthGate SignedOut Handling Tests', () {
    testWidgets('AuthGate transitions to RoleSelectionScreen upon AuthChangeEvent.signedOut',
        (WidgetTester tester) async {
      final authController = StreamController<AuthState>.broadcast();
      final mockUser = User(
        id: 'user-123',
        appMetadata: {},
        userMetadata: {'account_type': 'talent'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final initialSession = Session(
        accessToken: 'token-abc',
        tokenType: 'bearer',
        user: mockUser,
      );

      final appState = CineAppState(autoCheckConnectivity: false);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStream: authController.stream,
            initialSession: initialSession,
            autoCheckHealth: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(TalentPortalScreen), findsOneWidget);
      expect(find.byType(RoleSelectionScreen), findsNothing);

      authController.add(
        const AuthState(AuthChangeEvent.signedOut, null),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(RoleSelectionScreen), findsOneWidget);
      expect(find.byType(TalentPortalScreen), findsNothing);

      await authController.close();
      appState.dispose();
    });
  });

  group('5. GoRouter Unauthenticated Route Guard & Back Navigation Reset Tests', () {
    testWidgets('Unauthenticated direct access to protected routes redirects to role-selection',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Attempting to navigate to protected talent route without session
      appRouter.go('/talent');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(appRouter.routerDelegate.currentConfiguration.uri.path, equals('/role-selection'));
      expect(find.byType(RoleSelectionScreen), findsWidgets);
      expect(find.byType(TalentPortalScreen), findsNothing);

      // Attempting to navigate to protected production house route without session
      appRouter.go('/production-house');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(appRouter.routerDelegate.currentConfiguration.uri.path, equals('/role-selection'));
      expect(find.byType(RoleSelectionScreen), findsWidgets);

      // Attempting to navigate to nested protected project creation route
      appRouter.go('/projects/new');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(appRouter.routerDelegate.currentConfiguration.uri.path, equals('/role-selection'));
      expect(find.byType(RoleSelectionScreen), findsWidgets);
    });
  });
}

// ---------------- Helper Mock Notifiers ----------------

class _FakeCompanyProfileNotifier extends CompanyProfileNotifier {
  final CompanyProfile _profile;
  _FakeCompanyProfileNotifier(this._profile);

  @override
  Future<CompanyProfile> build() async => _profile;
}

class _CountedCompanyProfileNotifier extends CompanyProfileNotifier {
  final VoidCallback onBuild;
  _CountedCompanyProfileNotifier(this.onBuild);

  @override
  Future<CompanyProfile> build() async {
    onBuild();
    return const CompanyProfile(
      id: 'counted-1',
      companyName: 'Counted Studio',
      description: 'Desc',
      location: 'Hyd',
      specialization: 'Cinema',
      email: 'studio@counted.com',
      isVerified: true,
    );
  }
}

class _FakeProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<Project>> build() async => const <Project>[];
}

class _FakeOpportunitiesNotifier extends OpportunitiesNotifier {
  @override
  Future<List<Opportunity>> build() async => const <Opportunity>[];
}
