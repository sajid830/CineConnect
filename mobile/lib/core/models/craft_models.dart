class CinemaCraft {
  final String id;
  final String name;
  final String category;
  final String department;

  const CinemaCraft({
    required this.id,
    required this.name,
    required this.category,
    required this.department,
  });

  static const List<CinemaCraft> all24Crafts = [
    CinemaCraft(id: 'dir', name: 'Direction', category: 'Above the Line', department: 'Direction'),
    CinemaCraft(id: 'dop', name: 'Cinematography / DOP', category: 'Camera & Lighting', department: 'Camera'),
    CinemaCraft(id: 'scr', name: 'Screenplay & Dialogues', category: 'Above the Line', department: 'Writing'),
    CinemaCraft(id: 'art', name: 'Production Design & Art', category: 'Visual & Scenography', department: 'Art'),
    CinemaCraft(id: 'edit', name: 'Film Editing', category: 'Post-Production', department: 'Editorial'),
    CinemaCraft(id: 'snd', name: 'Sound Design & Atmos Mix', category: 'Audio Engineering', department: 'Sound'),
    CinemaCraft(id: 'act', name: 'Actors / Principal Cast', category: 'Performance', department: 'Talent'),
    CinemaCraft(id: 'stunt', name: 'Stunts & Action Choreography', category: 'Physical Effects', department: 'Stunts'),
    CinemaCraft(id: 'vfx', name: 'VFX & Virtual Production (ICVFX)', category: 'Post-Production', department: 'VFX'),
    CinemaCraft(id: 'mus', name: 'Music Direction & Score', category: 'Audio & Music', department: 'Music'),
    CinemaCraft(id: 'cost', name: 'Costume & Wardrobe Design', category: 'Visual & Scenography', department: 'Costume'),
    CinemaCraft(id: 'mua', name: 'Prosthetics, Hair & Makeup', category: 'Visual & Scenography', department: 'HMU'),
    CinemaCraft(id: 'prod', name: 'Line Production & EP', category: 'Logistics & Management', department: 'Production'),
    CinemaCraft(id: 'chor', name: 'Choreography', category: 'Performance', department: 'Movement'),
    CinemaCraft(id: 'di', name: 'DI Color Grading', category: 'Post-Production', department: 'Finishing'),
    CinemaCraft(id: 'gaff', name: 'Gaffer & Chief Lighting Tech', category: 'Camera & Lighting', department: 'Grip & Electric'),
    CinemaCraft(id: 'grip', name: 'Key Grip & Rigging', category: 'Camera & Lighting', department: 'Grip & Electric'),
    CinemaCraft(id: 'cont', name: 'Continuity & Script Supervision', category: 'On-Set Operations', department: 'Direction'),
    CinemaCraft(id: 'loc_snd', name: 'Sync Sound & Boom Op', category: 'On-Set Operations', department: 'Sound'),
    CinemaCraft(id: 'drone', name: 'FPV & Aerial Cinematography', category: 'Camera & Lighting', department: 'Camera'),
    CinemaCraft(id: 'dial', name: 'Dialect & Accent Coaching', category: 'Performance', department: 'Talent'),
    CinemaCraft(id: 'cast_dir', name: 'Casting Direction', category: 'Pre-Production', department: 'Casting'),
    CinemaCraft(id: 'post_sup', name: 'Post-Production Supervision', category: 'Post-Production', department: 'Editorial'),
    CinemaCraft(id: 'studio_exec', name: 'Creative Producer / Slate', category: 'Creative Management', department: 'Development'),
  ];
}

class VerifiedFilmCredit {
  final String id;
  final String filmTitle;
  final int releaseYear;
  final String craftRole;
  final String directorName;
  final String studioBanner;
  final bool verifiedByGuild;
  final String guildVerificationHash;

  const VerifiedFilmCredit({
    required this.id,
    required this.filmTitle,
    required this.releaseYear,
    required this.craftRole,
    required this.directorName,
    required this.studioBanner,
    this.verifiedByGuild = false,
    this.guildVerificationHash = '',
  });

