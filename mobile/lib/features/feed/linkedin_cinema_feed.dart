import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';

class LinkedInCinemaFeed extends StatefulWidget {
  final CineAppState appState;

  const LinkedInCinemaFeed({super.key, required this.appState});

  @override
  State<LinkedInCinemaFeed> createState() => _LinkedInCinemaFeedState();
}

class _LinkedInCinemaFeedState extends State<LinkedInCinemaFeed> {
  // Map of post IDs to their current aspect ratio (2.39:1 vs 16:9)
  final Map<String, bool> _isScopeMode = {};
  // Map of post IDs to like state
  final Map<String, bool> _likedPosts = {};

  final Map<String, bool> _followedAuthors = {};
  final Map<String, bool> _bookmarkedPosts = {};

  void _showTimecodeCritiqueDialog(CineFeedPost post) {
    final tcController = TextEditingController(text: post.smpteTimecode);
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14151C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CineColors.gold, width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: CineColors.gold, size: 20),
            SizedBox(width: 8),
            Text('Pin SMPTE Timecode Critique', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Post: ${post.authorName} • ${post.videoSlateTitle}',
                style: const TextStyle(fontSize: 12, color: CineColors.textMuted)),
            const SizedBox(height: 12),
            const Text('Frame-Accurate Timecode (SMPTE 24fps):',
                style: TextStyle(fontSize: 11.5, color: CineColors.gold)),
            const SizedBox(height: 4),
            TextField(
              controller: tcController,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Technical / Creative Critique Note:',
                style: TextStyle(fontSize: 11.5, color: CineColors.textMuted)),
            const SizedBox(height: 4),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Masterful shadow density at T2.0; subtle blue flare roll-off.',
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: CineColors.surfaceElevated,
                  content: Text(
                    'Timecode critique pinned at ${tcController.text} on 24fps Master Ledger!',
                    style: const TextStyle(color: CineColors.gold),
                  ),
                ),
              );
            },
            child: const Text('Pin to Master Ledger'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        // Section Header matching Screenshot 1
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.movie_filter_outlined, color: CineColors.gold, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Talent Activity & Showreels',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: CineColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CineColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CineColors.border),
                ),
                child: Text(
                  '${widget.appState.feedPosts.length} Posts',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: CineColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Posts List
        ...widget.appState.feedPosts.map((post) {
          final isScope = _isScopeMode[post.id] ?? true;
          final isLiked = _likedPosts[post.id] ?? false;
          final isFollowed = _followedAuthors[post.id] ?? false;
          final isBookmarked = _bookmarkedPosts[post.id] ?? false;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              color: CineColors.surfaceCard,
              border: Border(
                top: BorderSide(color: CineColors.border, width: 0.8),
                bottom: BorderSide(color: CineColors.border, width: 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: CineColors.surfaceElevated,
                        child: Text(
                          post.authorAvatar,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: CineColors.gold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    post.authorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: CineColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: CineColors.gold.withValues(alpha: 0.6), width: 0.8),
                                  ),
                                  child: Text(
                                    post.id == 'post-1' ? 'Method Actress' : 'Lead Actor & Stunts',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: CineColors.gold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post.id == 'post-1' ? '2h ago' : '5h ago',
                              style: const TextStyle(fontSize: 11, color: CineColors.textMuted),
                            ),
                          ],
                        ),
                      ),

                      // + Follow button (Matching Screenshot 1)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _followedAuthors[post.id] = !isFollowed;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFollowed ? CineColors.gold : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: CineColors.gold, width: 0.9),
                          ),
                          child: Text(
                            isFollowed ? 'Following' : '+ Follow',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isFollowed ? Colors.black : CineColors.gold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.more_horiz_rounded, color: CineColors.textMuted),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                // Post Body Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    post.contentText,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: CineColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Video / Slate Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CineColors.border),
                  ),
                  child: Column(
                    children: [
                      // Video Slate Area
                      Container(
                        height: isScope ? 175 : 195,
                        width: double.infinity,
                        color: const Color(0xFF0F1015),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Clapperboard watermark
                            Icon(
                              Icons.movie_creation_outlined,
                              size: 72,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            // Top Tag Pill
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: CineColors.gold.withValues(alpha: 0.7), width: 0.8),
                                ),
                                child: Text(
                                  post.id == 'post-1' ? 'WRAP PARTY & BTS' : 'AUDITION PREPARATION',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: CineColors.gold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            // Center Play Button & Timecode
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: CineColors.gold.withValues(alpha: 0.85),
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                                ),
                              ],
                            ),
                            // Bottom Title Bar
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.9),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post.videoSlateTitle,
                                      style: const TextStyle(
                                        color: CineColors.textPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      post.id == 'post-1'
                                          ? 'Dir. Elena Vance • DP David Kim'
                                          : 'Sequence 12B • Choreography Rehearsal',
                                      style: const TextStyle(
                                        color: CineColors.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Icons Row: Heart, Comment, Share, Bookmark (Matching Screenshot 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      // Heart Like
                      InkWell(
                        onTap: () {
                          setState(() {
                            _likedPosts[post.id] = !isLiked;
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite_rounded : Icons.favorite_rounded,
                              size: 20,
                              color: CineColors.gold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(post.id == 'post-1' ? 142 : 98) + (isLiked ? 1 : 0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CineColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Comment
                      InkWell(
                        onTap: () => _showTimecodeCritiqueDialog(post),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 19,
                              color: CineColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              post.id == 'post-1' ? '3' : '2',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: CineColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Share Arrow
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: CineColors.surfaceElevated,
                              content: Text(
                                'Showreel link copied to clipboard for casting directors!',
                                style: TextStyle(color: CineColors.gold),
                              ),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.send_rounded,
                          size: 19,
                          color: CineColors.textMuted,
                        ),
                      ),

                      const Spacer(),

                      // Crew ledger button
                      InkWell(
                        onTap: () => _showCrewLedgerBottomSheet(context, post),
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline_rounded, size: 16, color: CineColors.gold),
                            const SizedBox(width: 4),
                            Text(
                              'Crew (${post.taggedCrafts.length})',
                              style: const TextStyle(fontSize: 11, color: CineColors.gold, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Bookmark
                      InkWell(
                        onTap: () {
                          setState(() {
                            _bookmarkedPosts[post.id] = !isBookmarked;
                          });
                        },
                        child: Icon(
                          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 21,
                          color: isBookmarked ? CineColors.gold : CineColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showCrewLedgerBottomSheet(BuildContext context, CineFeedPost post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: CineColors.border),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Verified Crew Credits Ledger',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CineColors.gold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: CineColors.textMuted),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _crewCreditRow('Director', 'Karthik Subbaraj', 'DGA Verified'),
              _crewCreditRow('Cinematographer (DOP)', 'Maya Ray', 'ISC-9021 Verified'),
              _crewCreditRow('1st AC / Focus Puller', 'Rohan Patel', 'SICA-4401'),
              _crewCreditRow('Gaffer', 'Venkatesh Rao', 'Chief Tech Lighting'),
              _crewCreditRow('Colorist', 'Sameer Verma', 'DaVinci Certified'),
            ],
          ),
        );
      },
    );
  }

  Widget _crewCreditRow(String role, String name, String badge) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(fontSize: 11, color: CineColors.textMuted)),
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CineColors.textPrimary)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: CineColors.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: CineColors.border),
            ),
            child: Text(badge, style: const TextStyle(fontSize: 10, color: CineColors.gold)),
          ),
        ],
      ),
    );
  }
}
