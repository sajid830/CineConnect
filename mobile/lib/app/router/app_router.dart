import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
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
import '../../features/production_house/chat/chat_list_screen.dart';
import '../../features/production_house/notifications/notifications_screen.dart';
import '../../features/diagnostics/presentation/diagnostic_home_screen.dart';
import '../../features/search/global_search_screen.dart';

Widget appRouterErrorBuilder(BuildContext context, GoRouterState state) => Scaffold(
  backgroundColor: AppColors.background,
  appBar: AppBar(
    title: const Text('Page Not Found'),
    backgroundColor: AppColors.background,
  ),
  body: Center(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.gold),
          const SizedBox(height: 16),
          const Text(
            'Page Not Found',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.error?.message ?? 'The requested page does not exist.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/role-selection'),
            icon: const Icon(Icons.home),
            label: const Text('Return Home'),
          ),
        ],
      ),
    ),
  ),
);

/// Central CineConnect GoRouter configuration connecting:
/// 1. Shared Onboarding & Role Selection (/)
/// 2. Authentication & Verification (/auth, /forgot-password, /verify)
/// 3. Talent Cinema Super-App Portal (/talent)
/// 4. Production House Studio Dashboard & Workflow (/production-house, /projects/*, etc.)
/// 5. Service Diagnostics (/diagnostics)
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: appRouterErrorBuilder,
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
    final isTalentRoute = location == '/talent' ||
        (location.startsWith('/talent/') &&
            !location.startsWith('/talent-profile'));
    final isProductionRoute = location.startsWith('/production-house') ||
        location.startsWith('/projects') ||
        location.startsWith('/opportunities') ||
        location.startsWith('/applications') ||
        location.startsWith('/talent-profile') ||
        location.startsWith('/company-profile') ||
        location.startsWith('/ph-') ||
        location.startsWith('/chat');

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
        final id = state.uri.queryParameters['collaborationId'];
        if (id == null || id.isEmpty || id == 'general') {
          return const ChatListScreen();
        }
        return ChatScreen(collaborationId: id);
      },
    ),
    GoRoute(
      path: '/chat/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id'] ?? 'general';
        return '/ph-chat?collaborationId=$id';
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

    // --- Global Search ---
    GoRoute(
      path: '/search',
      name: 'global_search',
      builder: (context, state) => const GlobalSearchScreen(),
    ),

    // --- Production House Backwards-Compatible Aliases ---
    GoRoute(
      path: '/profile',
      redirect: (context, state) => '/company-profile',
    ),
    GoRoute(
      path: '/profile/edit',
      redirect: (context, state) => '/company-profile/edit',
    ),
    GoRoute(
      path: '/chats',
      redirect: (context, state) => '/ph-chat',
    ),
    GoRoute(
      path: '/notifications',
      redirect: (context, state) => '/ph-notifications',
    ),
    GoRoute(
      path: '/talent/:id',
      redirect: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return '/talent-profile/$id';
      },
    ),
    GoRoute(
      path: '/dashboard',
      redirect: (context, state) => '/production-house',
    ),
  ],
);
