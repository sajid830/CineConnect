import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/craft_models.dart';
import '../network/api_client.dart';
import '../services/chat_service.dart';
import '../services/talent_api_service.dart';
import '../../features/production_house/data/models/portfolio_item.dart';
import '../../features/production_house/data/models/project.dart';

class CineAppState extends ChangeNotifier {
  final TalentApiService _apiService;

  int _activeNavIndex = 0; // 0: Home/Feed, 1: Discover/Reels, 2: Opportunities/Jobs, 3: Network/Radar, 4: Slate/Profile
  OnSetStory? _activeViewedStory;
  String _activeHubFilter = 'Pan-India';
  bool _isBackendConnected = false;

  TalentApiService get apiService => _apiService;
  bool get isBackendConnected => _isBackendConnected;

  // Current logged in talent user's active skills
  final Set<String> _userSkills = {
    'ARRI Alexa 35',
    'Cooke Anamorphic /i',
    'Unreal Engine 5 ICVFX',
    'DaVinci Resolve Studio',
    'Ronin 4D 8K',
    'SMPTE Timecode Sync',
    'Steadicam M-2',
    'Low-Key Film Noir Lighting',
  };

  int get activeNavIndex => _activeNavIndex;
  OnSetStory? get activeViewedStory => _activeViewedStory;
  String get activeHubFilter => _activeHubFilter;
  Set<String> get userSkills => Set.unmodifiable(_userSkills);

  bool _isLoadingOpportunities = false;
  String? _opportunitiesError;
  bool _isUsingFallbackOpportunities = false;
  bool _hasApplicationsLookupFailed = false;

  bool get isLoadingOpportunities => _isLoadingOpportunities;
  String? get opportunitiesError => _opportunitiesError;
  bool get isUsingFallbackOpportunities => _isUsingFallbackOpportunities;
  bool get hasApplicationsLookupFailed => _hasApplicationsLookupFailed;

  TalentProfile? myProfile;
  bool _isLoadingProfile = false;
  bool get isLoadingProfile => _isLoadingProfile;

  List<VerifiedFilmCredit> myFilmography = [];
  bool _isLoadingFilmography = false;
  bool get isLoadingFilmography => _isLoadingFilmography;

  bool _isLoadingFeed = false;
  bool get isLoadingFeed => _isLoadingFeed;
  int _feedPage = 1;
  bool _hasMoreFeed = true;
  bool _isLoadingMoreFeed = false;
  String? _feedPaginationError;
  bool get hasMoreFeed => _hasMoreFeed;
  bool get isLoadingMoreFeed => _isLoadingMoreFeed;
  String? get feedPaginationError => _feedPaginationError;

  final Map<String, String> _postLikeInteractionIds = {};

  bool _isLoadingReels = false;
  bool get isLoadingReels => _isLoadingReels;
  int _reelsPage = 1;
  bool _hasMoreReels = true;
  bool _isLoadingMoreReels = false;
  bool get hasMoreReels => _hasMoreReels;
  bool get isLoadingMoreReels => _isLoadingMoreReels;

  bool _isLoadingStories = false;
  bool get isLoadingStories => _isLoadingStories;

  bool _isLoadingConnections = false;
  bool get isLoadingConnections => _isLoadingConnections;
  String? _connectionsError;
  String? get connectionsError => _connectionsError;

  List<CineConnection> incomingRequests = [];
  bool _isLoadingRequests = false;
  String? _requestsError;
  bool get isLoadingRequests => _isLoadingRequests;
  String? get requestsError => _requestsError;

  Map<String, String> peerConnectionIds = {};
  Map<String, ConnectionStatus> peerConnectionStatuses = {};

  List<PortfolioItem> myPortfolio = [];
  bool _isLoadingPortfolio = false;
  String? _portfolioError;
  bool get isLoadingPortfolio => _isLoadingPortfolio;
  String? get portfolioError => _portfolioError;

  CineAppState({TalentApiService? apiService, bool autoCheckConnectivity = true})
      : _apiService = apiService ?? TalentApiService() {
    myProfile = _buildFallbackTalentProfile();
    if (autoCheckConnectivity) {
      _initConnectivityCheck();
      loadOpportunities();
      loadNotifications();
      loadMyProfile();
      loadMyPortfolio();
      loadFeedPosts();
      loadReels();
      loadStories();
      loadConnections();
      loadConnectionRequests();
      _startPeriodicSync();
    }
  }

  Timer? _backgroundSyncTimer;

  void _startPeriodicSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      // Lightweight periodic background sync for notifications & chat badges
      if (ApiClient.currentUserId != null) {
        try {
          final unreadRes = await _apiService.getUnreadNotificationCount();
          if (unreadRes is Map<String, dynamic> && unreadRes['unread_count'] is num) {
            final newCount = (unreadRes['unread_count'] as num).toInt();
            if (_serverUnreadCount != newCount) {
              _serverUnreadCount = newCount;
              await loadNotifications(forceRefresh: true);
            }
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _initConnectivityCheck() async {
    _isBackendConnected = await _apiService.checkBackendHealth();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        super.notifyListeners();
      });
    } else {
      super.notifyListeners();
    }
  }