  factory VerifiedFilmCredit.fromJson(Map<String, dynamic> json) {
    return VerifiedFilmCredit(
      id: json['id']?.toString() ?? '',
      filmTitle: json['film_title']?.toString() ?? '',
      releaseYear: (json['release_year'] as num?)?.toInt() ?? DateTime.now().year,
      craftRole: json['craft_role']?.toString() ?? '',
      directorName: json['director_name']?.toString() ?? '',
      studioBanner: json['studio_banner']?.toString() ?? '',
      verifiedByGuild: json['verified_by_guild'] == true,
      guildVerificationHash: json['guild_verification_hash']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'film_title': filmTitle,
      'release_year': releaseYear,
      'craft_role': craftRole,
      if (directorName.isNotEmpty) 'director_name': directorName,
      if (studioBanner.isNotEmpty) 'studio_banner': studioBanner,
      'verified_by_guild': verifiedByGuild,
      if (guildVerificationHash.isNotEmpty) 'guild_verification_hash': guildVerificationHash,
    };
  }
}

enum ConnectionStatus {
  none,
  connected,        // accepted
  pendingSent,      // user sent request, waiting for receiver
  pendingReceived,  // incoming request, waiting for user to accept/reject
  rejected,
}

class TalentProfile {
  final String id;
  final String fullName;
  final String handle;
  final String headline;
  final String avatarUrl;
  final String primaryCraft;
  String get craft => primaryCraft;
  final List<String> secondaryCrafts;
  final String guildId; // e.g. "ISC-9021", "CINTAA-504", "SICA-1102"
  final bool isGuildVerified;
  final String hubLocation;
  final String dailyCallSheetRate;
  final String immediateAvailability; // "Available Tomorrow", "On Shoot till Dec 10"
  final List<String> verifiedGear;
  final List<String> skillTags;
  final List<VerifiedFilmCredit> filmography;
  final int connectionsCount;
  final int? endorsementsCount;
  final bool isConnected;
  final String? connectionId;
  final ConnectionStatus connectionStatus;

  const TalentProfile({
    required this.id,
    required this.fullName,
    required this.handle,
    required this.headline,
    required this.avatarUrl,
    required this.primaryCraft,
    this.secondaryCrafts = const [],
    this.guildId = '',
    this.isGuildVerified = false,
    this.hubLocation = '',
    this.dailyCallSheetRate = '',
    this.immediateAvailability = '',
    this.verifiedGear = const [],
    this.skillTags = const [],
    this.filmography = const [],
    this.connectionsCount = 0,
    this.endorsementsCount,
    this.isConnected = false,
    this.connectionId,
    this.connectionStatus = ConnectionStatus.none,
  });

