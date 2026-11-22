import 'package:flutter/material.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../header/app_header.dart';
import '../../navigation/cine_bottom_nav_bar.dart';
import '../../feed/linkedin_cinema_feed.dart';
import '../../jobs/naukri_casting_board.dart';
import '../../reels/cinereels_view.dart';
import '../../radar/talent_network_radar.dart';
import '../../profile/digital_slate_profile.dart';
import '../../notifications/notifications_sheet.dart';
import '../../chat/chat_sheet.dart';
import '../../create/create_action_sheet.dart';

/// Complete Cinema Talent Portal combining:
/// 1. LinkedIn for Cinema (Feed)
/// 2. Naukri for Cinema (Casting Board)
/// 3. CineReels (Instagram Reels for Cinema)
/// 4. 24-Crafts Talent Radar (Networking)
/// 5. Digital Slate Profile
class TalentPortalScreen extends StatefulWidget {
  final CineAppState? appState;
  const TalentPortalScreen({super.key, this.appState});

  @override
  State<TalentPortalScreen> createState() => _TalentPortalScreenState();
}

class _TalentPortalScreenState extends State<TalentPortalScreen> {
  late final CineAppState _appState;
  late final bool _ownsAppState;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _ownsAppState = widget.appState == null;
    _appState = widget.appState ?? CineAppState();
  }

  @override
  void dispose() {
    if (_ownsAppState) {
      _appState.dispose();
    }
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationsSheet(appState: _appState),
    );
  }

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatSheet(appState: _appState),
    );
  }

  void _openCreateAction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateActionSheet(appState: _appState),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: CineColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Top Cinema App Header
                CineAppHeader(
                  state: _appState,
                  onOpenNotifications: _openNotifications,
                  onOpenChat: _openChat,
                ),
                // 5-Tab Cinema Body
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      LinkedInCinemaFeed(appState: _appState),
                      NaukriCastingBoard(appState: _appState),
                      CineReelsView(appState: _appState),
                      TalentNetworkRadarView(appState: _appState),
                      DigitalSlateProfileView(appState: _appState),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: CineBottomNavBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            onCreatePressed: _openCreateAction,
            opportunitiesBadgeCount: _appState.jobBriefs.length,
          ),
        );
      },
    );
  }
}
