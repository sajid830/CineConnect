import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'chat_service.dart';
import 'media_upload_service.dart';

class TalentApiService {
  final ApiClient _apiClient;
  final MediaUploadService _mediaUploadService;
  final ChatService _chatService;

  TalentApiService({
    ApiClient? client,
    MediaUploadService? mediaUploadService,
    ChatService? chatService,
  })  : _apiClient = client ?? ApiClient(),
        _mediaUploadService =
            mediaUploadService ?? MediaUploadService(apiClient: client),
        _chatService = chatService ?? ChatService(apiClient: client);

  ApiClient get client => _apiClient;
  MediaUploadService get mediaUploadService => _mediaUploadService;
  ChatService get chatService => _chatService;

  /// Updates the authentication token for both this service instance and centrally in ApiClient.
  void authenticateWithSupabaseToken(String? token) {
    _apiClient.setAuthToken(token);
    ApiClient.setGlobalAuthToken(token);
  }

  /// Clears the authentication token on this service instance and centrally in ApiClient.
  void clearAuthToken() {
    _apiClient.clearAuthToken();
    ApiClient.clearGlobalAuthToken();
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
    final skip = (page - 1) * limit;
    final params = <String, dynamic>{'skip': skip, 'limit': limit};
    if (craft != null && craft.isNotEmpty) params['craft'] = craft;
    return await _apiClient.get(ApiEndpoints.listUsers, queryParams: params);
  }

  Future<dynamic> searchPeers(String query) async {
    return await _apiClient.get(ApiEndpoints.searchUsers, queryParams: {'q': query});
  }

  Future<List<dynamic>> getMyFilmography() async {
    final res = await _apiClient.get(ApiEndpoints.myFilmography);
    if (res is List) return res;
    return [];
  }

  Future<dynamic> addFilmCredit(Map<String, dynamic> data) async {
    return await _apiClient.post(ApiEndpoints.myFilmography, body: data);
  }

  Future<dynamic> updateFilmCredit(String creditId, Map<String, dynamic> data) async {
    return await _apiClient.put(ApiEndpoints.filmCreditDetails(creditId), body: data);
  }

  Future<void> deleteFilmCredit(String creditId) async {
    await _apiClient.delete(ApiEndpoints.filmCreditDetails(creditId));
  }

  Future<List<dynamic>> getUserFilmography(String userId) async {
    final res = await _apiClient.get(ApiEndpoints.userFilmography(userId));
    if (res is List) return res;
    return [];
  }

