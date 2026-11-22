import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';
import 'profile_settings_screen.dart';

class DigitalSlateProfileView extends StatefulWidget {
  final CineAppState appState;

  const DigitalSlateProfileView({super.key, required this.appState});

  @override
  State<DigitalSlateProfileView> createState() => _DigitalSlateProfileViewState();
}

class _DigitalSlateProfileViewState extends State<DigitalSlateProfileView> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final talent = widget.appState.talentNetwork.first;
    final postsCount = widget.appState.reels.length + widget.appState.feedPosts.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    talent.handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CineColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 15, color: CineColors.gold),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, color: CineColors.textPrimary),
                  onPressed: () => _showInfo('New post'),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.menu_rounded, color: CineColors.textPrimary),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileSettingsScreen(appState: widget.appState),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        CineColors.gold,
                        CineColors.goldLight,
                        Color(0xFFF59E0B),
                        CineColors.gold,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CineColors.gold.withValues(alpha: 0.25),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: CineColors.surface,
                    ),
                    child: Center(
                      child: Text(
                        talent.avatarUrl,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: CineColors.gold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('$postsCount', 'posts'),
                      _stat('${talent.connectionsCount}', 'connections'),
                      _stat('${talent.endorsementsCount}', 'endorsements'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    talent.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: CineColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.verified, size: 14, color: CineColors.gold),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Text(
              talent.primaryCraft,
              style: const TextStyle(fontSize: 12, color: CineColors.goldLight),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              talent.headline,
              style: const TextStyle(
                fontSize: 12,
                color: CineColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 13, color: CineColors.textMuted),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    '${talent.hubLocation} • ${talent.immediateAvailability}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: CineColors.textMuted),
                  ),
                ),
                Text(
                  talent.dailyCallSheetRate,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CineColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showInfo('Edit profile'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CineColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Edit profile',
                      style: TextStyle(fontSize: 12, color: CineColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showInfo('Share profile'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CineColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Share profile',
                      style: TextStyle(fontSize: 12, color: CineColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CineColors.border),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    color: CineColors.textPrimary,
                    onPressed: () => _showInfo('Discover people'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _highlight(Icons.movie_filter_outlined, 'Slate'),
                _highlight(Icons.camera_rounded, 'Gear'),
                _highlight(Icons.history_edu_rounded, 'Credits'),
                _highlight(Icons.auto_awesome_rounded, 'BTS'),
                _highlight(Icons.workspace_premium_outlined, 'Guild'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: CineColors.border, width: 0.8),
                bottom: BorderSide(color: CineColors.border, width: 0.8),
              ),
            ),
            child: Row(
              children: [
                _tab(Icons.grid_on_rounded, 0),
                _tab(Icons.play_circle_outline_rounded, 1),
                _tab(Icons.person_pin_outlined, 2),
              ],
            ),
          ),
          _buildGrid(talent),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: CineColors.textPrimary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: CineColors.textMuted),
        ),
      ],
    );
  }

  Widget _highlight(IconData icon, String label) {
    return GestureDetector(
      onTap: () => _showHighlight(label),
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CineColors.surfaceElevated,
                border: Border.all(color: CineColors.border, width: 1.2),
              ),
              child: Icon(icon, color: CineColors.gold, size: 24),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: CineColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(IconData icon, int index) {
    final selected = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? CineColors.gold : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: selected ? CineColors.gold : CineColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(TalentProfile talent) {
    if (_activeTab == 1) {
      final reels = widget.appState.reels;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 0.72,
        ),
        itemCount: reels.length,
        itemBuilder: (context, index) {
          final reel = reels[index];
          return _gridTile(
            icon: Icons.play_arrow_rounded,
            title: reel.title,
            subtitle: reel.reelType,
            colors: [const Color(0xFF2A2412), const Color(0xFF141419)],
            onTap: () => _showInfo(reel.title),
          );
        },
      );
    }

    if (_activeTab == 2) {
      final credits = talent.filmography;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: credits.length,
        itemBuilder: (context, index) {
          final credit = credits[index];
          return _gridTile(
            icon: Icons.verified_rounded,
            title: credit.filmTitle,
            subtitle: '${credit.releaseYear}',
            colors: [const Color(0xFF102A2A), const Color(0xFF141419)],
            onTap: () => _showInfo('${credit.filmTitle} • ${credit.craftRole}'),
          );
        },
      );
    }

    final posts = widget.appState.feedPosts;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _gridTile(
          icon: Icons.movie_creation_outlined,
          title: post.videoSlateTitle,
          subtitle: post.authorCraft,
          colors: [const Color(0xFF1A1A2A), const Color(0xFF141419)],
          onTap: () => _showInfo(post.videoSlateTitle),
        );
      },
    );
  }

  Widget _gridTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(color: CineColors.border, width: 0.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(icon, size: 28, color: CineColors.gold),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 14, 5, 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: CineColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8,
                        color: CineColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHighlight(String label) {
    final talent = widget.appState.talentNetwork.first;
    List<String> items;
    switch (label) {
      case 'Gear':
        items = talent.verifiedGear;
        break;
      case 'Credits':
        items = talent.filmography
            .map((c) => '${c.filmTitle} (${c.releaseYear}) — ${c.craftRole}')
            .toList();
        break;
      case 'Guild':
        items = [
          'Guild ID: ${talent.guildId}',
          'Guild verified: ${talent.isGuildVerified ? 'Yes' : 'Pending'}',
          'Connections: ${talent.connectionsCount}',
          'Endorsements: ${talent.endorsementsCount}',
        ];
        break;
      case 'Slate':
        items = [
          'Scene: 84A',
          'Take: 03',
          'Roll: A-01',
          'FPS: 24.00',
          'Shutter: 180°',
          'Director: Karthik Subbaraj',
        ];
        break;
      default:
        items = [
          'On-set wrap updates',
          'Camera tests & lighting setups',
          'Behind-the-scenes from recent shoots',
        ];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13141B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CineColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CineColors.textMuted),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: CineColors.gold),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: CineColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: CineColors.surfaceElevated,
        content: Text(message, style: const TextStyle(color: CineColors.gold)),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
