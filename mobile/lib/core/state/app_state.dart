import 'package:flutter/foundation.dart';
import '../models/craft_models.dart';
import '../services/talent_api_service.dart';

class CineAppState extends ChangeNotifier {
  final TalentApiService _apiService = TalentApiService();

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

  CineAppState() {
    _initConnectivityCheck();
  }

  Future<void> _initConnectivityCheck() async {
    _isBackendConnected = await _apiService.checkBackendHealth();
    notifyListeners();
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
  late List<ProductionJobBrief> jobBriefs = [
    const ProductionJobBrief(
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
    const ProductionJobBrief(
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
    const ProductionJobBrief(
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
  int get unreadNotificationsCount => notifications.where((n) => !n.isRead).length;
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

  void markNotificationsAsRead() {
    notifications = notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  void markNotificationAsRead(String id) {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !notifications[index].isRead) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markChatThreadAsRead(String threadId) {
    final index = chatThreads.indexWhere((t) => t.id == threadId);
    if (index != -1 && chatThreads[index].unreadCount > 0) {
      chatThreads[index] = chatThreads[index].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  void sendChatMessage(String threadId, String text) {
    if (text.trim().isEmpty) return;
    final index = chatThreads.indexWhere((t) => t.id == threadId);
    if (index != -1) {
      final thread = chatThreads[index];
      final newMsg = CineChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        senderName: 'Me',
        text: text.trim(),
        time: 'Just now',
        isMe: true,
      );
      final updatedMessages = List<CineChatMessage>.from(thread.messages)..add(newMsg);
      chatThreads[index] = thread.copyWith(
        lastMessage: text.trim(),
        lastMessageTime: 'Just now',
        unreadCount: 0,
        messages: updatedMessages,
      );
      notifyListeners();

      // Simulate a realistic cinema peer reply after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        final replyMsg = CineChatMessage(
          id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
          senderName: thread.participantName,
          text: 'Acknowledged! Added to the on-set call sheet notes.',
          time: 'Just now',
          isMe: false,
        );
        final currentIdx = chatThreads.indexWhere((t) => t.id == threadId);
        if (currentIdx != -1) {
          final curThread = chatThreads[currentIdx];
          final withReply = List<CineChatMessage>.from(curThread.messages)..add(replyMsg);
          chatThreads[currentIdx] = curThread.copyWith(
            lastMessage: replyMsg.text,
            lastMessageTime: 'Just now',
            messages: withReply,
          );
          notifyListeners();
        }
      });
    }
  }

  void addFeedPost(CineFeedPost newPost) {
    feedPosts.insert(0, newPost);
    notifyListeners();
  }

  void addReel(CineReelItem newReel) {
    reels.insert(0, newReel);
    notifyListeners();
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

  // 1-Tap apply to job using Talent API service
  Future<void> applyToJob(String jobId) async {
    try {
      await _apiService.applyForOpportunity(opportunityId: jobId);
    } catch (_) {
      // In offline/mock mode, proceed seamlessly
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

  // Connect with peer using Talent API service
  Future<void> togglePeerConnection(String talentId) async {
    final index = talentNetwork.indexWhere((t) => t.id == talentId);
    if (index != -1) {
      final old = talentNetwork[index];
      final newConnected = !old.isConnected;
      try {
        if (newConnected) {
          await _apiService.sendConnectionRequest(talentId);
        }
      } catch (_) {}
      talentNetwork[index] = old.copyWith(
        isConnected: newConnected,
        connectionsCount: old.connectionsCount + (newConnected ? 1 : -1),
      );
      notifyListeners();
    }
  }
}