  // ==========================================
  // Real Profile Integration
  // ==========================================
  Future<void> loadMyProfile({bool refresh = false}) async {
    _isLoadingProfile = true;
    notifyListeners();
    try {
      final res = await _apiService.getMyProfile();
      if (res is Map<String, dynamic>) {
        myProfile = TalentProfile.fromJson(res);
        if (myProfile != null) {
          if (myProfile!.skillTags.isNotEmpty) {
            _userSkills.addAll(myProfile!.skillTags);
          }
          if (myProfile!.filmography.isNotEmpty) {
            myFilmography = List<VerifiedFilmCredit>.from(myProfile!.filmography);
          }
        }
      }
    } catch (_) {
      // Keep existing profile or offline fallback
    } finally {
      if (myProfile == null) {
        myProfile = _buildFallbackTalentProfile();
        if (myProfile != null) {
          if (myProfile!.skillTags.isNotEmpty) {
            _userSkills.addAll(myProfile!.skillTags);
          }
          if (myProfile!.filmography.isNotEmpty) {
            myFilmography = List<VerifiedFilmCredit>.from(myProfile!.filmography);
          }
        }
      }
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  TalentProfile _buildFallbackTalentProfile() {
    String fullName = 'Cinema Talent';
    String handle = '@talent';
    String headline = 'Film & Television';
    String primaryCraft = 'Film Professional';
    String avatar = 'CT';
    String hubLocation = '';
    String dailyCallSheetRate = '';
    String immediateAvailability = '';
    String id = '';

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        id = user.id;
        final metadata = user.userMetadata;
        final rawName = metadata?['full_name']?.toString() ??
            metadata?['name']?.toString() ??
            user.email?.split('@').first ??
            'Cinema Talent';
        if (rawName.trim().isNotEmpty) {
          fullName = rawName.trim();
        }
        final rawHandle = metadata?['handle']?.toString() ??
            metadata?['username']?.toString() ??
            '@${fullName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}';
        if (rawHandle.trim().isNotEmpty) {
          handle = rawHandle.startsWith('@') ? rawHandle : '@$rawHandle';
        }
        final rawCraft = metadata?['role']?.toString() ??
            metadata?['craft']?.toString() ??
            'Film Professional';
        if (rawCraft.trim().isNotEmpty && rawCraft.toLowerCase() != 'talent') {
          primaryCraft = rawCraft;
          headline = '$primaryCraft | Film & Television';
        }
        final parts = fullName.split(RegExp(r'\s+'));
        if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
          avatar = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
        } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
          avatar = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
        }
      }
    } catch (_) {}

    return TalentProfile(
      id: id,
      fullName: fullName,
      handle: handle,
      headline: headline,
      avatarUrl: avatar,
      primaryCraft: primaryCraft,
      secondaryCrafts: const [],
      guildId: '',
      isGuildVerified: false,
      hubLocation: hubLocation,
      dailyCallSheetRate: dailyCallSheetRate,
      immediateAvailability: immediateAvailability,
      verifiedGear: const [],
      skillTags: const [],
      filmography: const [],
      connectionsCount: 0,
      endorsementsCount: 0,
      isConnected: false,
    );
  }

  Future<void> loadMyFilmography() async {
    _isLoadingFilmography = true;
    notifyListeners();
    try {
      final res = await _apiService.getMyFilmography();
      myFilmography = res
          .whereType<Map<String, dynamic>>()
          .map(VerifiedFilmCredit.fromJson)
          .toList();
      if (myProfile != null) {
        myProfile = myProfile!.copyWith(filmography: List<VerifiedFilmCredit>.from(myFilmography));
      }
    } catch (_) {
      // Keep existing
    } finally {
      _isLoadingFilmography = false;
      notifyListeners();
    }
  }

  Future<VerifiedFilmCredit> addFilmCredit(Map<String, dynamic> data) async {
    final res = await _apiService.addFilmCredit(data);
    final credit = VerifiedFilmCredit.fromJson(res as Map<String, dynamic>);
    myFilmography.insert(0, credit);
    if (myProfile != null) {
      myProfile = myProfile!.copyWith(filmography: List<VerifiedFilmCredit>.from(myFilmography));
    }
    notifyListeners();
    return credit;
  }

  Future<VerifiedFilmCredit> updateFilmCredit(String creditId, Map<String, dynamic> data) async {
    final res = await _apiService.updateFilmCredit(creditId, data);
    final updated = VerifiedFilmCredit.fromJson(res as Map<String, dynamic>);
    final idx = myFilmography.indexWhere((c) => c.id == creditId);
    if (idx != -1) {
      myFilmography[idx] = updated;
    }
    if (myProfile != null) {
      myProfile = myProfile!.copyWith(filmography: List<VerifiedFilmCredit>.from(myFilmography));
    }
    notifyListeners();
    return updated;
  }

  Future<void> deleteFilmCredit(String creditId) async {
    await _apiService.deleteFilmCredit(creditId);
    myFilmography.removeWhere((c) => c.id == creditId);
    if (myProfile != null) {
      myProfile = myProfile!.copyWith(filmography: List<VerifiedFilmCredit>.from(myFilmography));
    }
    notifyListeners();
  }

  Future<void> updateMyProfile(Map<String, dynamic> data) async {
    try {
      await _apiService.updateProfile(data);
      await loadMyProfile(refresh: true);
    } catch (_) {
      rethrow;
    }
  }

  void clearUserData() {
    myProfile = null;
    myFilmography.clear();
    myPortfolio.clear();
    reels.clear();
    stories.clear();
    feedPosts.clear();
    incomingRequests.clear();
    peerConnectionIds.clear();
    peerConnectionStatuses.clear();
    notifications.clear();
    _userSkills.clear();
    _apiService.clearAuthToken();
    notifyListeners();
  }

  // ==========================================
  // Real Social Feed Posts Integration
  // ==========================================
  Future<void> loadFeedPosts({bool refresh = false}) async {
    if (refresh) {
      _feedPage = 1;
      _hasMoreFeed = true;
      _feedPaginationError = null;
    }
    _isLoadingFeed = true;
    notifyListeners();
    try {
      final res = await _apiService.getFeedPosts(page: 1, limit: 20);
      if (res is List) {
        final fetched = res
            .whereType<Map<String, dynamic>>()
            .map(CineFeedPost.fromJson)
            .toList();
        feedPosts = fetched;
        for (final p in fetched) {
          if (p.likeInteractionId != null && p.likeInteractionId!.isNotEmpty) {
            _postLikeInteractionIds[p.id] = p.likeInteractionId!;
          }
        }
        _hasMoreFeed = fetched.length >= 20;
        _feedPage = 1;
        _feedPaginationError = null;
      }
    } catch (_) {
      // Keep existing posts on error
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreFeedPosts() async {
    if (!_hasMoreFeed || _isLoadingMoreFeed || _isLoadingFeed) return;
    _isLoadingMoreFeed = true;
    _feedPaginationError = null;
    notifyListeners();
    try {
      final nextPage = _feedPage + 1;
      final res = await _apiService.getFeedPosts(page: nextPage, limit: 20);
      if (res is List) {
        final fetched = res
            .whereType<Map<String, dynamic>>()
            .map(CineFeedPost.fromJson)
            .toList();
        if (fetched.isNotEmpty) {
          final existingIds = feedPosts.map((p) => p.id).toSet();
          final newItems = fetched.where((p) => !existingIds.contains(p.id)).toList();
          feedPosts.addAll(newItems);
          for (final p in newItems) {
            if (p.likeInteractionId != null && p.likeInteractionId!.isNotEmpty) {
              _postLikeInteractionIds[p.id] = p.likeInteractionId!;
            }
          }
          _feedPage = nextPage;
        }
        _hasMoreFeed = fetched.length >= 20;
        _feedPaginationError = null;
      }
    } catch (_) {
      _feedPaginationError = 'Could not load older posts. Tap to retry.';
    } finally {
      _isLoadingMoreFeed = false;
      notifyListeners();
    }
  }

  // ==========================================
  // Real CineReels Integration
  // ==========================================
  Future<void> loadReels({bool refresh = false}) async {
    if (refresh) {
      _reelsPage = 1;
      _hasMoreReels = true;
    }
    _isLoadingReels = true;
    notifyListeners();
    try {
      final res = await _apiService.getReels(page: 1, limit: 20);
      if (res is List) {
        final fetched = res
            .whereType<Map<String, dynamic>>()
            .map(CineReelItem.fromJson)
            .toList();
        if (fetched.isNotEmpty) {
          reels = fetched;
        }
        _hasMoreReels = fetched.length >= 20;
        _reelsPage = 1;
      }
    } catch (_) {
      // Keep existing reels on error
    } finally {
      _isLoadingReels = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreReels() async {
    if (!_hasMoreReels || _isLoadingMoreReels || _isLoadingReels) return;
    _isLoadingMoreReels = true;
    notifyListeners();
    try {
      final nextPage = _reelsPage + 1;
      final res = await _apiService.getReels(page: nextPage, limit: 20);
      if (res is List) {
        final fetched = res
            .whereType<Map<String, dynamic>>()
            .map(CineReelItem.fromJson)
            .toList();
        if (fetched.isNotEmpty) {
          final existingIds = reels.map((r) => r.id).toSet();
          final newItems = fetched.where((r) => !existingIds.contains(r.id)).toList();
          reels.addAll(newItems);
          _reelsPage = nextPage;
        }
        _hasMoreReels = fetched.length >= 20;
      }
    } catch (_) {
      // Keep existing items on failure
    } finally {
      _isLoadingMoreReels = false;
      notifyListeners();
    }
  }

  // ==========================================
  // Real On-Set Stories Integration
  // ==========================================
  Future<void> loadStories({bool refresh = false}) async {
    _isLoadingStories = true;
    notifyListeners();
    try {
      final res = await _apiService.getStories();
      if (res is List) {
        final fetched = res
            .whereType<Map<String, dynamic>>()
            .map(OnSetStory.fromJson)
            .toList();

        final myUserId = myProfile?.id;
        final myStoryIndex = fetched.indexWhere((s) => myUserId != null && s.userId == myUserId);

        OnSetStory yourStory;
        if (myStoryIndex != -1) {
          yourStory = fetched.removeAt(myStoryIndex).copyWith(
            creatorName: 'Your Story',
            initials: (myProfile != null && myProfile!.avatarUrl.length <= 3) ? myProfile!.avatarUrl : 'YOU',
          );
        } else {
          yourStory = OnSetStory(
            id: 'your-story-placeholder',
            userId: myUserId,
            creatorName: 'Your Story',
            initials: (myProfile != null && myProfile!.avatarUrl.length <= 3) ? myProfile!.avatarUrl : 'YOU',
            craftBadge: myProfile?.primaryCraft ?? 'My Slate',
            location: myProfile?.hubLocation ?? 'Stage 4 - Annapurna Studios',
            storyCaption: 'Tap to publish an on-set story',
            timeAgo: 'Add Story',
            hasUnseen: false,
          );
        }

        stories.clear();
        stories.add(yourStory);
        stories.addAll(fetched);
      }
    } catch (_) {
      // Keep existing stories on error
    } finally {
      _isLoadingStories = false;
      notifyListeners();
    }
  }

  Future<void> publishStory({
    required String mediaUrl,
    String? caption,
    String? location,
    String? craftBadge,
  }) async {
    try {
      await _apiService.createStory(
        mediaUrl: mediaUrl,
        caption: caption,
        location: location,
        craftBadge: craftBadge,
      );
      await loadStories(refresh: true);
    } catch (_) {
      rethrow;
    }
  }

  Future<void> deleteStory(String storyId) async {
    try {
      await _apiService.deleteStory(storyId);
      stories.removeWhere((s) => s.id == storyId);
      if (_activeViewedStory?.id == storyId) {
        _activeViewedStory = null;
      }
      notifyListeners();
      await loadStories(refresh: true);
    } catch (_) {
      rethrow;
    }
  }

  Future<String?> getStoryPlaybackUrl(String storyId) async {
    try {
      final res = await _apiService.getStoryPlaybackUrl(storyId);
      if (res is Map<String, dynamic> && res['playback_url'] != null) {
        final playbackUrl = res['playback_url'].toString();
        final idx = stories.indexWhere((s) => s.id == storyId);
        if (idx != -1) {
          stories[idx] = stories[idx].copyWith(playbackUrl: playbackUrl);
          notifyListeners();
        }
        return playbackUrl;
      }
    } catch (_) {}
    return null;
  }

  // ==========================================
  // Real Connections & Radar Integration
  // ==========================================
  Future<void> loadConnections({bool refresh = false}) async {
    _isLoadingConnections = true;
    _connectionsError = null;
    notifyListeners();
    try {
      final peersRes = await _apiService.listPeers(limit: 50);
      final allConnRes = await _apiService.getMyConnections(status: 'all');
      final reqsRes = await _apiService.getConnectionRequests();

      final Map<String, String> connIdByPeerId = {};
      final Map<String, ConnectionStatus> statusByPeerId = {};
      final myUserId = myProfile?.id;

      if (allConnRes is List) {
        for (final item in allConnRes) {
          if (item is Map<String, dynamic>) {
            final connId = item['id']?.toString();
            final sId = item['sender_id']?.toString();
            final rId = item['receiver_id']?.toString();
            final statusStr = item['status']?.toString();
            if (connId == null) continue;

            final otherUserId = (myUserId != null && sId == myUserId) ? rId : sId;
            if (otherUserId != null) {
              connIdByPeerId[otherUserId] = connId;
              if (statusStr == 'accepted') {
                statusByPeerId[otherUserId] = ConnectionStatus.connected;
              } else if (statusStr == 'pending') {
                if (myUserId != null && sId == myUserId) {
                  statusByPeerId[otherUserId] = ConnectionStatus.pendingSent;
                } else {
                  statusByPeerId[otherUserId] = ConnectionStatus.pendingReceived;
                }
              } else if (statusStr == 'rejected') {
                statusByPeerId[otherUserId] = ConnectionStatus.rejected;
              }
            }
          }
        }
      }

      if (reqsRes is List) {
        incomingRequests = reqsRes
            .whereType<Map<String, dynamic>>()
            .map(CineConnection.fromJson)
            .toList();
        for (final req in incomingRequests) {
          connIdByPeerId[req.senderId] = req.id;
          statusByPeerId[req.senderId] = ConnectionStatus.pendingReceived;
        }
      }

      peerConnectionIds = connIdByPeerId;
      peerConnectionStatuses = statusByPeerId;

      if (peersRes is List && peersRes.isNotEmpty) {
        final List<TalentProfile> network = [];
        for (final item in peersRes.whereType<Map<String, dynamic>>()) {
          final p = TalentProfile.fromJson(item);
          if (myProfile != null && p.id == myProfile!.id) continue;
          final cStatus = statusByPeerId[p.id] ?? ConnectionStatus.none;
          final isConn = cStatus == ConnectionStatus.connected;
          final cId = connIdByPeerId[p.id];
          network.add(p.copyWith(
            isConnected: isConn,
            connectionId: cId,
            connectionStatus: cStatus,
          ));
        }
        if (network.isNotEmpty) {
          talentNetwork = network;
        }
      }
    } catch (e) {
      _connectionsError = e.toString();
    } finally {
      _isLoadingConnections = false;
      notifyListeners();
    }
  }

  Future<void> loadConnectionRequests({bool refresh = false}) async {
    _isLoadingRequests = true;
    _requestsError = null;
    notifyListeners();
    try {
      final reqsRes = await _apiService.getConnectionRequests();
      if (reqsRes is List) {
        incomingRequests = reqsRes
            .whereType<Map<String, dynamic>>()
            .map(CineConnection.fromJson)
            .toList();
        for (final req in incomingRequests) {
          peerConnectionIds[req.senderId] = req.id;
          peerConnectionStatuses[req.senderId] = ConnectionStatus.pendingReceived;
          final idx = talentNetwork.indexWhere((t) => t.id == req.senderId);
          if (idx != -1) {
            talentNetwork[idx] = talentNetwork[idx].copyWith(
              connectionId: req.id,
              connectionStatus: ConnectionStatus.pendingReceived,
            );
          }
        }
      }
    } catch (e) {
      _requestsError = e.toString();
    } finally {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  /// Fetches real opportunities from FastAPI and PostgreSQL.
  /// Falls back to verified offline sample data if the backend is unreachable or offline.
  Future<void> loadOpportunities({String? craft, String? hub, int page = 1, bool forceRefresh = false}) async {
    _isLoadingOpportunities = true;
    _opportunitiesError = null;
    notifyListeners();

    try {
      final res = await _apiService.getOpportunities(craft: craft, hub: hub, page: page);

      // Correlation: correlate user's applied status from getMyApplications
      final Set<String> appliedIds = {};
      final Map<String, ApplicationStatus> appStatuses = {};
      bool appsLookupSucceeded = false;
      try {
        final appsRes = await _apiService.getMyApplications();
        if (appsRes is List) {
          appsLookupSucceeded = true;
          for (final app in appsRes) {
            if (app is Map<String, dynamic>) {
              final oppId = app['opportunity_id']?.toString();
              if (oppId != null && oppId.isNotEmpty) {
                appliedIds.add(oppId);
                appStatuses[oppId] = ProductionJobBrief.parseStatus(app['status']?.toString());
              }
            }
          }
        }
      } catch (_) {
        appsLookupSucceeded = false;
      }
      _hasApplicationsLookupFailed = !appsLookupSucceeded;

      // Index existing local applications in case lookup failed so we don't wipe out applied state
      final Map<String, ProductionJobBrief> existingJobsById = {
        for (final j in jobBriefs) j.id: j,
      };

      List<dynamic>? rawList;
      if (res is List) {
        rawList = res;
      } else if (res is Map<String, dynamic> && res['items'] is List) {
        rawList = res['items'] as List;
      }

      if (rawList != null && rawList.isNotEmpty) {
        final parsed = rawList
            .whereType<Map<String, dynamic>>()
            .map((item) {
              final oppId = item['id']?.toString() ?? '';
              final existingJob = existingJobsById[oppId];

              bool hasApplied;
              ApplicationStatus? status;

              if (appsLookupSucceeded) {
                hasApplied = appliedIds.contains(oppId);
                status = appStatuses[oppId];
              } else {
                // If lookup failed, do not falsely confirm user has not applied:
                // Preserve existing local applied state if known, otherwise false
                hasApplied = existingJob?.hasUserApplied ?? false;
                status = existingJob?.applicationStatus;
              }

              return ProductionJobBrief.fromJson(
                item,
                hasUserApplied: hasApplied,
                applicationStatus: status,
              );
            })
            .toList();

        jobBriefs = parsed;
        _isUsingFallbackOpportunities = false;
        _opportunitiesError = null;
      } else if (rawList != null && rawList.isEmpty) {
        // Real empty response from backend (no opportunities posted yet)
        jobBriefs = [];
        _isUsingFallbackOpportunities = false;
        _opportunitiesError = null;
      } else {
        jobBriefs = [];
        _isUsingFallbackOpportunities = false;
      }
    } catch (e) {
      _opportunitiesError = e.toString();
      jobBriefs = [];
      _isUsingFallbackOpportunities = false;
    } finally {
      _isLoadingOpportunities = false;
      notifyListeners();
    }
  }

  /// Fetches public production house projects from FastAPI and PostgreSQL.
  Future<void> loadPublicProjects({bool forceRefresh = false}) async {
    _isLoadingProjects = true;
    _projectsError = null;
    notifyListeners();

    try {
      final res = await _apiService.getPublicProjects();

      // Check applied projects from user's applications
      final Set<String> appliedProjectIds = {};
      final Map<String, String> projectAppStatuses = {};
      try {
        final appsRes = await _apiService.getMyApplications();
        if (appsRes is List) {
          for (final app in appsRes) {
            if (app is Map<String, dynamic>) {
              final projId = app['project_id']?.toString();
              if (projId != null && projId.isNotEmpty) {
                appliedProjectIds.add(projId);
                projectAppStatuses[projId] = app['status']?.toString() ?? 'submitted';
              }
            }
          }
        }
      } catch (_) {}

      List<dynamic>? rawList;
      if (res is List) {
        rawList = res;
      } else if (res is Map<String, dynamic> && res['items'] is List) {
        rawList = res['items'] as List;
      }

      if (rawList != null) {
        publicProjects = rawList.whereType<Map<String, dynamic>>().map((item) {
          final pId = item['id']?.toString() ?? '';
          final hasApplied = appliedProjectIds.contains(pId);
          final status = projectAppStatuses[pId];
          return Project.fromJson(item, hasUserApplied: hasApplied, applicationStatus: status);
        }).toList();
        _projectsError = null;
      } else {
        publicProjects = [];
      }
    } catch (e) {
      _projectsError = e.toString();
      publicProjects = [];
    } finally {
      _isLoadingProjects = false;
      notifyListeners();
    }
  }

  void setActiveNavIndex(int index) {
    _activeNavIndex = index;
    notifyListeners();
  }

  void setHubFilter(String hub) {
    _activeHubFilter = hub;
    notifyListeners();
  }

  void openStory(OnSetStory story) {
    _activeViewedStory = story;
    notifyListeners();
  }

  void closeStory() {
    _activeViewedStory = null;
    notifyListeners();
  }

  void toggleSkill(String skill) {
    if (_userSkills.contains(skill)) {
      _userSkills.remove(skill);
    } else {
      _userSkills.add(skill);
    }
    notifyListeners();
  }

  // --- Stories ---
  final List<OnSetStory> stories = [];

  // --- Posts ---
  late List<CineFeedPost> feedPosts = [];

  // --- Opportunities ---
  late List<ProductionJobBrief> jobBriefs = [];

  // --- Public Projects ---
  List<Project> publicProjects = [];
  bool _isLoadingProjects = false;
  bool get isLoadingProjects => _isLoadingProjects;
  String? _projectsError;
  String? get projectsError => _projectsError;

  // --- Reels ---
  late List<CineReelItem> reels = [];

  // --- Peer Network ---
  late List<TalentProfile> talentNetwork = [];

  // --- Notifications & Chat State ---
  bool _isLoadingNotifications = false;
  bool get isLoadingNotifications => _isLoadingNotifications;
  String? _notificationsError;
  String? get notificationsError => _notificationsError;
  int? _serverUnreadCount;

  int get unreadNotificationsCount {
    if (_serverUnreadCount != null) {
      return _serverUnreadCount!;
    }
    return notifications.where((n) => !n.isRead).length;
  }

  int get unreadChatCount => chatThreads.fold(0, (acc, thread) => acc + thread.unreadCount);

  late List<CineNotification> notifications = [];

  late List<CineChatThread> chatThreads = [];

  /// Fetches real user notifications and live unread count from FastAPI.
  Future<void> loadNotifications({bool forceRefresh = false}) async {
    if (_isLoadingNotifications) return;
    _isLoadingNotifications = true;
    _notificationsError = null;
    notifyListeners();

    try {
      final res = await _apiService.getNotifications(limit: 50);
      List<dynamic>? rawList;
      if (res is List) {
        rawList = res;
      } else if (res is Map<String, dynamic> && res['items'] is List) {
        rawList = res['items'] as List;
      }

      if (rawList != null) {
        final Map<String, CineNotification> deduplicated = {};
        for (final item in rawList.whereType<Map<String, dynamic>>()) {
          final notif = CineNotification.fromJson(item);
          if (notif.id.isNotEmpty) {
            deduplicated[notif.id] = notif;
          }
        }
        notifications = deduplicated.values.toList();
        _notificationsError = null;
      }

      // Live unread count
      try {
        final unreadRes = await _apiService.getUnreadNotificationCount();
        if (unreadRes is Map<String, dynamic> && unreadRes['unread_count'] is num) {
          _serverUnreadCount = (unreadRes['unread_count'] as num).toInt();
        } else {
          _serverUnreadCount = notifications.where((n) => !n.isRead).length;
        }
      } catch (_) {
        _serverUnreadCount = notifications.where((n) => !n.isRead).length;
      }
    } catch (e) {
      _notificationsError = e.toString();
    } finally {
      _isLoadingNotifications = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationsAsRead() async {
    if (notifications.every((n) => n.isRead)) return;
    final previous = List.of(notifications);
    final prevCount = _serverUnreadCount;

    // Optimistic update
    notifications = notifications.map((n) => n.copyWith(isRead: true)).toList();
    _serverUnreadCount = 0;
    notifyListeners();

    try {
      await _apiService.markAllNotificationsRead();
    } catch (e) {
      // Revert on failure
      notifications = previous;
      _serverUnreadCount = prevCount;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index == -1 || notifications[index].isRead) return;

    final previous = notifications[index];
    final prevCount = _serverUnreadCount;

    // Optimistic update
    notifications[index] = previous.copyWith(isRead: true);
    if (_serverUnreadCount != null && _serverUnreadCount! > 0) {
      _serverUnreadCount = _serverUnreadCount! - 1;
    }
    notifyListeners();

    try {
      await _apiService.markNotificationRead(id);
    } catch (e) {
      // Revert on failure
      final idx = notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        notifications[idx] = previous;
        _serverUnreadCount = prevCount;
        notifyListeners();
      }
      rethrow;
    }
  }

  final Set<String> acceptedCollabIds = {};
  final Set<String> declinedCollabIds = {};

  Future<void> loadMyCollaborations() async {
    try {
      final res = await _apiService.getMyCollaborations();
      if (res is List) {
        for (final item in res) {
          if (item is Map) {
            final id = item['id']?.toString();
            final status = item['status']?.toString().toLowerCase();
            if (id != null && id.isNotEmpty) {
              if (status == 'accepted') {
                acceptedCollabIds.add(id);
                declinedCollabIds.remove(id);
              } else if (status == 'rejected' || status == 'declined') {
                declinedCollabIds.add(id);
                acceptedCollabIds.remove(id);
              }
            }
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> acceptCollaboration(String collabId) async {
    // Instant optimistic update (0ms latency for UI)
    acceptedCollabIds.add(collabId);
    declinedCollabIds.remove(collabId);
    notifyListeners();

    try {
      await _apiService.acceptCollaboration(collabId);
      // Run background refreshes without blocking UI
      unawaited(Future.wait([
        loadNotifications(forceRefresh: true),
        loadConversations(),
      ]));
    } catch (e) {
      if (!e.toString().contains('accepted') && !e.toString().contains('already')) {
        // Revert on actual failure
        acceptedCollabIds.remove(collabId);
        notifyListeners();
        rethrow;
      }
    }
  }

  Future<void> rejectCollaboration(String collabId) async {
    // Instant optimistic update (0ms latency for UI)
    declinedCollabIds.add(collabId);
    acceptedCollabIds.remove(collabId);
    notifyListeners();

    try {
      await _apiService.rejectCollaboration(collabId);
      unawaited(loadNotifications(forceRefresh: true));
    } catch (e) {
      if (!e.toString().contains('rejected') && !e.toString().contains('declined')) {
        // Revert on actual failure
        declinedCollabIds.remove(collabId);
        notifyListeners();
        rethrow;
      }
    }
  }

  StreamSubscription? _chatWsSubscription;
  StreamSubscription? _chatConnSubscription;
  String? _activeChatThreadId;

  String? get activeChatThreadId => _activeChatThreadId;

  /// Initializes real-time WebSocket connection and registers message listeners.
  void initChatService() {
    _apiService.chatService.connectWebSocket();

    _chatWsSubscription?.cancel();
    _chatWsSubscription = _apiService.chatService.incomingMessagesStream.listen(_handleIncomingWsMessage);

    _chatConnSubscription?.cancel();
    _chatConnSubscription = _apiService.chatService.connectionStateStream.listen((state) {
      if (state == ChatConnectionState.connected) {
        // Recover conversations and active thread messages missed while disconnected
        loadConversations();
        if (_activeChatThreadId != null) {
          loadThreadMessages(_activeChatThreadId!);
        }
      }
    });

    loadConversations();
  }

  void clearActiveThread() {
    _activeChatThreadId = null;
  }

  String _formatMessageTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 1) {
      return '${dt.day}/${dt.month}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      final hours = dt.hour.toString().padLeft(2, '0');
      final minutes = dt.minute.toString().padLeft(2, '0');
      return '$hours:$minutes';
    }
  }

  /// Fetches real conversation summaries from FastAPI (`GET /api/v1/messages/conversations`).
  Future<void> loadConversations() async {
    try {
      final list = await _apiService.chatService.getConversations();
      if (list.isNotEmpty) {
        final fetchedThreads = <CineChatThread>[];
        for (final item in list) {
          final userId = item['user_id']?.toString() ?? '';
          final fullName = item['full_name']?.toString() ?? 'Cinema Professional';
          final lastMsg = item['last_message']?.toString() ?? '';
          final lastMsgAt = DateTime.tryParse(item['last_message_at']?.toString() ?? '');
          final unread = (item['unread_count'] as num?)?.toInt() ?? 0;

          final initials = fullName
              .split(' ')
              .where((p) => p.isNotEmpty)
              .map((p) => p[0])
              .take(2)
              .join()
              .toUpperCase();

          // Preserve existing local message list for this thread if already populated
          final existingIdx = chatThreads.indexWhere((t) => t.id == userId);
          final existingMessages =
              existingIdx != -1 ? chatThreads[existingIdx].messages : <CineChatMessage>[];

          fetchedThreads.add(
            CineChatThread(
              id: userId,
              participantName: fullName,
              participantCraft: 'Production / Cinema Peer',
              avatar: initials.isNotEmpty ? initials : 'CP',
              lastMessage: lastMsg,
              lastMessageTime: lastMsgAt != null ? _formatMessageTime(lastMsgAt) : 'Recent',
              unreadCount: unread,
              isOnline: true,
              messages: existingMessages,
            ),
          );
        }
        chatThreads = fetchedThreads;
        notifyListeners();
      }
    } catch (_) {
      // Retain existing list if offline or error
    }
  }

  /// Fetches real message history for a conversation thread (`GET /api/v1/messages/conversations/{user_id}`).
  Future<void> loadThreadMessages(String partnerUserId) async {
    _activeChatThreadId = partnerUserId;
    try {
      final rawMsgs = await _apiService.chatService.getConversationMessages(partnerUserId);
      final currentUserId = ApiClient.currentUserId;

      final mapped = rawMsgs.map((m) {
        final msgId = m['id']?.toString() ?? '';
        final senderId = m['sender_id']?.toString() ?? '';
        final body = m['body']?.toString() ?? '';
        final createdAt = DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now();
        final isMe = currentUserId != null && senderId == currentUserId;

        return CineChatMessage(
          id: msgId,
          senderName: isMe ? 'Me' : 'Partner',
          text: body,
          time: _formatMessageTime(createdAt),
          isMe: isMe,
        );
      }).toList();

      final index = chatThreads.indexWhere((t) => t.id == partnerUserId);
      if (index != -1) {
        final cur = chatThreads[index];
        final bool isDifferent = cur.messages.length != mapped.length ||
            (mapped.isNotEmpty && cur.messages.isNotEmpty && mapped.last.id != cur.messages.last.id);
        if (isDifferent) {
          chatThreads[index] = cur.copyWith(
            messages: mapped,
            unreadCount: 0,
          );
          notifyListeners();
        }
      } else {
        await loadConversations();
      }
    } catch (_) {}
  }

  void _handleIncomingWsMessage(Map<String, dynamic> event) {
    final currentUserId = ApiClient.currentUserId;
    final msgId = event['message_id']?.toString() ?? '';
    final senderId = event['sender_id']?.toString() ?? '';
    final recipientId = event['recipient_id']?.toString() ?? '';
    final body = event['body']?.toString() ?? '';
    final createdAt = DateTime.tryParse(event['created_at']?.toString() ?? '') ?? DateTime.now();

    final isMe = currentUserId != null && senderId == currentUserId;
    final partnerId = isMe ? recipientId : senderId;

    final newMsg = CineChatMessage(
      id: msgId,
      senderName: isMe ? 'Me' : 'Partner',
      text: body,
      time: _formatMessageTime(createdAt),
      isMe: isMe,
    );

    final index = chatThreads.indexWhere((t) => t.id == partnerId);
    if (index != -1) {
      final cur = chatThreads[index];
      // Deduplicate by message ID
      if (!cur.messages.any((m) => m.id == msgId)) {
        final updated = List<CineChatMessage>.from(cur.messages)..add(newMsg);
        final isThreadActive = _activeChatThreadId == partnerId;
        chatThreads[index] = cur.copyWith(
          lastMessage: body,
          lastMessageTime: _formatMessageTime(createdAt),
          unreadCount: isThreadActive ? 0 : cur.unreadCount + 1,
          messages: updated,
        );
        notifyListeners();
      }
    } else {
      // New conversation initiated by remote partner
      loadConversations();
    }
  }

  void markChatThreadAsRead(String threadId) {
    final index = chatThreads.indexWhere((t) => t.id == threadId);
    if (index != -1 && chatThreads[index].unreadCount > 0) {
      chatThreads[index] = chatThreads[index].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  /// Sends a direct message via FastAPI REST & WebSocket, updating UI with deduplication.
  Future<void> sendChatMessage(String threadId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = CineChatMessage(
      id: tempId,
      senderName: 'Me',
      text: trimmed,
      time: 'Just now',
      isMe: true,
    );

    final index = chatThreads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = chatThreads[index];
      final updatedMessages = List<CineChatMessage>.from(thread.messages)..add(optimisticMsg);
      chatThreads[index] = thread.copyWith(
        lastMessage: trimmed,
        lastMessageTime: 'Just now',
        unreadCount: 0,
        messages: updatedMessages,
      );
      notifyListeners();
    }

    try {
      final res = await _apiService.chatService.sendMessage(
        recipientId: threadId,
        body: trimmed,
        clientMessageId: tempId,
      );

      final realId = res['id']?.toString() ?? tempId;
      final createdAt = DateTime.tryParse(res['created_at']?.toString() ?? '') ?? DateTime.now();

      // Replace optimistic placeholder with confirmed server message ID
      final curIdx = chatThreads.indexWhere((t) => t.id == threadId);
      if (curIdx != -1) {
        final cur = chatThreads[curIdx];
        final updated = cur.messages.map((m) {
          if (m.id == tempId) {
            return CineChatMessage(
              id: realId,
              senderName: 'Me',
              text: trimmed,
              time: _formatMessageTime(createdAt),
              isMe: true,
            );
          }
          return m;
        }).toList();

        chatThreads[curIdx] = cur.copyWith(messages: updated);
        notifyListeners();
      }
    } catch (_) {
      // Retain optimistic message in offline mode
    }
  }

  Future<void> addFeedPost(CineFeedPost newPost) async {
    feedPosts.insert(0, newPost);
    notifyListeners();
    try {
      final res = await _apiService.createFeedPost(
        contentText: newPost.contentText,
        videoSlateTitle: newPost.videoSlateTitle,
        smpteTimecode: newPost.smpteTimecode,
        craftTags: newPost.taggedCrafts,
      );
      if (res is Map<String, dynamic> && res['id'] != null) {
        final confirmed = CineFeedPost.fromJson(res);
        final idx = feedPosts.indexWhere((p) => p.id == newPost.id);
        if (idx != -1) {
          feedPosts[idx] = confirmed;
          notifyListeners();
        }
      }
    } catch (_) {
      // Keep optimistic post in offline mode
    }
  }

  Future<void> toggleLikePost(String postId) async {
    final idx = feedPosts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final originalPost = feedPosts[idx];
    final wasLiked = originalPost.isLiked;
    final targetLiked = !wasLiked;
    final targetLikesCount = targetLiked
        ? originalPost.likes + 1
        : (originalPost.likes > 0 ? originalPost.likes - 1 : 0);

    // Optimistic state update
    feedPosts[idx] = originalPost.copyWith(
      isLiked: targetLiked,
      likes: targetLikesCount,
    );
    notifyListeners();

    try {
      if (targetLiked) {
        final res = await _apiService.interactWithPost(
          postId: postId,
          interactionType: 'like',
        );
        if (res is Map<String, dynamic> && res['id'] != null) {
          final interactionId = res['id'].toString();
          _postLikeInteractionIds[postId] = interactionId;
          final curIdx = feedPosts.indexWhere((p) => p.id == postId);
          if (curIdx != -1) {
            feedPosts[curIdx] = feedPosts[curIdx].copyWith(likeInteractionId: interactionId);
          }
        }
      } else {
        final interactionId = _postLikeInteractionIds[postId] ?? originalPost.likeInteractionId;
        if (interactionId != null && interactionId.isNotEmpty) {
          await _apiService.deleteInteraction(interactionId);
          _postLikeInteractionIds.remove(postId);
          final curIdx = feedPosts.indexWhere((p) => p.id == postId);
          if (curIdx != -1) {
            feedPosts[curIdx] = feedPosts[curIdx].copyWith(likeInteractionId: null);
          }
        } else {
          throw Exception('Cannot unlike: Missing interaction ID');
        }
      }
    } catch (_) {
      // Rollback optimistic update on error
      final rollbackIdx = feedPosts.indexWhere((p) => p.id == postId);
      if (rollbackIdx != -1) {
        feedPosts[rollbackIdx] = originalPost;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> addCommentToPost(String postId, String comment, {String? timecode}) async {
    final idx = feedPosts.indexWhere((p) => p.id == postId);
    if (idx != -1) {
      final old = feedPosts[idx];
      feedPosts[idx] = old.copyWith(comments: old.comments + 1);
      notifyListeners();
      try {
        await _apiService.interactWithPost(
          postId: postId,
          interactionType: 'comment',
          critiqueNote: comment,
          timecode: timecode,
        );
      } catch (_) {}
    }
  }

  Future<void> toggleBookmarkPost(String postId) async {
    try {
      await _apiService.bookmarkPost(postId);
    } catch (_) {}
  }

  Future<CineReelItem> addReel({
    required String title,
    required String mediaUrl,
    String? caption,
    String? thumbnailUrl,
    String? audioTrack,
    String? smpteTimecode,
    String? craftSpecialty,
    String? reelType,
  }) async {
    try {
      final res = await _apiService.createReel(
        title: title,
        mediaUrl: mediaUrl,
        caption: caption,
        thumbnailUrl: thumbnailUrl,
        audioTrack: audioTrack,
        smpteTimecode: smpteTimecode,
        craftSpecialty: craftSpecialty,
        reelType: reelType,
      );
      if (res is Map<String, dynamic> && res['id'] != null) {
        final confirmed = CineReelItem.fromJson(res);
        reels.insert(0, confirmed);
        notifyListeners();
        return confirmed;
      }
      throw Exception('Invalid server response when creating CineReel');
    } catch (_) {
      rethrow;
    }
  }

  Future<void> deleteReel(String reelId) async {
    try {
      await _apiService.deleteReel(reelId);
      reels.removeWhere((r) => r.id == reelId);
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  Future<String?> refreshReelPlaybackUrl(String reelId) async {
    try {
      final res = await _apiService.getReelPlaybackUrl(reelId);
      if (res is Map<String, dynamic> && res['playback_url'] != null) {
        final freshUrl = res['playback_url'].toString();
        final idx = reels.indexWhere((r) => r.id == reelId);
        if (idx != -1) {
          reels[idx] = reels[idx].copyWith(playbackUrl: freshUrl);
          notifyListeners();
        }
        return freshUrl;
      }
    } catch (_) {}
    return null;
  }

  // ==========================================
  // Real Portfolio & Showreels Integration
  // ==========================================
  Future<void> loadMyPortfolio({bool refresh = false}) async {
    _isLoadingPortfolio = true;
    _portfolioError = null;
    notifyListeners();
    try {
      final res = await _apiService.getMyPortfolio();
      if (res is List) {
        myPortfolio = res
            .whereType<Map<String, dynamic>>()
            .map(PortfolioItem.fromJson)
            .toList();
      }
    } catch (e) {
      _portfolioError = e.toString();
    } finally {
      _isLoadingPortfolio = false;
      notifyListeners();
    }
  }

  Future<PortfolioItem> addPortfolioItem({
    required String title,
    required String mediaUrl,
    String? description,
    String mediaType = 'video',
    String? thumbnailUrl,
  }) async {
    try {
      final res = await _apiService.addPortfolioMedia(
        title: title,
        mediaUrl: mediaUrl,
        description: description,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
      );
      if (res is Map<String, dynamic> && res['id'] != null) {
        final confirmed = PortfolioItem.fromJson(res);
        myPortfolio.insert(0, confirmed);
        notifyListeners();
        return confirmed;
      }
      throw Exception('Invalid server response when creating portfolio item');
    } catch (_) {
      rethrow;
    }
  }

  Future<void> deletePortfolioItem(String mediaId) async {
    try {
      await _apiService.deletePortfolioMedia(mediaId);
      myPortfolio.removeWhere((p) => p.id == mediaId);
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  Future<String?> refreshPortfolioDownloadUrl(String mediaId) async {
    try {
      final res = await _apiService.getPortfolioDownloadUrl(mediaId);
      if (res is Map<String, dynamic> && res['playback_url'] != null) {
        final freshUrl = res['playback_url'].toString();
        final idx = myPortfolio.indexWhere((p) => p.id == mediaId);
        if (idx != -1) {
          myPortfolio[idx] = myPortfolio[idx].copyWith(playbackUrl: freshUrl);
          notifyListeners();
        }
        return freshUrl;
      }
    } catch (_) {}
    return null;
  }

  // Skill match calculator
  double calculateSkillMatch(List<String> required) {
    if (required.isEmpty) return 1.0;
    int matches = 0;
    for (final req in required) {
      if (_userSkills.contains(req)) {
        matches++;
      }
    }
    return (matches / required.length) * 100.0;
  }

  // 1-Tap apply to job using Talent API service with optional self-tape and resume
  Future<void> applyToJob(
    String jobId, {
    String? selfTapeUrl,
    String? resumeUrl,
    String? coverLetter,
  }) async {
    try {
      await _apiService.applyForOpportunity(
        opportunityId: jobId,
        selfTapeUrl: selfTapeUrl,
        resumeUrl: resumeUrl,
        notes: coverLetter,
      );
    } catch (e) {
      // Re-throw so caller / UI can surface the real error
      rethrow;
    }
    final index = jobBriefs.indexWhere((j) => j.id == jobId);
    if (index != -1) {
      final old = jobBriefs[index];
      jobBriefs[index] = old.copyWith(
        hasUserApplied: true,
        applicantsCount: old.applicantsCount + 1,
        applicationStatus: ApplicationStatus.submitted,
      );
      notifyListeners();
    }
  }

  // 1-Tap or detailed apply to public Project using Talent API service
  Future<void> applyToProject(
    String projectId, {
    String? coverLetter,
    String? resumeUrl,
    String? selfTapeUrl,
  }) async {
    try {
      await _apiService.applyToProject(
        projectId: projectId,
        coverLetter: coverLetter,
        resumeUrl: resumeUrl,
        reelUrl: selfTapeUrl,
      );
    } catch (e) {
      rethrow;
    }
    final index = publicProjects.indexWhere((p) => p.id == projectId);
    if (index != -1) {
      final old = publicProjects[index];
      publicProjects[index] = old.copyWith(
        hasUserApplied: true,
        applicationsCount: old.applicationsCount + 1,
        applicationStatus: 'submitted',
      );
      notifyListeners();
    }
  }

  // ==========================================
  // Connection Actions (Send, Accept, Reject, Remove)
  // ==========================================
  Future<CineConnection> sendConnectionRequest(String targetUserId) async {
    if (myProfile != null && targetUserId == myProfile!.id) {
      throw Exception('You cannot connect with yourself.');
    }
    final existingStatus = peerConnectionStatuses[targetUserId];
    if (existingStatus == ConnectionStatus.connected) {
      throw Exception('Already connected with this talent.');
    }
    if (existingStatus == ConnectionStatus.pendingSent) {
      throw Exception('A connection request is already pending with this talent.');
    }

    try {
      final res = await _apiService.sendConnectionRequest(targetUserId);
      if (res is Map<String, dynamic> && res['id'] != null) {
        final conn = CineConnection.fromJson(res);
        peerConnectionIds[targetUserId] = conn.id;
        peerConnectionStatuses[targetUserId] = ConnectionStatus.pendingSent;

        final idx = talentNetwork.indexWhere((t) => t.id == targetUserId);
        if (idx != -1) {
          talentNetwork[idx] = talentNetwork[idx].copyWith(
            connectionId: conn.id,
            connectionStatus: ConnectionStatus.pendingSent,
            isConnected: false,
          );
        }
        notifyListeners();
        return conn;
      }
      throw Exception('Unexpected server response when sending connection request');
    } catch (_) {
      rethrow;
    }
  }

  Future<void> acceptConnectionRequest(String connectionId) async {
    final reqIdx = incomingRequests.indexWhere((r) => r.id == connectionId);
    final senderId = reqIdx != -1 ? incomingRequests[reqIdx].senderId : null;

    try {
      await _apiService.acceptConnectionRequest(connectionId);
      if (reqIdx != -1) {
        incomingRequests.removeAt(reqIdx);
      }
      if (senderId != null) {
        peerConnectionStatuses[senderId] = ConnectionStatus.connected;
        final idx = talentNetwork.indexWhere((t) => t.id == senderId);
        if (idx != -1) {
          final old = talentNetwork[idx];
          talentNetwork[idx] = old.copyWith(
            isConnected: true,
            connectionId: connectionId,
            connectionStatus: ConnectionStatus.connected,
            connectionsCount: old.connectionsCount + 1,
          );
        }
      }
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> rejectConnectionRequest(String connectionId) async {
    final reqIdx = incomingRequests.indexWhere((r) => r.id == connectionId);
    final senderId = reqIdx != -1 ? incomingRequests[reqIdx].senderId : null;

    try {
      await _apiService.rejectConnectionRequest(connectionId);
      if (reqIdx != -1) {
        incomingRequests.removeAt(reqIdx);
      }
      if (senderId != null) {
        peerConnectionStatuses[senderId] = ConnectionStatus.none;
        peerConnectionIds.remove(senderId);
        final idx = talentNetwork.indexWhere((t) => t.id == senderId);
        if (idx != -1) {
          talentNetwork[idx] = talentNetwork[idx].copyWith(
            isConnected: false,
            connectionStatus: ConnectionStatus.none,
            connectionId: null,
          );
        }
      }
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> removeConnection(String connectionId, {String? peerUserId}) async {
    String? targetPeerId = peerUserId;
    if (targetPeerId == null) {
      for (final entry in peerConnectionIds.entries) {
        if (entry.value == connectionId) {
          targetPeerId = entry.key;
          break;
        }
      }
    }

    try {
      await _apiService.removeConnection(connectionId);
      if (targetPeerId != null) {
        peerConnectionIds.remove(targetPeerId);
        peerConnectionStatuses[targetPeerId] = ConnectionStatus.none;
        final idx = talentNetwork.indexWhere((t) => t.id == targetPeerId);
        if (idx != -1) {
          final old = talentNetwork[idx];
          talentNetwork[idx] = old.copyWith(
            isConnected: false,
            connectionStatus: ConnectionStatus.none,
            connectionId: null,
            connectionsCount: old.isConnected ? (old.connectionsCount > 0 ? old.connectionsCount - 1 : 0) : old.connectionsCount,
          );
        }
      }
      incomingRequests.removeWhere((r) => r.id == connectionId);
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> removeConnectionWithPeer(String peerUserId) async {
    final connId = peerConnectionIds[peerUserId] ??
        talentNetwork.where((t) => t.id == peerUserId).map((t) => t.connectionId).firstOrNull;
    if (connId == null || connId.isEmpty) {
      throw Exception('No active connection found to remove.');
    }
    await removeConnection(connId, peerUserId: peerUserId);
  }

  // Connect with peer using Talent API service
  Future<void> togglePeerConnection(String talentId) async {
    final status = peerConnectionStatuses[talentId] ??
        talentNetwork.where((t) => t.id == talentId).map((t) => t.connectionStatus).firstOrNull ??
        ConnectionStatus.none;

    if (status == ConnectionStatus.connected || status == ConnectionStatus.pendingSent) {
      await removeConnectionWithPeer(talentId);
    } else {
      await sendConnectionRequest(talentId);
    }
  }

  // 1-Tap Instagram-style Follow/Unfollow toggle
  Future<bool> toggleFollowUser(String targetUserId) async {
    try {
      final res = await _apiService.toggleFollow(targetUserId);
      bool isFollowing = false;
      if (res is Map<String, dynamic>) {
        isFollowing = res['is_following'] == true;
      }
      peerConnectionStatuses[targetUserId] =
          isFollowing ? ConnectionStatus.connected : ConnectionStatus.none;

      final idx = talentNetwork.indexWhere((t) => t.id == targetUserId);
      if (idx != -1) {
        final old = talentNetwork[idx];
        talentNetwork[idx] = old.copyWith(
          connectionStatus: isFollowing ? ConnectionStatus.connected : ConnectionStatus.none,
          isConnected: isFollowing,
        );
      }
      notifyListeners();
      return isFollowing;
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    _chatWsSubscription?.cancel();
    _chatConnSubscription?.cancel();
    super.dispose();
  }
}
