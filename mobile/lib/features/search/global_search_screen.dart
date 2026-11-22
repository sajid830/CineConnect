import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../../core/services/talent_api_service.dart';

/// Global Search Screen connecting to GET /api/v1/search/
/// Provides unified discovery across Talent, Studios & Production Houses, and Casting Opportunities.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TalentApiService _apiService = TalentApiService();
  Timer? _debounceTimer;

  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _productionHouses = [];
  List<Map<String, dynamic>> _opportunities = [];

  late TabController _tabController;
  final List<String> _tabs = ['All', 'Talent', 'Studios', 'Opportunities'];

  // Craft & Guild Filter Chips
  String? _selectedCraftFilter;
  bool _guildVerifiedOnly = false;

  final List<String> _craftFilters = [
    'All Crafts',
    'Cinematography',
    'Direction',
    'Acting',
    'Sound Design',
    'Editing',
    'Art Direction',
    'Screenplay',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _users = [];
        _productionHouses = [];
        _opportunities = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 380), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.searchGlobal(query);
      if (res is Map<String, dynamic>) {
        setState(() {
          _users = (res['users'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _productionHouses = (res['production_houses'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _opportunities = (res['opportunities'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load search results: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((u) {
      if (_guildVerifiedOnly && u['is_guild_verified'] != true) {
        return false;
      }
      if (_selectedCraftFilter != null &&
          _selectedCraftFilter != 'All Crafts') {
        final role = (u['role'] ?? '').toString().toLowerCase();
        final filter = _selectedCraftFilter!.toLowerCase();
        if (!role.contains(filter)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CineColors.background,
      appBar: AppBar(
        backgroundColor: CineColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: CineColors.textPrimary),
          onPressed: () => Navigator.of(context).canPop()
              ? Navigator.of(context).pop()
              : context.go('/talent'),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: CineColors.textPrimary, fontSize: 15),
          cursorColor: CineColors.gold,
          decoration: InputDecoration(
            hintText: 'Search 24-crafts talent, studios, casting calls...',
            hintStyle: const TextStyle(color: CineColors.textMuted, fontSize: 13.5),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: CineColors.textMuted, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : const Icon(Icons.search_rounded, color: CineColors.gold, size: 20),
          ),
          onChanged: _onSearchChanged,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CineColors.gold,
          labelColor: CineColors.gold,
          unselectedLabelColor: CineColors.textMuted,
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: 'All (${_filteredUsers.length + _productionHouses.length + _opportunities.length})'),
            Tab(text: 'Talent (${_filteredUsers.length})'),
            Tab(text: 'Studios (${_productionHouses.length})'),
            Tab(text: 'Castings (${_opportunities.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Craft & Guild Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Guild Verified Only', style: TextStyle(fontSize: 11.5)),
                  selected: _guildVerifiedOnly,
                  selectedColor: CineColors.gold.withValues(alpha: 0.25),
                  checkmarkColor: CineColors.gold,
                  backgroundColor: CineColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: _guildVerifiedOnly ? CineColors.gold : CineColors.textMuted,
                    fontWeight: _guildVerifiedOnly ? FontWeight.w700 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: _guildVerifiedOnly ? CineColors.gold : CineColors.border,
                  ),
                  onSelected: (val) {
                    setState(() {
                      _guildVerifiedOnly = val;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ..._craftFilters.map((craft) {
                  final isSelected = (_selectedCraftFilter == craft) ||
                      (_selectedCraftFilter == null && craft == 'All Crafts');
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(craft, style: const TextStyle(fontSize: 11.5)),
                      selected: isSelected,
                      selectedColor: CineColors.gold.withValues(alpha: 0.25),
                      backgroundColor: CineColors.surfaceElevated,
                      labelStyle: TextStyle(
                        color: isSelected ? CineColors.gold : CineColors.textMuted,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? CineColors.gold : CineColors.border,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedCraftFilter = craft == 'All Crafts' ? null : craft;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(color: CineColors.border, height: 1),

          // Search Results View
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(CineColors.gold),
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      )
                    : _searchController.text.trim().isEmpty
                        ? _buildSearchSuggestions()
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildAllTab(),
                              _buildTalentList(_filteredUsers),
                              _buildProductionHouseList(_productionHouses),
                              _buildOpportunityList(_opportunities),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 56, color: CineColors.gold.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'Explore the Cinema Master Network',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: CineColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Search for guild-certified cinematographers, directors, production companies, and active open casting calls across India.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: CineColors.textMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTab() {
    final hasResults = _filteredUsers.isNotEmpty ||
        _productionHouses.isNotEmpty ||
        _opportunities.isNotEmpty;

    if (!hasResults) {
      return _buildEmptyResults();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        if (_filteredUsers.isNotEmpty) ...[
          _buildSectionHeader('Talent & Crew (${_filteredUsers.length})', Icons.people_outline),
          ..._filteredUsers.take(4).map(_buildTalentCard),
          const SizedBox(height: 14),
        ],
        if (_opportunities.isNotEmpty) ...[
          _buildSectionHeader('Casting Calls & Opportunities (${_opportunities.length})', Icons.movie_creation_outlined),
          ..._opportunities.take(4).map(_buildOpportunityCard),
          const SizedBox(height: 14),
        ],
        if (_productionHouses.isNotEmpty) ...[
          _buildSectionHeader('Production Houses & Studios (${_productionHouses.length})', Icons.business_outlined),
          ..._productionHouses.take(4).map(_buildProductionHouseCard),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, color: CineColors.gold, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: CineColors.gold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTalentList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _buildEmptyResults('No matching talent found');
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _buildTalentCard(items[index]),
    );
  }

  Widget _buildProductionHouseList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _buildEmptyResults('No production houses found');
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _buildProductionHouseCard(items[index]),
    );
  }

  Widget _buildOpportunityList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _buildEmptyResults('No opportunities found');
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _buildOpportunityCard(items[index]),
    );
  }

  Widget _buildEmptyResults([String message = 'No results found']) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: CineColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: CineColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTalentCard(Map<String, dynamic> user) {
    final fullName = user['full_name'] ?? 'Cinema Professional';
    final role = user['role'] ?? 'Film Craft';
    final location = user['location'] ?? 'Pan-India';
    final isGuild = user['is_guild_verified'] == true;
    final rate = user['daily_call_sheet_rate'];
    final id = user['id'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: CineColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CineColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: CineColors.gold.withValues(alpha: 0.2),
          child: Text(
            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T',
            style: const TextStyle(color: CineColors.gold, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                fullName,
                style: const TextStyle(
                  color: CineColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isGuild)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CineColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CineColors.gold, width: 0.7),
                ),
                child: const Text(
                  'GUILD',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: CineColors.gold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(
              role,
              style: const TextStyle(color: CineColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: CineColors.textMuted),
                const SizedBox(width: 3),
                Text(location, style: const TextStyle(color: CineColors.textMuted, fontSize: 11)),
                if (rate != null) ...[
                  const SizedBox(width: 10),
                  Text('₹$rate/day', style: const TextStyle(color: CineColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: CineColors.textMuted, size: 20),
        onTap: () {
          if (id.isNotEmpty) {
            context.push('/talent-profile/$id');
          }
        },
      ),
    );
  }

  Widget _buildProductionHouseCard(Map<String, dynamic> ph) {
    final name = ph['company_name'] ?? 'Production House';
    final location = ph['location'] ?? 'Mumbai / Pan-India';
    final desc = ph['description'] ?? 'Active Film Studio & Production House';

    return Container(
      decoration: BoxDecoration(
        color: CineColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CineColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.amber.shade900.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CineColors.gold.withValues(alpha: 0.4)),
          ),
          child: const Center(
            child: Icon(Icons.business_rounded, color: CineColors.gold, size: 20),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: CineColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              desc,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: CineColors.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: CineColors.textMuted),
                const SizedBox(width: 3),
                Text(location, style: const TextStyle(color: CineColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: CineColors.textMuted, size: 20),
        onTap: () {
          context.push('/company-profile');
        },
      ),
    );
  }

  Widget _buildOpportunityCard(Map<String, dynamic> opp) {
    final title = opp['title'] ?? 'Casting Opportunity';
    final roleType = opp['role_type'] ?? 'Actor / Crew';
    final location = opp['location'] ?? 'Location TBD';
    final id = opp['id'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: CineColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CineColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: CineColors.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CineColors.gold.withValues(alpha: 0.3)),
          ),
          child: const Center(
            child: Icon(Icons.movie_filter_rounded, color: CineColors.gold, size: 20),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: CineColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              roleType,
              style: const TextStyle(color: CineColors.gold, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: CineColors.textMuted),
                const SizedBox(width: 3),
                Text(location, style: const TextStyle(color: CineColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: CineColors.textMuted, size: 20),
        onTap: () {
          if (id.isNotEmpty) {
            context.push('/opportunities/$id');
          }
        },
      ),
    );
  }
}
