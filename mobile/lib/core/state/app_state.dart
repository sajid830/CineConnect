import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/craft_models.dart';
import '../network/api_client.dart';
import '../services/chat_service.dart';
import '../services/talent_api_service.dart';
import '../../features/production_house/data/models/portfolio_item.dart';

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
    }
  }

  Future<void> _initConnectivityCheck() async {
    _isBackendConnected = await _apiService.checkBackendHealth();
    notifyListeners();
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
      _isLoadingProfile = false;
      notifyListeners();
    }
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
        if (jobBriefs.isEmpty || forceRefresh) {
          jobBriefs = List.of(_fallbackJobBriefs);
          _isUsingFallbackOpportunities = true;
        }
      }
    } catch (e) {
      _opportunitiesError = e.toString();
      // On connection error, preserve existing or fall back to mock data
      if (jobBriefs.isEmpty) {
        jobBriefs = List.of(_fallbackJobBriefs);
        _isUsingFallbackOpportunities = true;
      }
    } finally {
      _isLoadingOpportunities = false;
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

  // --- Mock Stories ---
  final List<OnSetStory> stories = [
    const OnSetStory(
      id: 'story-0',
      creatorName: 'YOU',
      initials: 'YOU',
      craftBadge: 'My Slate',
      location: 'Stage 4 - Annapurna Studios',
      storyCaption: 'Pre-light check for 120fps anamorphic crane shot.',
      timeAgo: 'Just now',
      hasUnseen: false,
    ),
    const OnSetStory(
      id: 'story-1',
      creatorName: 'Maya Ray',
      initials: 'MR',
      craftBadge: 'Cinematographer (ISC)',
      location: 'Ramoji Film City, Stage 12',
      storyCaption: 'Night sequence lit with ARRI SkyPanel X & LiteMat 4. Alexa 35 at EI 3200.',
      timeAgo: '14m ago',
    ),
    const OnSetStory(
      id: 'story-2',
      creatorName: 'Alex Chen',
      initials: 'AC',
      craftBadge: 'Stunt Coordinator',
      location: 'Filmistan Studio, Mumbai',
      storyCaption: 'Rehearsing wire-work for climax brawl. Safety rigs certified.',
      timeAgo: '42m ago',
    ),
    const OnSetStory(
      id: 'story-3',
      creatorName: 'Liam Rossi',
      initials: 'LR',
      craftBadge: 'Production Sound / Atmos',
      location: 'Outdoor Ghats, Varanasi',
      storyCaption: 'Schoeps CMIT 5U in 40km/h wind with Rycote Cyclone. Zero rumble.',
      timeAgo: '2h ago',
    ),
    const OnSetStory(
      id: 'story-4',
      creatorName: 'Elena Vance',
      initials: 'EV',
      craftBadge: 'Virtual Production / ICVFX',
      location: 'Nandi Hills LED Volume',
      storyCaption: 'Calibrating UE5 nDisplay parallax with tracking markers. Seamless wrap.',
      timeAgo: '4h ago',
    ),
  ];

  // --- LinkedIn for Cinema Posts ---
  late List<CineFeedPost> feedPosts = [
    const CineFeedPost(
      id: 'post-1',
      authorName: 'Maya Ray',
      authorCraft: 'Director of Photography (ISC)',
      authorAvatar: 'MR',
      guildBadge: 'ISC-9021 • Verified',
      timestamp: '2 hours ago • Hyderabad Hub',
      contentText:
          'Official Wrap on "Midnight Solitude"! 🎬 38 continuous night shoots wrapped cleanly under schedule. Rigged dual ARRI Alexa 35s paired with vintage Cooke Anamorphic /i primes. Huge credit to my 1st AC and Gaffer for sustaining pristine exposure across T2.0 deep shadows without clipping highlight roll-offs.',
      videoSlateTitle: 'SCENE 84A / TAKE 3 [ANAMORPHIC MASTER 2.39:1]',
      smpteTimecode: 'TC 01:24:19:18',
      currentAspect: '2.39:1',
      likes: 842,
      comments: 94,
      taggedCrafts: ['Cinematography', 'Grip & Lighting', 'Camera Dept', 'Color Grading'],
    ),
    const CineFeedPost(
      id: 'post-2',
      authorName: 'Alex Chen',
      authorCraft: 'Action Director / Stunt Choreographer',
      authorAvatar: 'AC',
      guildBadge: 'FMAI-418 • Verified',
      timestamp: '5 hours ago • Mumbai Hub',
      contentText:
          'Behind the scenes of our 4-minute continuous oner stunt sequence on "Viper Strike". No CGI cuts, pure timing with Ronin 4D on a high-speed cable dolly with 6 stunt doubles executing precision falls.',
      videoSlateTitle: 'ACTION PRE-VIZ / RIGGING TEST REEL',
      smpteTimecode: 'TC 00:08:42:04',
      currentAspect: '16:9',
      likes: 1240,
      comments: 136,
      taggedCrafts: ['Stunts', 'Direction', 'Aerial & Drone', 'VFX'],
    ),
  ];

  // --- Opportunities (Naukri for Talent) ---
  static const List<ProductionJobBrief> _fallbackJobBriefs = [
    ProductionJobBrief(
      id: 'job-101',
      studioName: 'Mythri Movie Makers',
      studioBannerLogo: 'MMM',
      councilId: 'TFPC-2026-MMM4',
      projectTitle: 'Project Garuda (Pan-India Action Sci-Fi)',
      targetCraft: 'Cinematography / DOP',
      hubLocation: 'Hyderabad & Dubai Hubs',
      compensation: '₹18,00,000 - ₹25,00,000 / Schedule',
      shootWindow: 'Dec 15, 2026 – Feb 28, 2027 (45 Days)',
      description:
          'Seeking an experienced A-Camera Cinematographer with extensive high-speed phantom work, anamorphic glass experience, and Virtual Production LED volume workflows.',
      screenplaySides:
          'SCENE 14. INT. CYBERNETIC COMMAND BUNKER - NIGHT\nDense haze fills the subterranean control chamber. Amber strobe lights flash at 120BPM.\nDEV (30s) wipes grease from his mechanical eye-patch, cocking the ion disruptor.\nDEV: "Kill the main breaker. Let them hunt us in the dark."',
      requiredSkills: [
        'ARRI Alexa 35',
        'Cooke Anamorphic /i',
        'Unreal Engine 5 ICVFX',
        'DaVinci Resolve Studio',
        'Low-Key Film Noir Lighting',
      ],
      applicantsCount: 42,
      isPanIndia: true,
      hasUserApplied: true,
      applicationStatus: ApplicationStatus.underDirectorReview,
    ),
    ProductionJobBrief(
      id: 'job-102',
      studioName: 'Excel Entertainment',
      studioBannerLogo: 'EXCEL',
      councilId: 'IMPPA-2026-XCL',
      projectTitle: 'Don: Legacy Dawn',
      targetCraft: 'Action & Stunt Director',
      hubLocation: 'Mumbai & Berlin Hubs',
      compensation: '₹35,00,000 / Flat Project Contract',
      shootWindow: 'Jan 10, 2027 – April 2027',
      description:
          'Urgent requirement for an international fight choreographer and stunt coordinator versed in practical vehicle collisions, tactical close-quarters choreography, and wire work.',
      screenplaySides:
          'SCENE 99. EXT. AUTOBAHN VIADUCT - DUSK\nRain lashes the asphalt. Two black sedans scream sideways at 180 km/h.\nKABIR vaults through the shattered windshield onto the rear chassis of the pursuit SUV.',
      requiredSkills: [
        'Martial Arts & Kalari',
        'Wire-Work Rigging',
        'Precision Vehicle Stunts',
        'High-Speed Camera Coordination',
      ],
      applicantsCount: 29,
      isPanIndia: true,
      hasUserApplied: false,
      applicationStatus: ApplicationStatus.submitted,
    ),
    ProductionJobBrief(
      id: 'job-103',
      studioName: 'YRF (Yash Raj Films)',
      studioBannerLogo: 'YRF',
      councilId: 'IMPPA-2026-YRF1',
      screenplaySides: "",
      projectTitle: 'Pathaan: Protocol Zero',
      targetCraft: 'Sound Design & Atmos Mix',
      hubLocation: 'YRF Studios, Mumbai',
      compensation: '₹12,00,000 / Final Mix Stage',
      shootWindow: 'Post-Production Nov 2026 – Jan 2027',
      description:
          'Looking for Lead Supervising Sound Editor and Atmos Re-recording Mixer for theatrical 9.1.4 Dolby Atmos release. Must possess Avid Pro Tools HDX cert and weapon foley library.',
      requiredSkills: [
        'Dolby Atmos 9.1.4 Mixing',
        'Avid Pro Tools HDX',
        'Foley Design',
        'SMPTE Timecode Sync',
      ],
      applicantsCount: 18,
      isPanIndia: false,
      hasUserApplied: true,
      applicationStatus: ApplicationStatus.shortlisted,
    ),
  ];

  late List<ProductionJobBrief> jobBriefs = List.of(_fallbackJobBriefs);

  // --- Instagram Reels for Cinema ---
  late List<CineReelItem> reels = [
    const CineReelItem(
      id: 'reel-1',
      creatorName: 'Maya Ray',
      creatorCraft: 'Cinematographer (ISC)',
      creatorAvatar: 'MR',
      title: 'ARRI Alexa 35 + Hawk V-Lite Anamorphic Night Showreel',
      audioTrack: 'Original Score • Hans Zimmer (Dune Atmos Suite)',
      smpteTimecode: '00:01:14:18',
      craftSpecialty: 'Anamorphic 2.39:1 Flare & Shadow Roll-off',
      likesCount: 14200,
      commentsCount: 630,
      reelType: 'Cinematography Showreel',
    ),
    const CineReelItem(
      id: 'reel-2',
      creatorName: 'Elena Vance',
      creatorCraft: 'Virtual Production Lead',
      creatorAvatar: 'EV',
      title: 'Unreal Engine 5.4 In-Camera VFX (ICVFX) Live Parallax Test',
      audioTrack: 'Sound Design • Ludwig Göransson (Oppenheimer)',
      smpteTimecode: '00:00:48:12',
      craftSpecialty: 'LED Volume Real-time Camera Tracking',
      likesCount: 9800,
      commentsCount: 412,
      reelType: 'Virtual Production Reel',
    ),
    const CineReelItem(
      id: 'reel-3',
      creatorName: 'Alex Chen',
      creatorCraft: 'Stunt Choreographer',
      creatorAvatar: 'AC',
      title: 'Single-Take Corridor Katana Fight Sequence (Uncut)',
      audioTrack: 'Original Sound Stage Sync FX (Punch & Blade)',
      smpteTimecode: '00:02:10:06',
      craftSpecialty: 'Kalarippayattu Martial Combat',
      likesCount: 22400,
      commentsCount: 1205,
      reelType: 'Stunt Reel',
    ),
  ];

  // --- 24-Crafts Peer Network & Radar ---
  late List<TalentProfile> talentNetwork = [
    const TalentProfile(
      id: 'talent-1',
      fullName: 'Maya Ray',
      handle: '@mayaray_dop',
      headline: 'Award-Winning Cinematographer | ARRI Alexa 35 Owner-Operator',
      avatarUrl: 'MR',
      primaryCraft: 'Cinematography / DOP',
      secondaryCrafts: ['DI Colorist', 'Lighting / Gaffer'],
      guildId: 'ISC-9021',
      hubLocation: 'Hyderabad & Mumbai',
      dailyCallSheetRate: '₹95,000 / Day',
      immediateAvailability: 'Available from Dec 1',
      verifiedGear: ['ARRI Alexa 35', 'Cooke Anamorphic /i 32/50/85', 'SmallHD Cine 13', 'Ronin 2'],
      skillTags: [
        'ARRI Alexa 35',
        'Cooke Anamorphic /i',
        'Unreal Engine 5 ICVFX',
        'DaVinci Resolve Studio',
        'Low-Key Film Noir Lighting',
        'Ronin 4D 8K',
      ],
      filmography: [
        VerifiedFilmCredit(
          id: 'c1',
          filmTitle: 'Midnight Solitude',
          releaseYear: 2026,
          craftRole: 'Director of Photography',
          directorName: 'Karthik Subbaraj',
          studioBanner: 'Stone Bench Films',
        ),
        VerifiedFilmCredit(
          id: 'c2',
          filmTitle: 'Neon Dust',
          releaseYear: 2025,
          craftRole: '2nd Unit DOP',
          directorName: 'Lokesh Kanagaraj',
          studioBanner: 'Raaj Kamal Films',
        ),
      ],
      isConnected: true,
    ),
    const TalentProfile(
      id: 'talent-2',
      fullName: 'Elena Vance',
      handle: '@elena_icvfx',
      headline: 'Virtual Production Supervisor & Unreal Engine 5 nDisplay Specialist',
      avatarUrl: 'EV',
      primaryCraft: 'VFX & Virtual Production (ICVFX)',
      secondaryCrafts: ['Direction', 'Post-Production Supervision'],
      guildId: 'VES-4412',
      hubLocation: 'Bengaluru & Los Angeles',
      dailyCallSheetRate: '₹1,20,000 / Day',
      immediateAvailability: 'Available Immediately',
      verifiedGear: ['OptiTrack MoCap Rig', 'Dual RTX 6000 Ada Nodes', 'AJA Kona 5'],
      skillTags: [
        'Unreal Engine 5 ICVFX',
        'nDisplay Calibration',
        'LED Volume Parallax',
        'DaVinci Resolve Studio',
        'SMPTE Timecode Sync',
      ],
      filmography: [
        VerifiedFilmCredit(
          id: 'c3',
          filmTitle: 'Project Garuda',
          releaseYear: 2026,
          craftRole: 'Virtual Production Supervisor',
          directorName: 'S.S. Rajamouli',
          studioBanner: 'Mythri Movie Makers',
        ),
      ],
      isConnected: false,
    ),
    const TalentProfile(
      id: 'talent-3',
      fullName: 'Alex Chen',
      handle: '@chen_stunts',
      headline: 'Head Stunt Coordinator & Action Director | Martial Arts Specialist',
      avatarUrl: 'AC',
      primaryCraft: 'Stunts & Action Choreography',
      secondaryCrafts: ['Direction', 'Drone / Aerial'],
      guildId: 'FMAI-418',
      hubLocation: 'Mumbai & Chennai',
      dailyCallSheetRate: '₹1,50,000 / Day',
      immediateAvailability: 'Booked till Nov 30',
      verifiedGear: ['Pneumatic Ratchet Rigs', 'Deceleration Airbags', 'High-Speed Wire Rigs'],
      skillTags: [
        'Martial Arts & Kalari',
        'Wire-Work Rigging',
        'Precision Vehicle Stunts',
        'High-Speed Camera Coordination',
      ],
      filmography: [
        VerifiedFilmCredit(
          id: 'c4',
          filmTitle: 'Viper Strike',
          releaseYear: 2025,
          craftRole: 'Action Director',
          directorName: 'Ali Abbas Zafar',
          studioBanner: 'Yash Raj Films',
        ),
      ],
      isConnected: false,
    ),
  ];

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

  late List<CineNotification> notifications = [
    const CineNotification(
      id: 'notif-1',
      title: 'Showreel Shortlisted!',
      description: 'Elena Vance (Director) shortlisted your "Prague Night Exterior" showreel for "Midnight Solitude".',
      timeAgo: '10m ago',
      avatarInitials: 'EV',
      type: 'shortlist',
      isRead: false,
    ),
    const CineNotification(
      id: 'notif-2',
      title: '96% Skill Match Alert',
      description: 'Vyjayanthi Movies posted "Project Garuda" matching your ARRI Alexa 35 & Cooke Anamorphic skills.',
      timeAgo: '1h ago',
      avatarInitials: 'VM',
      type: 'castingMatch',
      isRead: false,
    ),
    const CineNotification(
      id: 'notif-3',
      title: 'Audition Status Updated',
      description: 'Scene 84A passed Stage 2 Review (Under Director Review). Screenplay sides unlocked.',
      timeAgo: '3h ago',
      avatarInitials: 'AC',
      type: 'auditionStatus',
      isRead: false,
    ),
    const CineNotification(
      id: 'notif-4',
      title: 'Call-Sheet Hold Request',
      description: 'Vikram Rao placed a preliminary 6-day hold for Dec 12 - Dec 18 (Mumbai Hub).',
      timeAgo: '5h ago',
      avatarInitials: 'VR',
      type: 'hold',
      isRead: false,
    ),
    const CineNotification(
      id: 'notif-5',
      title: 'Skill Endorsement',
      description: 'Alex Chen endorsed your Steadicam M-2 & SMPTE Timecode Sync technical proficiencies.',
      timeAgo: '1d ago',
      avatarInitials: 'AC',
      type: 'endorsement',
      isRead: true,
    ),
  ];

  late List<CineChatThread> chatThreads = [
    const CineChatThread(
      id: 'thread-1',
      participantName: 'Elena Vance',
      participantCraft: 'Director • Prague Shoot',
      avatar: 'EV',
      lastMessage: 'Loved your latest grade on the Prague teaser. Are you free for DI review tomorrow at 11 AM?',
      lastMessageTime: '14:20',
      unreadCount: 1,
      isOnline: true,
      messages: [
        CineChatMessage(
          id: 'm1',
          senderName: 'Elena Vance',
          text: 'Hey! Just screened your anamorphic night test on the calibrated Barco projector.',
          time: '14:15',
          isMe: false,
        ),
        CineChatMessage(
          id: 'm2',
          senderName: 'Elena Vance',
          text: 'Loved your latest grade on the Prague teaser. Are you free for DI review tomorrow at 11 AM?',
          time: '14:20',
          isMe: false,
        ),
      ],
    ),
    const CineChatThread(
      id: 'thread-2',
      participantName: 'Vikram Rao',
      participantCraft: 'Producer • Hombale Films',
      avatar: 'VR',
      lastMessage: 'Call-sheet hold confirmed for Dec 12. Contract dispatching soon.',
      lastMessageTime: '11:45',
      unreadCount: 1,
      isOnline: true,
      messages: [
        CineChatMessage(
          id: 'm3',
          senderName: 'Vikram Rao',
          text: 'Our line producer approved the equipment package (Alexa 35 + Cooke primes).',
          time: '11:30',
          isMe: false,
        ),
        CineChatMessage(
          id: 'm4',
          senderName: 'Vikram Rao',
          text: 'Call-sheet hold confirmed for Dec 12. Contract dispatching soon.',
          time: '11:45',
          isMe: false,
        ),
      ],
    ),
    const CineChatThread(
      id: 'thread-3',
      participantName: 'Alex Chen',
      participantCraft: 'Stunt Coordinator',
      avatar: 'AC',
      lastMessage: "Let's sync up on the rig safety protocol before tomorrow's shoot.",
      lastMessageTime: 'Yesterday',
      unreadCount: 0,
      isOnline: false,
      messages: [
        CineChatMessage(
          id: 'm5',
          senderName: 'Alex Chen',
          text: "Let's sync up on the rig safety protocol before tomorrow's shoot.",
          time: 'Yesterday 18:00',
          isMe: false,
        ),
      ],
    ),
    const CineChatThread(
      id: 'thread-4',
      participantName: 'Priya Sharma',
      participantCraft: 'Casting Director • YRF',
      avatar: 'PS',
      lastMessage: 'Received your self-tape for the lead role. Great cadence!',
      lastMessageTime: '2d ago',
      unreadCount: 0,
      isOnline: false,
      messages: [
        CineChatMessage(
          id: 'm6',
          senderName: 'Priya Sharma',
          text: 'Received your self-tape for the lead role. Great cadence!',
          time: '2d ago',
          isMe: false,
        ),
      ],
    ),
  ];

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
        chatThreads[index] = chatThreads[index].copyWith(
          messages: mapped,
          unreadCount: 0,
        );
        notifyListeners();
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
}
