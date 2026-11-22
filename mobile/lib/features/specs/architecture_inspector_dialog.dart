import 'package:flutter/material.dart';
import 'package:cineconnect/app/theme.dart';

class ArchitectureInspectorDialog extends StatefulWidget {
  const ArchitectureInspectorDialog({super.key});

  @override
  State<ArchitectureInspectorDialog> createState() => _ArchitectureInspectorDialogState();
}

class _ArchitectureInspectorDialogState extends State<ArchitectureInspectorDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF101117),
            border: Border.all(color: CineColors.gold, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: CineColors.gold.withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF151620),
                  border: Border(bottom: BorderSide(color: CineColors.border)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code_rounded, color: CineColors.gold, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Talent Portal Architecture & API Inspector',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CineColors.textPrimary),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: CineColors.textMuted, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              ),

              // Tabs Header
              Container(
                color: const Color(0xFF0D0E14),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: CineColors.gold,
                  labelColor: CineColors.gold,
                  unselectedLabelColor: CineColors.textMuted,
                  labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Talent API Mapping'),
                    Tab(text: 'Design Tokens'),
                    Tab(text: 'Bottom Nav Layout'),
                    Tab(text: 'Skill Matching Engine'),
                    Tab(text: '24 Crafts Domain Models'),
                    Tab(text: 'Mobile Production Specs'),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCodeView('''// CINE CONNECT TALENT-ONLY API MAPPING
// Authentication: Authorization: Bearer <SUPABASE_ACCESS_TOKEN>
// Base URL: http://localhost:8000 | Android Emulator: http://10.0.2.2:8000

// 1. TALENT USER PROFILES (lib/core/network/api_endpoints.dart)
GET    /api/v1/users/me                     -> Get authenticated talent profile
PUT    /api/v1/users/me                     -> Complete profile replace
PATCH  /api/v1/users/me                     -> Update skills, availability, rate
GET    /api/v1/users/{user_id}              -> Public peer profile
GET    /api/v1/users                        -> List talent radar peers
GET    /api/v1/users/search                 -> Search cinema peers
GET    /api/v1/users/{user_id}/portfolio    -> Inspect peer showreels

// 2. OPPORTUNITIES & AUDITION APPLICATIONS
GET    /api/v1/opportunities/              -> List casting & crew calls (trailing slash)
GET    /api/v1/opportunities/{id}          -> Read 12pt Courier screenplay sides
GET    /api/v1/opportunities/search        -> Search calls with skill tags
POST   /api/v1/applications/               -> 1-Tap Self-Tape apply (trailing slash)
GET    /api/v1/applications/my             -> My Auditions Tracker
DELETE /api/v1/applications/{id}            -> Withdraw audition application

// 3. SHOWREELS & PORTFOLIO MEDIA
GET    /api/v1/portfolio/my                -> Digital Slate showreels
POST   /api/v1/portfolio/                  -> Add showreel / SMPTE slate (trailing slash)
DELETE /api/v1/portfolio/{id}              -> Delete portfolio reel
POST   /api/v1/media/upload-url            -> Presigned S3 upload URL

// 4. LINKEDIN FOR CINEMA SOCIAL FEED
GET    /api/v1/posts/                      -> Industry pulse feed (trailing slash)
POST   /api/v1/posts/                      -> Wrap post / SMPTE 24fps reel
POST   /api/v1/interactions/               -> Clap / SMPTE timecode critique note

// 5. 24-CRAFTS PEER CONNECTIONS & COLLABORATIONS
POST   /api/v1/connections/                -> Send peer connection (trailing slash)
GET    /api/v1/connections/my              -> List connected crew
GET    /api/v1/collaborations/my           -> Inbound project invites
PATCH  /api/v1/collaborations/{id}/accept  -> Accept collaboration

// 6. MESSAGING & TALENT DASHBOARD
GET    /api/v1/messages/conversations      -> Peer chat conversations
POST   /api/v1/messages/                   -> Direct chat message (trailing slash)
GET    /api/v1/dashboard/talent            -> Talent Overview Dashboard

// [EXCLUDED - NOT MERGED INTO TALENT PORTAL]:
// Production House creation/management routes (/production-houses/*,
// /opportunities POST/DELETE, /applications review, /dashboard/production-house)'''),
                    _buildCodeView('''// CINE CONNECT TALENT PORTAL DESIGN TOKENS
class CineColors {
  // User Exact Specified Tokens:
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF1D675);
  static const Color surface = Color(0xFF161616);
  static const Color border = Color(0xFF2A2A2A);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textMuted = Color(0xFF9A9A9A);
  static const Color error = Color(0xFFE5484D);

  // OLED Cinema True-Black Environment
  static const Color background = Color(0xFF0B0C10); // 0.005 nit OLED black
  static const Color surfaceElevated = Color(0xFF1C1C22);
  static const Color surfaceCard = Color(0xFF141419);
  static const Color success = Color(0xFF10B981);    // 96% Match & Guild Verified
  static const Color warning = Color(0xFFF59E0B);    // 35mm Amber Warning
}'''),
                    _buildCodeView('''// BOTTOM NAVIGATION LAYOUT (Standard 5-Tab Bar)
// Home | Opportunities | Create (+) | Search | Profile
// The highlighted center action opens the create flow.

class CineBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildNavItem(index: 0, label: 'Home'),
        _buildNavItem(index: 1, label: 'Opportunities'),
        _buildCreateButton(onTap: onCreatePressed),
        _buildNavItem(index: 3, label: 'Search'),
        _buildNavItem(index: 4, label: 'Profile'),
      ],
    );
  }
}'''),
                    _buildCodeView('''// REAL-TIME SKILL OVERLAP & MATCH ENGINE (FOR TALENT)
// Evaluates talent's verified skill set against studio job calls:
double calculateSkillMatch(List<String> required) {
  if (required.isEmpty) return 1.0;
  int matched = 0;
  for (final req in required) {
    if (userSkills.contains(req)) {
      matched++;
    }
  }
  return (matched / required.length) * 100.0;
}

// When talent toggles skill chips in their Digital Slate,
// all open briefs instantly re-evaluate (e.g. 96% Match)!'''),
                    _buildCodeView('''// 24 CRAFTS & VERIFIED FILMOGRAPHY DOMAIN MODEL
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
}'''),
                    _buildCodeView('''// MOBILE PRODUCTION ARCHITECTURE & FRAME BUDGETING
1. 3-in-1 Architecture:
   - LinkedIn for Cinema: Professional feed & SMPTE player
   - Naukri for Cinema: Casting board & 1-tap self-tape
   - Instagram Reels: Full 9:16 showreels & double-tap gold hearts
2. 60/120 FPS Rendering Budget:
   - Lightweight bottom navigation bar with cached icons
   - PageView memory recycling in vertical showreels
3. Guild-Verified Slate:
   - Animated clapperboard snap trigger with haptic feedback
   - Cryptographic verification hash for union credits'''),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeView(String code) {
    return Container(
      padding: const EdgeInsets.all(14),
      color: const Color(0xFF0A0B10),
      child: SingleChildScrollView(
        child: SelectableText(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            color: Color(0xFFD4D4DC),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
