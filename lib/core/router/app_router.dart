import 'package:go_router/go_router.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/auth/choose_type_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/verify_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/projects/create_project_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/opportunities/create_opportunity_screen.dart';
import '../../features/talent_discovery/talent_detail_screen.dart';
import '../../features/applications/application_detail_screen.dart';
import '../../features/company_profile/company_profile_screen.dart';
import '../../features/company_profile/edit_company_profile_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/opportunities/opportunity_detail_screen.dart';
import '../../features/opportunities/opportunity_applications_screen.dart';
import '../../features/chat/chat_list_screen.dart';
import '../../features/auth/create_account_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ChooseTypeScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const CreateAccountScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify',
      builder: (context, state) =>
          VerifyScreen(email: state.uri.queryParameters['email'] ?? ''),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    // '/projects/new' must come before '/projects/:id'
    GoRoute(
      path: '/projects/new',
      builder: (context, state) => const CreateProjectScreen(),
    ),
    GoRoute(
      path: '/projects/:id/edit',
      builder: (context, state) =>
          CreateProjectScreen(projectId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/projects/:id',
      builder: (context, state) =>
          ProjectDetailScreen(projectId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/opportunities/new',
      builder: (context, state) => const CreateOpportunityScreen(),
    ),
    GoRoute(
      path: '/opportunities/:id/edit',
      builder: (context, state) =>
          CreateOpportunityScreen(opportunityId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/opportunities/:id',
      builder: (context, state) =>
          OpportunityDetailScreen(opportunityId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/opportunities/:id/applications',
      builder: (context, state) => OpportunityApplicationsScreen(
        opportunityId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/talent/:id',
      builder: (context, state) =>
          TalentDetailScreen(talentId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/applications/:id',
      builder: (context, state) =>
          ApplicationDetailScreen(applicationId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const CompanyProfileScreen(),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditCompanyProfileScreen(),
    ),
    GoRoute(
      path: '/chat/:id',
      builder: (context, state) =>
          ChatScreen(collaborationId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/chats',
      builder: (context, state) => const ChatListScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
);