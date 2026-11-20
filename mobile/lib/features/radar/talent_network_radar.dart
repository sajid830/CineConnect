import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/craft_models.dart';
import '../../core/state/app_state.dart';

class TalentNetworkRadarView extends StatefulWidget {
  final CineAppState appState;

  const TalentNetworkRadarView({super.key, required this.appState});

  @override
  State<TalentNetworkRadarView> createState() => _TalentNetworkRadarViewState();
}

class _TalentNetworkRadarViewState extends State<TalentNetworkRadarView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCraft = 'All';

  static const List<String> _craftFilters = [
    'All',
    'Cinematography',
    'VFX',
    'Stunts',
    'Sound',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesCraft(TalentProfile peer) {
    switch (_selectedCraft) {
      case 'Cinematography':
        return peer.primaryCraft.toLowerCase().contains('cinemat');
      case 'VFX':
        return peer.primaryCraft.toLowerCase().contains('vfx') ||
            peer.primaryCraft.toLowerCase().contains('virtual');
      case 'Stunts':
        return peer.primaryCraft.toLowerCase().contains('stunt');
      case 'Sound':
        return peer.primaryCraft.toLowerCase().contains('sound');
      default:
        return true;
    }
  }

  List<TalentProfile> get _peers {
    final q = _searchQuery.toLowerCase().trim();
    return widget.appState.talentNetwork.where((peer) {
      final matchesCraft = _matchesCraft(peer);
      if (q.isEmpty) return matchesCraft;
      final matchesQuery = peer.fullName.toLowerCase().contains(q) ||
          peer.handle.toLowerCase().contains(q) ||
          peer.primaryCraft.toLowerCase().contains(q) ||
          peer.hubLocation.toLowerCase().contains(q) ||
          peer.verifiedGear.any((gear) => gear.toLowerCase().contains(q));
      return matchesCraft && matchesQuery;
    }).toList();
  }

  void _inspectPeerSlate(TalentProfile peer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13141B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: CineColors.gold, width: 1.2),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: CineColors.gold,
                      child: Text(
                        peer.avatarUrl,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                        ),
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
                                  peer.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: CineColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, size: 15, color: CineColors.gold),
                            ],
                          ),
                          Text(
                            peer.primaryCraft,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: CineColors.goldLight),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: CineColors.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  peer.headline,
                  style: const TextStyle(fontSize: 12, color: CineColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CineColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CineColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DAY RATE',
                              style: TextStyle(
                                fontSize: 9,
                                color: CineColors.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              peer.dailyCallSheetRate,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: CineColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'AVAILABILITY',
                              style: TextStyle(
                                fontSize: 9,
                                color: CineColors.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              peer.immediateAvailability,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: CineColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'VERIFIED GEAR',
                  style: TextStyle(
                    fontSize: 10,
                    color: CineColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  peer.verifiedGear.join(' • '),
                  style: const TextStyle(fontSize: 11.5, color: CineColors.textPrimary),
                ),
                const SizedBox(height: 14),
                const Text(
                  'FILM CREDITS',
                  style: TextStyle(
                    fontSize: 10,
                    color: CineColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...peer.filmography.map(
                  (credit) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.movie_outlined, size: 14, color: CineColors.gold),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${credit.filmTitle} (${credit.releaseYear}) — ${credit.craftRole}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CineColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.verified, size: 14, color: CineColors.gold),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.appState.togglePeerConnection(peer.id);
                      Navigator.of(ctx).pop();
                    },
                    icon: Icon(peer.isConnected ? Icons.check : Icons.person_add, size: 16),
                    label: Text(
                      peer.isConnected ? 'Connected' : 'Send collaboration request',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final peers = _peers;
    final isSearching = _searchQuery.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(fontSize: 13, color: CineColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search talent, craft or gear',
                hintStyle: const TextStyle(fontSize: 12.5, color: CineColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: CineColors.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: CineColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: CineColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _craftFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final label = _craftFilters[index];
                final selected = _selectedCraft == label;
                return InkWell(
                  onTap: () => setState(() => _selectedCraft = label),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? CineColors.gold : CineColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? CineColors.gold : CineColors.border,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.black : CineColors.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  isSearching ? 'Results' : 'Explore',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CineColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${peers.length} talent',
                  style: const TextStyle(
                    fontSize: 11,
                    color: CineColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (peers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 44, color: CineColors.textMuted),
                    SizedBox(height: 10),
                    Text(
                      'No talent found',
                      style: TextStyle(color: CineColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else if (isSearching)
            ...peers.map((peer) => _searchResultRow(peer))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: peers.length,
              itemBuilder: (context, index) => _exploreTile(peers[index], index),
            ),
        ],
      ),
    );
  }

  Widget _searchResultRow(TalentProfile peer) {
    return InkWell(
      onTap: () => _inspectPeerSlate(peer),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: CineColors.surfaceElevated,
              child: Text(
                peer.avatarUrl,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: CineColors.gold,
                ),
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
                          peer.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: CineColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.verified, size: 13, color: CineColors.gold),
                    ],
                  ),
                  Text(
                    peer.primaryCraft,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: CineColors.goldLight),
                  ),
                  Text(
                    peer.hubLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: CineColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _inspectPeerSlate(peer),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: CineColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              ),
              child: const Text(
                'View',
                style: TextStyle(fontSize: 11, color: CineColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exploreTile(TalentProfile peer, int index) {
    final gradients = [
      [const Color(0xFF2A2412), const Color(0xFF141419)],
      [const Color(0xFF102A2A), const Color(0xFF141419)],
      [const Color(0xFF2A1020), const Color(0xFF141419)],
      [const Color(0xFF1A1A2A), const Color(0xFF141419)],
    ];

    return GestureDetector(
      onTap: () => _inspectPeerSlate(peer),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradients[index % gradients.length],
          ),
          border: Border.all(color: CineColors.border, width: 0.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                peer.avatarUrl,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: CineColors.gold,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 18, 6, 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peer.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: CineColors.textPrimary,
                      ),
                    ),
                    Text(
                      peer.primaryCraft,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: CineColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (peer.isConnected)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.verified, size: 13, color: CineColors.gold),
              ),
          ],
        ),
      ),
    );
  }
}