  TalentProfile copyWith({
    String? id,
    String? fullName,
    String? handle,
    String? headline,
    String? avatarUrl,
    String? primaryCraft,
    List<String>? secondaryCrafts,
    String? guildId,
    bool? isGuildVerified,
    String? hubLocation,
    String? dailyCallSheetRate,
    String? immediateAvailability,
    List<String>? verifiedGear,
    List<String>? skillTags,
    List<VerifiedFilmCredit>? filmography,
    bool? isConnected,
    int? connectionsCount,
    int? endorsementsCount,
    String? connectionId,
    ConnectionStatus? connectionStatus,
  }) {
    final nextConnected = isConnected ?? this.isConnected;
    final nextStatus = connectionStatus ??
        (isConnected != null
            ? (nextConnected ? ConnectionStatus.connected : ConnectionStatus.none)
            : this.connectionStatus);
    return TalentProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      handle: handle ?? this.handle,
      headline: headline ?? this.headline,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      primaryCraft: primaryCraft ?? this.primaryCraft,
      secondaryCrafts: secondaryCrafts ?? this.secondaryCrafts,
      guildId: guildId ?? this.guildId,
      isGuildVerified: isGuildVerified ?? this.isGuildVerified,
      hubLocation: hubLocation ?? this.hubLocation,
      dailyCallSheetRate: dailyCallSheetRate ?? this.dailyCallSheetRate,
      immediateAvailability: immediateAvailability ?? this.immediateAvailability,
      verifiedGear: verifiedGear ?? this.verifiedGear,
      skillTags: skillTags ?? this.skillTags,
      filmography: filmography ?? this.filmography,
      connectionsCount: connectionsCount ?? this.connectionsCount,
      endorsementsCount: endorsementsCount ?? this.endorsementsCount,
      isConnected: nextConnected,
      connectionId: connectionId ?? this.connectionId,
      connectionStatus: nextStatus,
    );
  }

  factory TalentProfile.fromJson(Map<String, dynamic> json) {
    final rawName = json['full_name']?.toString() ?? 'Talent';
    final parts = rawName.trim().split(RegExp(r'\s+'));
    String avatar = 'CC';
    if (parts.length >= 2) {
      avatar = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      avatar = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }

    List<String> parsedSkills = [];
    if (json['skills'] is List) {
      parsedSkills = (json['skills'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<String> parsedSecondary = [];
    if (json['secondary_crafts'] is List) {
      parsedSecondary = (json['secondary_crafts'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<String> parsedGear = [];
    if (json['verified_gear'] is List) {
      parsedGear = (json['verified_gear'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<VerifiedFilmCredit> parsedCredits = [];
    if (json['filmography'] is List) {
      parsedCredits = (json['filmography'] as List)
          .whereType<Map<String, dynamic>>()
          .map(VerifiedFilmCredit.fromJson)
          .toList();
    }

    return TalentProfile(
      id: json['id']?.toString() ?? '',
      fullName: rawName,
      handle: json['handle']?.toString() ?? '@${rawName.toLowerCase().replaceAll(' ', '')}',
      headline: json['headline']?.toString() ?? (json['role'] != null ? '${json['role']} | Film & Television' : ''),
      avatarUrl: json['avatar_url']?.toString() ?? avatar,
      primaryCraft: json['role']?.toString() ?? '',
      secondaryCrafts: parsedSecondary,
      guildId: json['guild_id']?.toString() ?? '',
      isGuildVerified: json['is_guild_verified'] == true || json['is_verified'] == true,
      hubLocation: json['location']?.toString() ?? '',
      dailyCallSheetRate: json['daily_call_sheet_rate']?.toString() ?? '',
      immediateAvailability: json['immediate_availability']?.toString() ?? '',
      verifiedGear: parsedGear,
      skillTags: parsedSkills,
      filmography: parsedCredits,
      connectionsCount: (json['connections_count'] as num?)?.toInt() ?? 0,
      endorsementsCount: (json['endorsements_count'] as num?)?.toInt(),
      isConnected: json['is_connected'] == true || json['connection_status'] == 'accepted',
      connectionId: json['connection_id']?.toString(),
      connectionStatus: (json['is_connected'] == true || json['connection_status'] == 'accepted')
          ? ConnectionStatus.connected
          : (json['connection_status'] == 'pending'
              ? ConnectionStatus.pendingSent
              : ConnectionStatus.none),
    );
  }
}

class CineConnection {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TalentProfile? sender;
  final TalentProfile? receiver;

  const CineConnection({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sender,
    this.receiver,
  });

  factory CineConnection.fromJson(Map<String, dynamic> json) {
    return CineConnection(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sender: json['sender'] is Map<String, dynamic>
          ? TalentProfile.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      receiver: json['receiver'] is Map<String, dynamic>
          ? TalentProfile.fromJson(json['receiver'] as Map<String, dynamic>)
          : null,
    );
  }
}

enum ApplicationStatus {
  submitted,
  underDirectorReview,
  shortlisted,
  callSheetHold,
  booked,
  rejected,
  unknown,
}

class ProductionJobBrief {
  final String id;
  final String studioName;
  final String studioBannerLogo;
  final String councilId; // e.g. "TFPC-2026-MMM4", "IMPPA-2026-XCL"
  final String projectTitle;
  final String targetCraft;
  final String hubLocation;
  final String compensation;
  final String shootWindow;
  final String description;
  final String screenplaySides;
  final List<String> requiredSkills;
  final int applicantsCount;
  final bool isPanIndia;
  final bool hasUserApplied;
  final ApplicationStatus applicationStatus;

  const ProductionJobBrief({
    required this.id,
    required this.studioName,
    required this.studioBannerLogo,
    required this.councilId,
    required this.projectTitle,
    required this.targetCraft,
    required this.hubLocation,
    required this.compensation,
    required this.shootWindow,
    required this.description,
    required this.screenplaySides,
    required this.requiredSkills,
    required this.applicantsCount,
    this.isPanIndia = true,
    this.hasUserApplied = false,
    this.applicationStatus = ApplicationStatus.submitted,
  });

  ProductionJobBrief copyWith({
    bool? hasUserApplied,
    ApplicationStatus? applicationStatus,
    int? applicantsCount,
  }) {
    return ProductionJobBrief(
      id: id,
      studioName: studioName,
      studioBannerLogo: studioBannerLogo,
      councilId: councilId,
      projectTitle: projectTitle,
      targetCraft: targetCraft,
      hubLocation: hubLocation,
      compensation: compensation,
      shootWindow: shootWindow,
      description: description,
      screenplaySides: screenplaySides,
      requiredSkills: requiredSkills,
      applicantsCount: applicantsCount ?? this.applicantsCount,
      isPanIndia: isPanIndia,
      hasUserApplied: hasUserApplied ?? this.hasUserApplied,
      applicationStatus: applicationStatus ?? this.applicationStatus,
    );
  }

  static ApplicationStatus parseStatus(String? status) {
    if (status == null || status.trim().isEmpty) {
      return ApplicationStatus.unknown;
    }
    switch (status.trim().toLowerCase()) {
      case 'submitted':
      case 'received':
        return ApplicationStatus.submitted;
      case 'under_review':
      case 'underdirectorreview':
      case 'in_review':
        return ApplicationStatus.underDirectorReview;
      case 'shortlisted':
        return ApplicationStatus.shortlisted;
      case 'call_sheet_hold':
      case 'callsheethold':
      case 'hold':
        return ApplicationStatus.callSheetHold;
      case 'booked':
      case 'accepted':
      case 'contracted':
        return ApplicationStatus.booked;
      case 'rejected':
      case 'declined':
        return ApplicationStatus.rejected;
      default:
        return ApplicationStatus.unknown;
    }
  }

  factory ProductionJobBrief.fromJson(
    Map<String, dynamic> json, {
    bool? hasUserApplied,
    ApplicationStatus? applicationStatus,
  }) {
    final rawId = json['id']?.toString() ?? '';
    final title = json['title']?.toString() ?? 'Untitled Opportunity';
    final roleType = json['role_type']?.toString() ?? 'General Talent';
    final location = json['location']?.toString() ?? 'Pan-India';
    final comp = json['compensation']?.toString() ?? 'Industry Standard Scale';
    final reqs = json['requirements']?.toString() ?? '';
    final deadline = json['deadline']?.toString();
    final phId = json['production_house_id']?.toString();

    // Required skills
    List<String> skills = [];
    if (json['skills'] is List) {
      skills = (json['skills'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (skills.isEmpty && reqs.isNotEmpty) {
      if (reqs.contains(',')) {
        skills = reqs
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s.length <= 40)
            .take(5)
            .toList();
      } else {
        skills = [roleType];
      }
    }
    if (skills.isEmpty) {
      skills = [roleType];
    }

    final studio = json['studio_name']?.toString() ??
        (phId != null && phId.length >= 8
            ? 'Production Studio #${phId.substring(0, 8).toUpperCase()}'
            : 'Verified Production House');

    final studioLogo = json['studio_banner_logo']?.toString() ??
        (studio.length >= 3 ? studio.substring(0, 3).toUpperCase() : 'PH');

    final council = json['council_id']?.toString() ??
        (phId != null && phId.length >= 8
            ? 'PROD-${phId.substring(0, 8).toUpperCase()}'
            : 'VERIFIED-2026');

    final shootWin = deadline != null && deadline.isNotEmpty
        ? 'Deadline: $deadline'
        : (json['shoot_window']?.toString() ?? 'Upcoming Production');

    final sides = json['screenplay_sides']?.toString() ??
        (reqs.isNotEmpty ? reqs : 'Screenplay sides to be provided upon audition invitation.');

    final isPan = location.toLowerCase().contains('pan-india') || location.toLowerCase().contains('india');

    return ProductionJobBrief(
      id: rawId,
      studioName: studio,
      studioBannerLogo: studioLogo,
      councilId: council,
      projectTitle: title,
      targetCraft: roleType,
      hubLocation: location,
      compensation: comp,
      shootWindow: shootWin,
      description: reqs.isNotEmpty ? reqs : title,
      screenplaySides: sides,
      requiredSkills: skills,
      applicantsCount: (json['applicants_count'] as num?)?.toInt() ?? 0,
      isPanIndia: isPan,
      hasUserApplied: hasUserApplied ?? (json['has_user_applied'] == true),
      applicationStatus: applicationStatus ?? parseStatus(json['status']?.toString()),
    );
  }
}

class CineFeedPost {
  final String id;
  final String authorName;
  final String authorCraft;
  final String authorAvatar;
  final String guildBadge;
  final String timestamp;
  final String contentText;
  final String videoSlateTitle;
  final String smpteTimecode;
  final String currentAspect; // "2.39:1" or "16:9"
  final int likes;
  final int comments;
  final bool isLogC4Mode;
  final List<String> taggedCrafts;
  final bool isLiked;
  final bool isBookmarked;
  final String? likeInteractionId;

  const CineFeedPost({
    required this.id,
    required this.authorName,
    required this.authorCraft,
    required this.authorAvatar,
    required this.guildBadge,
    required this.timestamp,
    required this.contentText,
    required this.videoSlateTitle,
    required this.smpteTimecode,
    this.currentAspect = "2.39:1",
    required this.likes,
    required this.comments,
    this.isLogC4Mode = false,
    required this.taggedCrafts,
    this.isLiked = false,
    this.isBookmarked = false,
    this.likeInteractionId,
  });

  CineFeedPost copyWith({
    int? likes,
    int? comments,
    bool? isLogC4Mode,
    bool? isLiked,
    bool? isBookmarked,
    String? likeInteractionId,
  }) {
    return CineFeedPost(
      id: id,
      authorName: authorName,
      authorCraft: authorCraft,
      authorAvatar: authorAvatar,
      guildBadge: guildBadge,
      timestamp: timestamp,
      contentText: contentText,
      videoSlateTitle: videoSlateTitle,
      smpteTimecode: smpteTimecode,
      currentAspect: currentAspect,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isLogC4Mode: isLogC4Mode ?? this.isLogC4Mode,
      taggedCrafts: taggedCrafts,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      likeInteractionId: likeInteractionId ?? this.likeInteractionId,
    );
  }

  factory CineFeedPost.fromJson(Map<String, dynamic> json) {
    List<String> tags = [];
    if (json['tags'] is List) {
      tags = (json['tags'] as List).map((e) => e.toString()).toList();
    }

    final rawCreatedAt = json['created_at']?.toString();
    String ts = 'Just now';
    if (rawCreatedAt != null) {
      final dt = DateTime.tryParse(rawCreatedAt);
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          ts = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          ts = '${diff.inHours}h ago';
        } else {
          ts = '${diff.inDays}d ago';
        }
      }
    }

    return CineFeedPost(
      id: json['id']?.toString() ?? '',
      authorName: json['author_name']?.toString() ?? 'Filmmaker',
      authorCraft: json['author_craft']?.toString() ?? 'Direction',
      authorAvatar: json['author_avatar']?.toString() ?? 'CC',
      guildBadge: json['guild_badge']?.toString() ?? 'Verified Member',
      timestamp: ts,
      contentText: json['caption']?.toString() ?? json['content_text']?.toString() ?? '',
      videoSlateTitle: json['video_slate_title']?.toString() ?? 'SCENE TAKE / RAW',
      smpteTimecode: json['smpte_timecode']?.toString() ?? 'TC 00:00:00:00',
      currentAspect: json['aspect_ratio']?.toString() ?? '2.39:1',
      likes: (json['likes_count'] as num?)?.toInt() ?? (json['likes'] as num?)?.toInt() ?? 0,
      comments: (json['comments_count'] as num?)?.toInt() ?? (json['comments'] as num?)?.toInt() ?? 0,
      taggedCrafts: tags.isNotEmpty ? tags : const ['Direction', 'Cinematography'],
      isLiked: json['is_liked'] == true,
      isBookmarked: json['is_bookmarked'] == true,
      likeInteractionId: json['like_interaction_id']?.toString(),
    );
  }
}

class CineReelItem {
  final String id;
  final String? userId;
  final String? mediaUrl;
  final String? playbackUrl;
  final String creatorName;
  final String creatorCraft;
  final String creatorAvatar;
  final String title;
  final String audioTrack;
  final String smpteTimecode;
  final String craftSpecialty;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isBookmarked;
  final String reelType;

  const CineReelItem({
    required this.id,
    this.userId,
    this.mediaUrl,
    this.playbackUrl,
    required this.creatorName,
    required this.creatorCraft,
    required this.creatorAvatar,
    required this.title,
    required this.audioTrack,
    required this.smpteTimecode,
    required this.craftSpecialty,
    required this.likesCount,
    required this.commentsCount,
    this.isLiked = false,
    this.isBookmarked = false,
    required this.reelType,
  });

  CineReelItem copyWith({
    String? playbackUrl,
    bool? isLiked,
    int? likesCount,
    bool? isBookmarked,
  }) {
    return CineReelItem(
      id: id,
      userId: userId,
      mediaUrl: mediaUrl,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      creatorName: creatorName,
      creatorCraft: creatorCraft,
      creatorAvatar: creatorAvatar,
      title: title,
      audioTrack: audioTrack,
      smpteTimecode: smpteTimecode,
      craftSpecialty: craftSpecialty,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      reelType: reelType,
    );
  }

  factory CineReelItem.fromJson(Map<String, dynamic> json) {
    return CineReelItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      mediaUrl: json['media_url']?.toString(),
      playbackUrl: json['playback_url']?.toString() ?? json['media_url']?.toString(),
      creatorName: json['creator_name']?.toString() ?? 'Cinematographer',
      creatorCraft: json['creator_craft']?.toString() ?? 'Camera Dept',
      creatorAvatar: json['creator_avatar']?.toString() ?? 'CC',
      title: json['title']?.toString() ?? 'Untitled Reel',
      audioTrack: json['audio_track']?.toString() ?? 'Original Soundtrack',
      smpteTimecode: json['smpte_timecode']?.toString() ?? '00:00:00:00',
      craftSpecialty: json['craft_specialty']?.toString() ?? 'Anamorphic 2.39:1',
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      isLiked: json['is_liked'] == true,
      isBookmarked: json['is_bookmarked'] == true,
      reelType: json['reel_type']?.toString() ?? 'Cinematography Showreel',
    );
  }
}

class OnSetStory {
  final String id;
  final String? userId;
  final String? mediaUrl;
  final String? playbackUrl;
  final String creatorName;
  final String initials;
  final String craftBadge;
  final String location;
  final String storyCaption;
  final String timeAgo;
  final bool hasUnseen;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const OnSetStory({
    required this.id,
    this.userId,
    this.mediaUrl,
    this.playbackUrl,
    required this.creatorName,
    required this.initials,
    required this.craftBadge,
    required this.location,
    required this.storyCaption,
    required this.timeAgo,
    this.hasUnseen = true,
    this.createdAt,
    this.expiresAt,
  });

  OnSetStory copyWith({
    String? id,
    String? userId,
    String? mediaUrl,
    String? playbackUrl,
    String? creatorName,
    String? initials,
    String? craftBadge,
    String? location,
    String? storyCaption,
    String? timeAgo,
    bool? hasUnseen,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return OnSetStory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      creatorName: creatorName ?? this.creatorName,
      initials: initials ?? this.initials,
      craftBadge: craftBadge ?? this.craftBadge,
      location: location ?? this.location,
      storyCaption: storyCaption ?? this.storyCaption,
      timeAgo: timeAgo ?? this.timeAgo,
      hasUnseen: hasUnseen ?? this.hasUnseen,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  factory OnSetStory.fromJson(Map<String, dynamic> json) {
    return OnSetStory(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      mediaUrl: json['media_url']?.toString(),
      playbackUrl: json['playback_url']?.toString() ?? json['media_url']?.toString(),
      creatorName: json['creator_name']?.toString() ?? 'Talent',
      initials: json['initials']?.toString() ?? 'CC',
      craftBadge: json['craft_badge']?.toString() ?? 'Crew Member',
      location: json['location']?.toString() ?? 'Film Set',
      storyCaption: json['caption']?.toString() ?? json['story_caption']?.toString() ?? '',
      timeAgo: json['time_ago']?.toString() ?? 'Recently',
      hasUnseen: json['has_unseen'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
    );
  }
}

class CineNotification {
  final String id;
  final String title;
  final String description;
  final String timeAgo;
  final String avatarInitials;
  final String type; // shortlist, castingMatch, auditionStatus, hold, endorsement, application, collaboration, message, etc.
  final bool isRead;
  final DateTime? createdAt;

  const CineNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.avatarInitials,
    required this.type,
    this.isRead = false,
    this.createdAt,
  });

  CineNotification copyWith({
    String? id,
    String? title,
    String? description,
    String? timeAgo,
    String? avatarInitials,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return CineNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      timeAgo: timeAgo ?? this.timeAgo,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String _calculateTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static String _deriveInitials(String title, String type) {
    final clean = title.trim();
    if (clean.isNotEmpty) {
      final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.length >= 2) {
        final first = words[0][0].toUpperCase();
        final second = words[1][0].toUpperCase();
        if (RegExp(r'[A-Z]').hasMatch(first) && RegExp(r'[A-Z]').hasMatch(second)) {
          return '$first$second';
        }
      } else if (words.isNotEmpty && words[0].length >= 2) {
        final sub = words[0].substring(0, 2).toUpperCase();
        if (RegExp(r'^[A-Z]{2}$').hasMatch(sub)) {
          return sub;
        }
      }
    }
    switch (type.toLowerCase()) {
      case 'application':
      case 'auditionstatus':
        return 'AP';
      case 'castingmatch':
      case 'shortlist':
        return 'CC';
      case 'collaboration':
        return 'CL';
      case 'message':
        return 'DM';
      case 'connection':
      case 'endorsement':
        return 'NT';
      default:
        return 'CC';
    }
  }

  factory CineNotification.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final rawTitle = json['title']?.toString() ?? 'Notification';
    final rawMessage = json['message']?.toString() ?? json['description']?.toString() ?? '';
    final rawType = json['type']?.toString() ?? 'system';
    final rawIsRead = json['is_read'] == true;

    DateTime? createdAt;
    if (json['created_at'] != null) {
      createdAt = DateTime.tryParse(json['created_at'].toString());
    }
    final date = createdAt ?? DateTime.now();

    return CineNotification(
      id: rawId,
      title: rawTitle,
      description: rawMessage,
      timeAgo: _calculateTimeAgo(date),
      avatarInitials: _deriveInitials(rawTitle, rawType),
      type: rawType,
      isRead: rawIsRead,
      createdAt: date,
    );
  }
}

class CineChatMessage {
  final String id;
  final String senderName;
  final String text;
  final String time;
  final bool isMe;

  const CineChatMessage({
    required this.id,
    required this.senderName,
    required this.text,
    required this.time,
    required this.isMe,
  });
}

class CineChatThread {
  final String id;
  final String participantName;
  final String participantCraft;
  final String avatar;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final List<CineChatMessage> messages;

  const CineChatThread({
    required this.id,
    required this.participantName,
    required this.participantCraft,
    required this.avatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = true,
    this.messages = const [],
  });

  CineChatThread copyWith({
    String? lastMessage,
    String? lastMessageTime,
    int? unreadCount,
    List<CineChatMessage>? messages,
  }) {
    return CineChatThread(
      id: id,
      participantName: participantName,
      participantCraft: participantCraft,
      avatar: avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline,
      messages: messages ?? this.messages,
    );
  }
}
