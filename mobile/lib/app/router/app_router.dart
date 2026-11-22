import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/auth_gate.dart';
import '../../screens/role_selection_screen.dart';
import '../../screens/auth_screen.dart';
import '../../screens/forgot_password_screen.dart';
import '../../screens/verification_screen.dart';
import '../../features/talent/presentation/talent_portal_screen.dart';
import '../../features/production_house/dashboard/dashboard_screen.dart';
import '../../features/production_house/projects/create_project_screen.dart';
import '../../features/production_house/projects/project_detail_screen.dart';
import '../../features/production_house/opportunities/create_opportunity_screen.dart';
import '../../features/production_house/opportunities/opportunity_detail_screen.dart';
import '../../features/production_house/opportunities/opportunity_applications_screen.dart';
import '../../features/production_house/applications/application_detail_screen.dart';
import '../../features/production_house/talent_discovery/talent_detail_screen.dart';
import '../../features/production_house/company_profile/company_profile_screen.dart';
import '../../features/production_house/company_profile/edit_company_profile_screen.dart';
import '../../features/production_house/chat/chat_screen.dart';
import '../../features/production_house/notifications/notifications_screen.dart';
import '../../features/diagnostics/presentation/diagnostic_home_screen.dart';

/// Central CineConnect GoRouter configuration connecting:
/// 1. Shared Onboarding & Role Selection (/)
/// 2. Authentication & Verification (/auth, /forgot-password, /verify)
/// 3. Talent Cinema Super-App Portal (/talent)
/// 4. Production House Studio Dashboard & Workflow (/production-house, /projects/*, etc.)
/// 5. Service Diagnostics (/diagnostics)
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final location = state.uri.path;
    final isGoingToAuth = location == '/' ||
        location == '/role-selection' ||
        location == '/auth' ||
        location.startsWith('/login') ||
        location == '/forgot-password' ||
        location == '/verify' ||
        location == '/diagnostics';

    // If attempting to access an open route, allow without session checks
    if (isGoingToAuth) {
      return null;
    }

    Session? session;
    try {
      session = Supabase.instance.client.auth.currentSession;
    } catch (_) {
      session = null;
    }

    // Protect all dashboard routes against unauthenticated access
    if (session == null) {
      return '/role-selection';
    }

    final role = resolveUserAuthRole(session.user.userMetadata);

    // Cross-role route protection:
    final isTalentRoute = location.startsWith('/talent');
    final isProductionRoute = location.startsWith('/production-house') ||
        location.startsWith('/projects') ||
        location.startsWith('/opportunities') ||
        location.startsWith('/applications') ||
        location.startsWith('/talent-profile') ||
        location.startsWith('/company-profile') ||
        location.startsWith('/ph-');

    if (isTalentRoute && role != AuthRole.talent) {
      // Production House attempting to access Talent route
      return '/production-house';
    }

    if (isProductionRoute && role != AuthRole.productionHouse) {
      // Talent attempting to access Production House route
      return '/talent';
    }

    return null;
  },
  routes: [
    // --- Shared Onboarding & Account Selection ---
    GoRoute(
      path: '/',
      name: 'root',
      builder: (context, state) => const AuthGate(),
    ),
    GoRoute(
      path: '/role-selection',
      name: 'role_selection',
      builder: (context, state) => const RoleSelectionScreen(),
    ),

    // --- Authentication ---
    GoRoute(
      path: '/auth',
      name: 'auth',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'talent';
        return AuthScreen(selectedRole: role);
      },
    ),
    GoRoute(
      path: '/login/:role',
      redirect: (context, state) {
        final role = state.pathParameters['role'] ?? 'talent';
        return '/auth?role=$role';
      },
    ),
    GoRoute(
      path: '/forgot-password',
      name: 'forgot_password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify',
      name: 'verify',
      builder: (context, state) => VerificationScreen(
        email: state.uri.queryParameters['email'] ?? '',
        roleType: state.uri.queryParameters['role'] ?? 'talent',
      ),
    ),

    // --- Talent Portal ---
    GoRoute(
      path: '/talent',
      name: 'talent_portal',
      builder: (context, state) => const TalentPortalScreen(),
    ),

    // --- Production House Portal & Workflow ---
    GoRoute(
      path: '/production-house',
      name: 'production_house_dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/projects/new',
      name: 'create_project',
      builder: (context, state) => const CreateProjectScreen(),
    ),
    GoRoute(
      path: '/projects/:id',
      name: 'project_detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ProjectDetailScreen(projectId: id);
      },
    ),
    GoRoute(
      path: '/projects/:id/edit',
      name: 'edit_project',
      builder: (context, state) {
        final id = state.pathParameters['id'];
        return CreateProjectScreen(projectId: id);
      },
    ),
    GoRoute(
      path: '/opportunities/new',
      name: 'create_opportunity',
      builder: (context, state) => CreateOpportunityScreen(
        opportunityId: state.uri.queryParameters['opportunityId'],
      ),
    ),
    GoRoute(
      path: '/opportunities/:id',
      name: 'opportunity_detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return OpportunityDetailScreen(opportunityId: id);
      },
    ),
    GoRoute(
      path: '/opportunities/:id/applications',
      name: 'opportunity_applications',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return OpportunityApplicationsScreen(opportunityId: id);
      },
    ),
    GoRoute(
      path: '/applications/:id',
      name: 'application_detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return ApplicationDetailScreen(applicationId: id);
      },
    ),
    GoRoute(
      path: '/talent-profile/:id',
      name: 'talent_detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return TalentDetailScreen(talentId: id);
      },
    ),
    GoRoute(
      path: '/company-profile',
      name: 'company_profile',
      builder: (context, state) => const CompanyProfileScreen(),
    ),
    GoRoute(
      path: '/company-profile/edit',
      name: 'edit_company_profile',
      builder: (context, state) => const EditCompanyProfileScreen(),
    ),
    GoRoute(
      path: '/ph-chat',
      name: 'ph_chat',
      builder: (context, state) {
        final id = state.uri.queryParameters['collaborationId'] ?? 'general';
        return ChatScreen(collaborationId: id);
      },
    ),
    GoRoute(
      path: '/ph-notifications',
      name: 'ph_notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),

    // --- Diagnostics ---
    GoRoute(
      path: '/diagnostics',
      name: 'diagnostics',
      builder: (context, state) => const DiagnosticHomeScreen(),
    ),
  ],
);
