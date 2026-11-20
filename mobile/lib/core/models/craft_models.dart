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
    this.verifiedByGuild = true,
    this.guildVerificationHash = 'SHA256:0x8F9C...A12',
  });
}

class TalentProfile {
  final String id;
  final String fullName;
  final String handle;
  final String headline;
  final String avatarUrl;
  final String primaryCraft;
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
  final int endorsementsCount;
  final bool isConnected;

  const TalentProfile({
    required this.id,
    required this.fullName,
    required this.handle,
    required this.headline,
    required this.avatarUrl,
    required this.primaryCraft,
    required this.secondaryCrafts,
    required this.guildId,
    this.isGuildVerified = true,
    required this.hubLocation,
    required this.dailyCallSheetRate,
    required this.immediateAvailability,
    required this.verifiedGear,
    required this.skillTags,
    required this.filmography,
    this.connectionsCount = 542,
    this.endorsementsCount = 98,
    this.isConnected = false,
  });

  TalentProfile copyWith({
    bool? isConnected,
    int? connectionsCount,
  }) {
    return TalentProfile(
      id: id,
      fullName: fullName,
      handle: handle,
      headline: headline,
      avatarUrl: avatarUrl,
      primaryCraft: primaryCraft,
      secondaryCrafts: secondaryCrafts,
      guildId: guildId,
      isGuildVerified: isGuildVerified,
      hubLocation: hubLocation,
      dailyCallSheetRate: dailyCallSheetRate,
      immediateAvailability: immediateAvailability,
      verifiedGear: verifiedGear,
      skillTags: skillTags,
      filmography: filmography,
      connectionsCount: connectionsCount ?? this.connectionsCount,
      endorsementsCount: endorsementsCount,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

enum ApplicationStatus {
  submitted,
  underDirectorReview,
  shortlisted,
  callSheetHold,
  booked,
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
  });
}

class CineReelItem {
  final String id;
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
    bool? isLiked,
    int? likesCount,
    bool? isBookmarked,
  }) {
    return CineReelItem(
      id: id,
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
}

class OnSetStory {
  final String id;
  final String creatorName;
  final String initials;
  final String craftBadge;
  final String location;
  final String storyCaption;
  final String timeAgo;
  final bool hasUnseen;

  const OnSetStory({
    required this.id,
    required this.creatorName,
    required this.initials,
    required this.craftBadge,
    required this.location,
    required this.storyCaption,
    required this.timeAgo,
    this.hasUnseen = true,
  });
}

class CineNotification {
  final String id;
  final String title;
  final String description;
  final String timeAgo;
  final String avatarInitials;
  final String type; // shortlist, castingMatch, auditionStatus, hold, endorsement
  final bool isRead;

  const CineNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.avatarInitials,
    required this.type,
    this.isRead = false,
  });

  CineNotification copyWith({bool? isRead}) {
    return CineNotification(
      id: id,
      title: title,
      description: description,
      timeAgo: timeAgo,
      avatarInitials: avatarInitials,
      type: type,
      isRead: isRead ?? this.isRead,
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
