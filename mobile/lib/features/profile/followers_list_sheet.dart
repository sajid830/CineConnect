import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

enum FollowListType { followers, following }

class FollowersListSheet extends StatefulWidget {
  final String targetUserId;
  final String userName;
  final FollowListType initialType;
  final int initialFollowersCount;
  final int initialFollowingCount;
  final VoidCallback? onFollowCountChanged;

  const FollowersListSheet({
    super.key,
    required this.targetUserId,
    required this.userName,
    this.initialType = FollowListType.followers,
    this.initialFollowersCount = 0,
    this.initialFollowingCount = 0,
    this.onFollowCountChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetUserId,
    required String userName,
    FollowListType initialType = FollowListType.followers,
    int followersCount = 0,
    int followingCount = 0,
    VoidCallback? onFollowCountChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FollowersListSheet(
        targetUserId: targetUserId,
        userName: userName,
        initialType: initialType,
        initialFollowersCount: followersCount,
        initialFollowingCount: followingCount,
        onFollowCountChanged: onFollowCountChanged,
      ),
    );
  }

  @override
  State<FollowersListSheet> createState() => _FollowersListSheetState();
}

class _FollowersListSheetState extends State<FollowersListSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ApiClient _apiClient = ApiClient();

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _loadingFollowers = true;
  bool _loadingFollowing = true;
  String? _followersError;
  String? _followingError;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialType == FollowListType.followers ? 0 : 1,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchFollowers();
    _fetchFollowing();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFollowers() async {
    setState(() {
      _loadingFollowers = true;
      _followersError = null;
    });
    try {
      final res = await _apiClient.get(ApiEndpoints.userFollowers(widget.targetUserId));
      if (res is List) {
        _followers = res.whereType<Map<String, dynamic>>().toList();
      } else {
        _followers = [];
      }
    } catch (e) {
      _followersError = 'Could not load followers';
    } finally {
      if (mounted) {
        setState(() => _loadingFollowers = false);
      }
    }
  }

  Future<void> _fetchFollowing() async {
    setState(() {
      _loadingFollowing = true;
      _followingError = null;
    });
    try {
      final res = await _apiClient.get(ApiEndpoints.userFollowing(widget.targetUserId));
      if (res is List) {
        _following = res.whereType<Map<String, dynamic>>().toList();
      } else {
        _following = [];
      }
    } catch (e) {
      _followingError = 'Could not load following';
    } finally {
      if (mounted) {
        setState(() => _loadingFollowing = false);
      }
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> item) async {
    final userId = item['user_id']?.toString();
    if (userId == null || userId.isEmpty) return;

    final wasFollowing = item['is_following'] == true;
    final newFollowingState = !wasFollowing;

    // Instant optimistic update
    setState(() {
      item['is_following'] = newFollowingState;
      // Also sync across the other tab if the user appears in both
      for (final f in _followers) {
        if (f['user_id']?.toString() == userId) {
          f['is_following'] = newFollowingState;
        }
      }
      for (final f in _following) {
        if (f['user_id']?.toString() == userId) {
          f['is_following'] = newFollowingState;
        }
      }
    });

    widget.onFollowCountChanged?.call();

    try {
      await _apiClient.post(ApiEndpoints.toggleFollow(userId));
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          item['is_following'] = wasFollowing;
          for (final f in _followers) {
            if (f['user_id']?.toString() == userId) {
              f['is_following'] = wasFollowing;
            }
          }
          for (final f in _following) {
            if (f['user_id']?.toString() == userId) {
              f['is_following'] = wasFollowing;
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow status')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filterList(List<Map<String, dynamic>> list) {
    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.toLowerCase().trim();
    return list.where((item) {
      final name = (item['full_name'] ?? '').toString().toLowerCase();
      final role = (item['role'] ?? '').toString().toLowerCase();
      final handle = (item['handle'] ?? '').toString().toLowerCase();
      final loc = (item['location'] ?? '').toString().toLowerCase();
      return name.contains(q) || role.contains(q) || handle.contains(q) || loc.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ApiClient.currentUserId;
    final followersCount = _loadingFollowers ? widget.initialFollowersCount : _followers.length;
    final followingCount = _loadingFollowing ? widget.initialFollowingCount : _following.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: CineColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border(
          top: BorderSide(color: CineColors.border, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: CineColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CineColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: CineColors.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: CineColors.border, width: 0.8)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: CineColors.gold,
              indicatorWeight: 2.5,
              labelColor: CineColors.gold,
              unselectedLabelColor: CineColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: '$followersCount Followers'),
                Tab(text: '$followingCount Following'),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search people and studios...',
                hintStyle: const TextStyle(color: CineColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: CineColors.textMuted, size: 18),
                filled: true,
                fillColor: CineColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: CineColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: CineColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: CineColors.gold, width: 1.2),
                ),
              ),
            ),
          ),

          // Tab View Lists
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(
                  items: _filterList(_followers),
                  isLoading: _loadingFollowers,
                  error: _followersError,
                  onRetry: _fetchFollowers,
                  emptyMessage: 'No followers yet',
                  currentUserId: currentUserId,
                ),
                _buildList(
                  items: _filterList(_following),
                  isLoading: _loadingFollowing,
                  error: _followingError,
                  onRetry: _fetchFollowing,
                  emptyMessage: 'Not following anyone yet',
                  currentUserId: currentUserId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList({
    required List<Map<String, dynamic>> items,
    required bool isLoading,
    required String? error,
    required VoidCallback onRetry,
    required String emptyMessage,
    required String? currentUserId,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: CineColors.gold),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: CineColors.textMuted, size: 36),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(color: CineColors.textMuted)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onRetry,
              child: const Text('Try Again', style: TextStyle(color: CineColors.gold)),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, color: CineColors.textMuted, size: 42),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty ? 'No matches found' : emptyMessage,
              style: const TextStyle(color: CineColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: CineColors.border),
      itemBuilder: (context, i) {
        final item = items[i];
        final id = item['user_id']?.toString() ?? '';
        final name = item['full_name']?.toString() ?? 'Cinema Professional';
        final role = item['role']?.toString() ?? 'Filmmaker';
        final location = item['location']?.toString();
        final avatar = item['avatar_url']?.toString();
        final isFollowing = item['is_following'] == true;
        final isSelf = currentUserId != null && currentUserId == id;

        // Initials
        final parts = name.trim().split(RegExp(r'\s+'));
        final initials = parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : (parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'CC');

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: CineColors.gold.withValues(alpha: 0.18),
                backgroundImage: (avatar != null && avatar.startsWith('http'))
                    ? NetworkImage(avatar)
                    : null,
                child: (avatar == null || !avatar.startsWith('http'))
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: CineColors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: CineColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location != null && location.isNotEmpty ? '$role • $location' : role,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: CineColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isSelf)
                ElevatedButton(
                  onPressed: () => _toggleFollow(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? CineColors.surfaceElevated : CineColors.gold,
                    foregroundColor: isFollowing ? Colors.white : Colors.black,
                    side: isFollowing ? const BorderSide(color: CineColors.border) : BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isFollowing ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
