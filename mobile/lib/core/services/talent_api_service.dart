import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class TalentApiService {
  final ApiClient _apiClient;

  TalentApiService({ApiClient? client}) : _apiClient = client ?? ApiClient();

  ApiClient get client => _apiClient;

  void authenticateWithSupabaseToken(String token) {
    _apiClient.setAuthToken(token);
  }

  // ==========================================
  // 1. Health & Status
  // ==========================================
  Future<bool> checkBackendHealth() async {
    try {
      final res = await _apiClient.get(ApiEndpoints.apiHealth);
      return res != null;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // 2. Talent User Profiles
  // ==========================================
  Future<dynamic> getMyProfile() async {
    return await _apiClient.get(ApiEndpoints.myProfile);
  }

  Future<dynamic> updateProfile(Map<String, dynamic> data, {bool replace = false}) async {
    if (replace) {
      return await _apiClient.put(ApiEndpoints.myProfile, body: data);
    } else {
      return await _apiClient.patch(ApiEndpoints.myProfile, body: data);
    }
  }

  Future<dynamic> getPeerProfile(String userId) async {
    return await _apiClient.get(ApiEndpoints.userPublicProfile(userId));
  }

  Future<dynamic> listPeers({String? craft, int page = 1, int limit = 20}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (craft != null && craft.isNotEmpty) params['craft'] = craft;
    return await _apiClient.get(ApiEndpoints.listUsers, queryParams: params);
  }

  Future<dynamic> searchPeers(String query) async {
    return await _apiClient.get(ApiEndpoints.searchUsers, queryParams: {'q': query});
  }

  // ==========================================
  // 3. Opportunities / Casting Calls (Talent View)
  // ==========================================
  Future<dynamic> getOpportunities({String? craft, String? hub, int page = 1}) async {
    final params = <String, dynamic>{'page': page};
    if (craft != null && craft != 'All Crafts') params['craft'] = craft;
    if (hub != null && hub != 'Pan-India') params['hub'] = hub;
    return await _apiClient.get(ApiEndpoints.opportunities, queryParams: params);
  }

  Future<dynamic> getOpportunityDetails(String oppId) async {
    return await _apiClient.get(ApiEndpoints.opportunityDetails(oppId));
  }

  Future<dynamic> searchOpportunities(String query) async {
    return await _apiClient.get(ApiEndpoints.searchOpportunities, queryParams: {'q': query});
  }

  // ==========================================
  // 4. Talent Applications & Self-Tape Auditions
  // ==========================================
  Future<dynamic> applyForOpportunity({
    required String opportunityId,
    String? selfTapeUrl,
    String? notes,
  }) async {
    final body = {
      'opportunity_id': opportunityId,
      if (selfTapeUrl != null) 'self_tape_url': selfTapeUrl,
      if (notes != null) 'notes': notes,
    };
    return await _apiClient.post(ApiEndpoints.applyOpportunity, body: body);
  }

  Future<dynamic> getMyApplications() async {
    return await _apiClient.get(ApiEndpoints.myApplications);
  }

  Future<dynamic> withdrawApplication(String applicationId) async {
    return await _apiClient.delete(ApiEndpoints.applicationDetails(applicationId));
  }

  // ==========================================
  // 5. Portfolio & Showreels
  // ==========================================
  Future<dynamic> getMyPortfolio() async {
    return await _apiClient.get(ApiEndpoints.myPortfolio);
  }

  Future<dynamic> addPortfolioMedia({
    required String title,
    required String mediaUrl,
    String? craft,
    String? smpteTimecode,
  }) async {
    final body = {
      'title': title,
      'media_url': mediaUrl,
      if (craft != null) 'craft': craft,
      if (smpteTimecode != null) 'smpte_timecode': smpteTimecode,
    };
    return await _apiClient.post(ApiEndpoints.portfolioCollection, body: body);
  }

  Future<dynamic> deletePortfolioMedia(String mediaId) async {
    return await _apiClient.delete(ApiEndpoints.portfolioItem(mediaId));
  }

  // ==========================================
  // 6. LinkedIn for Cinema Social Feed
  // ==========================================
  Future<dynamic> getFeedPosts({int page = 1, int limit = 20}) async {
    return await _apiClient.get(ApiEndpoints.postsCollection, queryParams: {'page': page, 'limit': limit});
  }

  Future<dynamic> createFeedPost({
    required String contentText,
    String? videoSlateTitle,
    String? smpteTimecode,
    List<String>? craftTags,
  }) async {
    final body = {
      'content': contentText,
      if (videoSlateTitle != null) 'video_slate_title': videoSlateTitle,
      if (smpteTimecode != null) 'smpte_timecode': smpteTimecode,
      if (craftTags != null) 'tags': craftTags,
    };
    return await _apiClient.post(ApiEndpoints.postsCollection, body: body);
  }

  Future<dynamic> interactWithPost({
    required String postId,
    required String interactionType, // 'clap', 'timecode_critique', 'share'
    String? timecode,
    String? critiqueNote,
  }) async {
    final body = {
      'post_id': postId,
      'type': interactionType,
      if (timecode != null) 'timecode': timecode,
      if (critiqueNote != null) 'note': critiqueNote,
    };
    return await _apiClient.post(ApiEndpoints.interactionsCollection, body: body);
  }

  // ==========================================
  // 7. 24-Crafts Peer Connections & Radar
  // ==========================================
  Future<dynamic> getMyConnections() async {
    return await _apiClient.get(ApiEndpoints.myConnections);
  }

  Future<dynamic> getConnectionRequests() async {
    return await _apiClient.get(ApiEndpoints.connectionRequests);
  }

  Future<dynamic> sendConnectionRequest(String targetUserId) async {
    return await _apiClient.post(ApiEndpoints.sendConnection, body: {'target_user_id': targetUserId});
  }

  Future<dynamic> acceptConnectionRequest(String connectionId) async {
    return await _apiClient.patch(ApiEndpoints.acceptConnection(connectionId));
  }

  Future<dynamic> rejectConnectionRequest(String connectionId) async {
    return await _apiClient.patch(ApiEndpoints.rejectConnection(connectionId));
  }

  // ==========================================
  // 8. Collaborations & Project Invitations
  // ==========================================
  Future<dynamic> getMyCollaborations() async {
    return await _apiClient.get(ApiEndpoints.myCollaborations);
  }

  Future<dynamic> acceptCollaboration(String collabId) async {
    return await _apiClient.patch(ApiEndpoints.acceptCollaboration(collabId));
  }

  Future<dynamic> rejectCollaboration(String collabId) async {
    return await _apiClient.patch(ApiEndpoints.rejectCollaboration(collabId));
  }

  // ==========================================
  // 9. Real-Time Messaging & Notifications
  // ==========================================
  Future<dynamic> listConversations() async {
    return await _apiClient.get(ApiEndpoints.listConversations);
  }

  Future<dynamic> getConversationMessages(String peerUserId) async {
    return await _apiClient.get(ApiEndpoints.userConversation(peerUserId));
  }

  Future<dynamic> sendDirectMessage({required String recipientUserId, required String content}) async {
    final body = {
      'recipient_id': recipientUserId,
      'content': content,
    };
    return await _apiClient.post(ApiEndpoints.sendMessage, body: body);
  }

  Future<dynamic> getNotifications() async {
    return await _apiClient.get(ApiEndpoints.notifications);
  }

  Future<dynamic> markAllNotificationsRead() async {
    return await _apiClient.patch(ApiEndpoints.markAllNotificationsRead);
  }

  // ==========================================
  // 10. Presigned Media Upload & Dashboard
  // ==========================================
  Future<dynamic> requestPresignedUploadUrl({required String filename, required String contentType}) async {
    final body = {
      'filename': filename,
      'content_type': contentType,
    };
    return await _apiClient.post(ApiEndpoints.mediaUploadUrl, body: body);
  }

  Future<dynamic> getTalentDashboard() async {
    return await _apiClient.get(ApiEndpoints.talentDashboard);
  }
}