  // ==========================================
  // 3. Opportunities / Casting Calls (Talent View)
  // ==========================================
  Future<dynamic> getOpportunities({String? craft, String? hub, int page = 1, int limit = 20}) async {
    final skip = (page - 1) * limit;
    final params = <String, dynamic>{'skip': skip, 'limit': limit};
    if (craft != null && craft != 'All Crafts') params['role_type'] = craft;
    if (hub != null && hub != 'Pan-India') params['location'] = hub;
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
  /// Uploads confidential media (such as resumes and self-tapes) to MinIO private storage.
  Future<MediaUploadResult> uploadPrivateMedia({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    return await _mediaUploadService.uploadFile(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      purpose: 'private',
    );
  }

  /// Streams confidential media directly to MinIO private storage without memory buffering.
  Future<MediaUploadResult> uploadPrivateXFile({
    required XFile file,
    required String contentType,
  }) async {
    return await _mediaUploadService.uploadXFile(
      file: file,
      contentType: contentType,
      purpose: 'private',
    );
  }

  /// Streams arbitrary chunked data to MinIO private storage without memory buffering.
  Future<MediaUploadResult> uploadPrivateStream({
    required Stream<List<int>> stream,
    required int length,
    required String fileName,
    required String contentType,
  }) async {
    return await _mediaUploadService.uploadStream(
      stream: stream,
      length: length,
      fileName: fileName,
      contentType: contentType,
      purpose: 'private',
    );
  }

  /// Streams a resume/document directly to MinIO private storage without memory buffering.
  Future<MediaUploadResult> uploadPrivateResumeStream({
    required Stream<List<int>> stream,
    required int length,
    required String fileName,
  }) async {
    return await _mediaUploadService.uploadResumeStream(
      stream: stream,
      length: length,
      fileName: fileName,
    );
  }

  Future<dynamic> applyForOpportunity({
    required String opportunityId,
    String? selfTapeUrl,
    String? notes,
    String? resumeUrl,
  }) async {
    final body = {
      'opportunity_id': opportunityId,
      if (selfTapeUrl != null) 'reel_url': selfTapeUrl,
      if (notes != null) 'cover_letter': notes,
      if (resumeUrl != null) 'resume_url': resumeUrl,
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
  // Public Projects Discovery & Application
  // ==========================================
  Future<dynamic> getPublicProjects({int page = 1, int limit = 50}) async {
    final skip = (page - 1) * limit;
    return await _apiClient.get(ApiEndpoints.projectsCollection, queryParams: {'skip': skip, 'limit': limit});
  }

  Future<dynamic> applyToProject({
    required String projectId,
    String? coverLetter,
    String? resumeUrl,
    String? reelUrl,
  }) async {
    final body = {
      'project_id': projectId,
      if (coverLetter != null && coverLetter.isNotEmpty) 'cover_letter': coverLetter,
      if (resumeUrl != null && resumeUrl.isNotEmpty) 'resume_url': resumeUrl,
      if (reelUrl != null && reelUrl.isNotEmpty) 'reel_url': reelUrl,
    };
    return await _apiClient.post(ApiEndpoints.applicationsCollection, body: body);
  }

  // ==========================================
  // 5. Portfolio & Showreels
  // ==========================================
  Future<dynamic> getMyPortfolio() async {
    return await _apiClient.get(ApiEndpoints.myPortfolio);
  }

  Future<dynamic> getPortfolioDownloadUrl(String mediaId) async {
    return await _apiClient.get(ApiEndpoints.portfolioDownloadUrl(mediaId));
  }

  Future<dynamic> addPortfolioMedia({
    required String title,
    required String mediaUrl,
    String? craft,
    String? smpteTimecode,
    String? description,
    String mediaType = 'video',
    String? thumbnailUrl,
  }) async {
    final body = {
      'title': title,
      'media_url': mediaUrl,
      'media_type': mediaType,
      if (description != null) 'description': description,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
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
    final skip = (page - 1) * limit;
    return await _apiClient.get(ApiEndpoints.postsCollection, queryParams: {'skip': skip, 'limit': limit});
  }

  Future<dynamic> createFeedPost({
    required String contentText,
    String? mediaUrl,
    String? videoSlateTitle,
    String? smpteTimecode,
    List<String>? craftTags,
  }) async {
    final body = {
      'caption': contentText,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (videoSlateTitle != null) 'video_slate_title': videoSlateTitle,
      if (smpteTimecode != null) 'smpte_timecode': smpteTimecode,
      if (craftTags != null) 'tags': craftTags,
    };
    return await _apiClient.post(ApiEndpoints.postsCollection, body: body);
  }

  Future<dynamic> interactWithPost({
    required String postId,
    required String interactionType, // 'like', 'clap', 'timecode_critique', 'share', 'comment'
    String? timecode,
    String? critiqueNote,
  }) async {
    final mappedType = (interactionType == 'clap' || interactionType == 'like') ? 'like' : interactionType;
    final body = {
      'post_id': postId,
      'type': mappedType,
      if (timecode != null) 'timecode': timecode,
      if (critiqueNote != null) 'comment': critiqueNote,
    };
    return await _apiClient.post(ApiEndpoints.interactionsCollection, body: body);
  }

  Future<dynamic> deleteInteraction(String interactionId) async {
    return await _apiClient.delete(ApiEndpoints.interactionDetails(interactionId));
  }

  Future<dynamic> bookmarkPost(String postId) async {
    return await _apiClient.post(ApiEndpoints.postBookmark(postId));
  }

  Future<dynamic> removeBookmark(String postId) async {
    return await _apiClient.delete(ApiEndpoints.postBookmark(postId));
  }

  Future<dynamic> getMyBookmarks() async {
    return await _apiClient.get(ApiEndpoints.myBookmarks);
  }

  // ==========================================
  // 6b. CineReels (Vertical Showreels)
  // ==========================================
  Future<dynamic> getReels({int page = 1, int limit = 20}) async {
    final skip = (page - 1) * limit;
    return await _apiClient.get(ApiEndpoints.reelsCollection, queryParams: {'skip': skip, 'limit': limit});
  }

  Future<dynamic> createReel({
    required String title,
    required String mediaUrl,
    String? caption,
    String? thumbnailUrl,
    String? audioTrack,
    String? smpteTimecode,
    String? craftSpecialty,
    String? reelType,
  }) async {
    final body = {
      'title': title,
      'media_url': mediaUrl,
      if (caption != null) 'caption': caption,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (audioTrack != null) 'audio_track': audioTrack,
      if (smpteTimecode != null) 'smpte_timecode': smpteTimecode,
      if (craftSpecialty != null) 'craft_specialty': craftSpecialty,
      if (reelType != null) 'reel_type': reelType,
    };
    return await _apiClient.post(ApiEndpoints.reelsCollection, body: body);
  }

  Future<dynamic> deleteReel(String reelId) async {
    return await _apiClient.delete(ApiEndpoints.reelDetails(reelId));
  }

  Future<dynamic> getReelPlaybackUrl(String reelId) async {
    return await _apiClient.get(ApiEndpoints.reelPlaybackUrl(reelId));
  }

  // ==========================================
  // 6c. On-Set Stories (24h Ephemeral Stories)
  // ==========================================
  Future<dynamic> getStories() async {
    return await _apiClient.get(ApiEndpoints.storiesCollection);
  }

  Future<dynamic> createStory({
    required String mediaUrl,
    String? caption,
    String? location,
    String? craftBadge,
  }) async {
    final body = {
      'media_url': mediaUrl,
      if (caption != null) 'caption': caption,
      if (location != null) 'location': location,
      if (craftBadge != null) 'craft_badge': craftBadge,
    };
    return await _apiClient.post(ApiEndpoints.storiesCollection, body: body);
  }

  Future<dynamic> deleteStory(String storyId) async {
    return await _apiClient.delete(ApiEndpoints.storyDetails(storyId));
  }

  Future<dynamic> getStoryPlaybackUrl(String storyId) async {
    return await _apiClient.get(ApiEndpoints.storyPlaybackUrl(storyId));
  }

  /// Streams public media (such as on-set stories or post media) directly to MinIO storage.
  Future<MediaUploadResult> uploadPublicXFile({
    required XFile file,
    required String contentType,
  }) async {
    return await _mediaUploadService.uploadXFile(
      file: file,
      contentType: contentType,
      purpose: 'public',
    );
  }

  // ==========================================
  // 6d. Unified Global Search
  // ==========================================
  Future<dynamic> searchGlobal(String query) async {
    return await _apiClient.get(ApiEndpoints.globalSearch, queryParams: {'q': query});
  }

  // ==========================================
  // 7. 24-Crafts Peer Connections & Radar
  // ==========================================
  Future<dynamic> getMyConnections({String? status}) async {
    final params = status != null ? {'status': status} : null;
    return await _apiClient.get(ApiEndpoints.myConnections, queryParams: params);
  }

  Future<dynamic> getConnectionRequests() async {
    return await _apiClient.get(ApiEndpoints.connectionRequests);
  }

  Future<dynamic> sendConnectionRequest(String targetUserId) async {
    return await _apiClient.post(ApiEndpoints.sendConnection, body: {'receiver_id': targetUserId});
  }

  Future<dynamic> acceptConnectionRequest(String connectionId) async {
    return await _apiClient.patch(ApiEndpoints.acceptConnection(connectionId));
  }

  Future<dynamic> rejectConnectionRequest(String connectionId) async {
    return await _apiClient.patch(ApiEndpoints.rejectConnection(connectionId));
  }

  Future<dynamic> removeConnection(String connectionId) async {
    return await _apiClient.delete(ApiEndpoints.removeConnection(connectionId));
  }

  Future<dynamic> toggleFollow(String userId) async {
    return await _apiClient.post(ApiEndpoints.toggleFollow(userId));
  }

  Future<dynamic> getUserFollowers(String userId) async {
    return await _apiClient.get(ApiEndpoints.userFollowers(userId));
  }

  Future<dynamic> getUserFollowing(String userId) async {
    return await _apiClient.get(ApiEndpoints.userFollowing(userId));
  }

  Future<dynamic> getFollowStatus(String userId) async {
    return await _apiClient.get(ApiEndpoints.followStatus(userId));
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
      'body': content,
    };
    return await _apiClient.post(ApiEndpoints.sendMessage, body: body);
  }

  Future<dynamic> getNotifications({int page = 1, int limit = 20, bool? isRead}) async {
    final skip = (page - 1) * limit;
    final params = <String, dynamic>{'skip': skip, 'limit': limit};
    if (isRead != null) params['is_read'] = isRead;
    return await _apiClient.get(ApiEndpoints.notifications, queryParams: params);
  }

  Future<dynamic> getUnreadNotificationCount() async {
    return await _apiClient.get(ApiEndpoints.unreadNotificationCount);
  }

  Future<dynamic> markNotificationRead(String notificationId) async {
    return await _apiClient.patch(ApiEndpoints.markNotificationRead(notificationId));
  }

  Future<dynamic> markAllNotificationsRead() async {
    return await _apiClient.patch(ApiEndpoints.markAllNotificationsRead);
  }

  // ==========================================
  // 10. Presigned Media Upload & Dashboard
  // ==========================================
  Future<dynamic> requestPresignedUploadUrl({
    required String filename,
    required String contentType,
    int? fileSizeBytes,
    String purpose = 'public',
  }) async {
    final body = {
      'file_name': filename,
      'content_type': contentType,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      'purpose': purpose,
    };
    return await _apiClient.post(ApiEndpoints.mediaUploadUrl, body: body);
  }

  Future<dynamic> getTalentDashboard() async {
    return await _apiClient.get(ApiEndpoints.talentDashboard);
  }
}
