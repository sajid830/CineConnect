import '../config/env_config.dart';

class ApiEndpoints {
  // Base URL resolution delegated to central EnvConfig architecture
  static String get baseUrl => EnvConfig.fromEnvironment().apiBaseUrl;

  static const String apiPrefix = '/api/v1';

  // ==========================================
  // 1. Health & Infrastructure
  // ==========================================
  static const String health = '/health';
  static const String apiHealth = '$apiPrefix/health';
  static const String dbHealth = '$apiPrefix/health/db';

  // ==========================================
  // 2. Talent User Profiles
  // ==========================================
  static const String myProfile = '$apiPrefix/users/me';
  static String userPublicProfile(String userId) => '$apiPrefix/users/$userId';
  static const String listUsers = '$apiPrefix/users';
  static const String searchUsers = '$apiPrefix/users/search';
  static String userPortfolio(String userId) => '$apiPrefix/users/$userId/portfolio';
  static String userPosts(String userId) => '$apiPrefix/users/$userId/posts';
  static String userConnections(String userId) => '$apiPrefix/users/$userId/connections';
  static String userFollowers(String userId) => '$apiPrefix/users/$userId/followers';
  static String userFollowing(String userId) => '$apiPrefix/users/$userId/following';

  // ==========================================
  // 3. Projects (Read-only for Talent)
  // ==========================================
  static const String listProjects = '$apiPrefix/projects';
  static String projectDetails(String projectId) => '$apiPrefix/projects/$projectId';
  static const String searchProjects = '$apiPrefix/projects/search';
  static String projectOpportunities(String projectId) => '$apiPrefix/projects/$projectId/opportunities';

  // ==========================================
  // 4. Opportunities / Casting & Crew Calls (Browsing for Talent)
  // Note: Trailing slash required as reported in OpenAPI audit
  // ==========================================
  static const String opportunities = '$apiPrefix/opportunities/';
  static String opportunityDetails(String oppId) => '$apiPrefix/opportunities/$oppId';
  static const String searchOpportunities = '$apiPrefix/opportunities/search';

  // ==========================================
  // 5. Talent Applications & Self-Tapes
  // Note: POST collection has trailing slash
  // ==========================================
  static const String applyOpportunity = '$apiPrefix/applications/';
  static const String myApplications = '$apiPrefix/applications/my';
  static String applicationDetails(String appId) => '$apiPrefix/applications/$appId';

  // ==========================================
  // 6. Portfolio & Showreels Media
  // ==========================================
  static const String portfolioCollection = '$apiPrefix/portfolio/';
  static const String myPortfolio = '$apiPrefix/portfolio/my';
  static String portfolioItem(String mediaId) => '$apiPrefix/portfolio/$mediaId';

  // ==========================================
  // 7. Social Posts (LinkedIn for Cinema Feed)
  // ==========================================
  static const String postsCollection = '$apiPrefix/posts/';
  static String postDetails(String postId) => '$apiPrefix/posts/$postId';
  static const String myPosts = '$apiPrefix/posts/my';

  // ==========================================
  // 8. Interactions (Likes, Claps, Timecode Critiques)
  // ==========================================
  static const String interactionsCollection = '$apiPrefix/interactions/';
  static const String myInteractions = '$apiPrefix/interactions/my';
  static String interactionDetails(String interactionId) => '$apiPrefix/interactions/$interactionId';
  // Fallback path flagged in audit
  static String postInteractions(String postId) => '$apiPrefix/interactions/posts/$postId/interactions';

  // ==========================================
  // 9. Connections & Peer Network (24-Crafts Radar)
  // ==========================================
  static const String sendConnection = '$apiPrefix/connections/';
  static const String myConnections = '$apiPrefix/connections/my';
  static const String connectionRequests = '$apiPrefix/connections/requests';
  static String acceptConnection(String connId) => '$apiPrefix/connections/$connId/accept';
  static String rejectConnection(String connId) => '$apiPrefix/connections/$connId/reject';
  static String removeConnection(String connId) => '$apiPrefix/connections/$connId';

  // ==========================================
  // 10. Talent Collaborations & Invitations
  // ==========================================
  static const String myCollaborations = '$apiPrefix/collaborations/my';
  static String collaborationDetails(String collabId) => '$apiPrefix/collaborations/$collabId';
  static String acceptCollaboration(String collabId) => '$apiPrefix/collaborations/$collabId/accept';
  static String rejectCollaboration(String collabId) => '$apiPrefix/collaborations/$collabId/reject';

  // ==========================================
  // 11. Messaging & Real-Time Chat
  // ==========================================
  static const String sendMessage = '$apiPrefix/messages/';
  static const String listConversations = '$apiPrefix/messages/conversations';
  static String userConversation(String userId) => '$apiPrefix/messages/conversations/$userId';
  static String messageDetails(String msgId) => '$apiPrefix/messages/$msgId';
  static const String unreadMessageCount = '$apiPrefix/messages/unread-count';
  static String webSocketChat(String token) {
    final wsBase = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    return '$wsBase/ws/chat?token=$token';
  }

  // ==========================================
  // 12. Search & Notifications
  // ==========================================
  static const String globalSearch = '$apiPrefix/search/';
  static const String notifications = '$apiPrefix/notifications/';
  static const String unreadNotificationCount = '$apiPrefix/notifications/unread-count';
  static String markNotificationRead(String notifId) => '$apiPrefix/notifications/$notifId/read';
  static const String markAllNotificationsRead = '$apiPrefix/notifications/read-all';

  // ==========================================
  // 13. Media Upload (Presigned S3/Storage URL)
  // ==========================================
  static const String mediaUploadUrl = '$apiPrefix/media/upload-url';

  // ==========================================
  // 14. Talent Dashboard
  // (Exclusive to Talent User Portal)
  // ==========================================
  static const String talentDashboard = '$apiPrefix/dashboard/talent';
}
