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
  static const String myFilmography = '$apiPrefix/users/me/filmography';
  static String filmCreditDetails(String creditId) => '$apiPrefix/users/me/filmography/$creditId';
  static String userFilmography(String userId) => '$apiPrefix/users/$userId/filmography';

  // ==========================================
  // 3. Projects
  // ==========================================
  static const String projectsCollection = '$apiPrefix/projects';
  static const String myProjects = '$apiPrefix/projects/my';
  static const String listProjects = '$apiPrefix/projects';
  static String projectDetails(String projectId) => '$apiPrefix/projects/$projectId';
  static const String searchProjects = '$apiPrefix/projects/search';
  static String projectOpportunities(String projectId) => '$apiPrefix/projects/$projectId/opportunities';
  static String projectApplications(String projectId) => '$apiPrefix/projects/$projectId/applications';

  // ==========================================
  // 4. Opportunities / Casting & Crew Calls (Browsing for Talent)
  // Note: Trailing slash required as reported in OpenAPI audit
  // ==========================================
  static const String opportunities = '$apiPrefix/opportunities/';
  static const String myOpportunities = '$apiPrefix/opportunities/my';
  static String opportunityDetails(String oppId) => '$apiPrefix/opportunities/$oppId';
  static String opportunityStatus(String oppId) => '$apiPrefix/opportunities/$oppId/status';
  static String opportunityApplications(String oppId) => '$apiPrefix/opportunities/$oppId/applications';
  static const String searchOpportunities = '$apiPrefix/opportunities/search';

  // ==========================================
  // 5. Talent Applications & Self-Tapes
  // Note: POST collection has trailing slash
  // ==========================================
  static const String applyOpportunity = '$apiPrefix/applications/';
  static const String applicationsCollection = '$apiPrefix/applications/';
  static const String myApplications = '$apiPrefix/applications/my';
  static String applicationDetails(String appId) => '$apiPrefix/applications/$appId';
  static String applicationStatus(String appId) => '$apiPrefix/applications/$appId/status';
  static String applicationResumeDownloadUrl(String appId) => '$apiPrefix/applications/$appId/resume-download-url';
  static String applicationReelDownloadUrl(String appId) => '$apiPrefix/applications/$appId/reel-download-url';

  // ==========================================
  // 6. Portfolio & Showreels Media
  // ==========================================
  static const String portfolioCollection = '$apiPrefix/portfolio/';
  static const String myPortfolio = '$apiPrefix/portfolio/my';
  static String portfolioItem(String mediaId) => '$apiPrefix/portfolio/$mediaId';
  static String portfolioDownloadUrl(String mediaId) => '$apiPrefix/portfolio/$mediaId/download-url';

  // ==========================================
  // 7. Social Posts (LinkedIn for Cinema Feed)
  // ==========================================
  static const String postsCollection = '$apiPrefix/posts/';
  static String postDetails(String postId) => '$apiPrefix/posts/$postId';
  static const String myPosts = '$apiPrefix/posts/my';
  static String postBookmark(String postId) => '$apiPrefix/posts/$postId/bookmark';
  static const String myBookmarks = '$apiPrefix/posts/bookmarks/my';

  // ==========================================
  // 7b. CineReels (Showreels Feed)
  // ==========================================
  static const String reelsCollection = '$apiPrefix/reels/';
  static const String myReels = '$apiPrefix/reels/my';
  static String reelDetails(String reelId) => '$apiPrefix/reels/$reelId';
  static String reelPlaybackUrl(String reelId) => '$apiPrefix/reels/$reelId/playback-url';

  // ==========================================
  // 7c. On-Set Stories (24h Ephemeral Feed)
  // ==========================================
  static const String storiesCollection = '$apiPrefix/stories/';
  static const String myStories = '$apiPrefix/stories/my';
  static String storyDetails(String storyId) => '$apiPrefix/stories/$storyId';
  static String storyPlaybackUrl(String storyId) => '$apiPrefix/stories/$storyId/playback-url';

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
  static String toggleFollow(String userId) => '$apiPrefix/connections/toggle/$userId';
  static String followStatus(String userId) => '$apiPrefix/connections/status/$userId';

  // ==========================================
  // 10. Talent Collaborations & Invitations
  // ==========================================
  static const String collaborationsCollection = '$apiPrefix/collaborations/';
  static const String myCollaborations = '$apiPrefix/collaborations/my';
  static String collaborationDetails(String collabId) => '$apiPrefix/collaborations/$collabId';
  static String acceptCollaboration(String collabId) => '$apiPrefix/collaborations/$collabId/accept';
  static String rejectCollaboration(String collabId) => '$apiPrefix/collaborations/$collabId/reject';
  static String updateCollaborationStatus(String collabId) => '$apiPrefix/collaborations/$collabId/status';

  // ==========================================
  // 11. Messaging & Real-Time Chat
  // ==========================================
  static const String sendMessage = '$apiPrefix/messages/';
  static const String listConversations = '$apiPrefix/messages/conversations';
  static String userConversation(String userId) => '$apiPrefix/messages/conversations/$userId';
  static String messageDetails(String msgId) => '$apiPrefix/messages/$msgId';
  static const String unreadMessageCount = '$apiPrefix/messages/unread-count';
  static String webSocketChat(String token) {
    final cleanBase = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final wsBase = cleanBase.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    return '$wsBase/ws/chat?token=$token&ngrok-skip-browser-warning=true';
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

  // ==========================================
  // 15. Production House Endpoints
  // ==========================================
  static const String productionHouseDashboard = '$apiPrefix/dashboard/production-house';
  static const String productionHouseMe = '$apiPrefix/production-houses/me';
  static const String productionHousesCollection = '$apiPrefix/production-houses';
  static String productionHouseDetails(String id) => '$apiPrefix/production-houses/$id';
}
