import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/state/app_state.dart';
import '../features/header/app_header.dart';
import '../features/navigation/cine_bottom_nav_bar.dart';
import '../features/feed/linkedin_cinema_feed.dart';
import '../features/jobs/naukri_casting_board.dart';
import '../features/radar/talent_network_radar.dart';
import '../features/profile/digital_slate_profile.dart';
import '../features/stories/story_viewer_dialog.dart';
import '../features/stories/story_status_bar.dart';
import '../features/notifications/notifications_sheet.dart';
import '../features/chat/chat_sheet.dart';
import '../features/create/create_action_sheet.dart';

class CineConnectApp extends StatefulWidget {
  const CineConnectApp({super.key});

  @override
  State<CineConnectApp> createState() => _CineConnectAppState();
}

class _CineConnectAppState extends State<CineConnectApp> {
  final CineAppState _state = CineAppState();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChange);
    _state.dispose();
    super.dispose();
  }

  void _onStateChange() {
    setState(() {});
  }

  BuildContext? get _navContext => _navigatorKey.currentContext;

  void _openNotificationsSheet() {
    final navContext = _navContext;
    if (navContext == null) return;
    showModalBottomSheet(
      context: navContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationsSheet(appState: _state),
    );
  }

  void _openChatSheet() {
    final navContext = _navContext;
    if (navContext == null) return;
    showModalBottomSheet(
      context: navContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatSheet(appState: _state),
    );
  }

  void _openCreateActionModal() {
    final navContext = _navContext;
    if (navContext == null) return;
    showModalBottomSheet(
      context: navContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateActionSheet(appState: _state),
    );
  }

  void _handleBack() {
    if (_state.activeNavIndex != 0) {
      _state.setActiveNavIndex(0);
    } else {
      final navContext = _navContext;
      if (navContext == null) return;
      ScaffoldMessenger.of(navContext).showSnackBar(
        const SnackBar(
          backgroundColor: CineColors.surfaceElevated,
          content: Text(
            'Already at Home feed',
            style: TextStyle(color: CineColors.gold),
          ),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildActiveTabBody() {
    switch (_state.activeNavIndex) {
      case 0:
        return Column(
          children: [
            StoryStatusBar(state: _state),
            Expanded(child: LinkedInCinemaFeed(appState: _state)),
          ],
        );
      case 1:
        return NaukriCastingBoard(appState: _state);
      case 2:
        return LinkedInCinemaFeed(appState: _state);
      case 3:
        return TalentNetworkRadarView(appState: _state);
      case 4:
        return DigitalSlateProfileView(appState: _state);
      default:
        return LinkedInCinemaFeed(appState: _state);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineConnect — 24 Crafts Cinema Talent Network',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: CineTheme.darkTheme,
      home: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: CineColors.background,
            body: SafeArea(
              child: Stack(
                children: [
                  // Main Talent Portal Column
                  Column(
                    children: [
                      // Header with Back Arrow, Logo, Title, TALENT badge, Notifications & Chat
                      CineAppHeader(
                        state: _state,
                        onOpenNotifications: _openNotificationsSheet,
                        onOpenChat: _openChatSheet,
                        onBack: _handleBack,
                      ),

                      // Dynamic Screen Body
                      Expanded(
                        child: _buildActiveTabBody(),
                      ),
                    ],
                  ),

                  // Full-Screen On-Set Story Modal Viewer
                  if (_state.activeViewedStory != null)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.85),
                        child: OnSetStoryViewerDialog(
                          story: _state.activeViewedStory!,
                          onClose: () => _state.closeStory(),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Navigation Bar with Home, Opportunities, Create (+), Search, Profile
            bottomNavigationBar: CineBottomNavBar(
              currentIndex: _state.activeNavIndex,
              onTap: (index) {
                _state.setActiveNavIndex(index);
              },
              onCreatePressed: _openCreateActionModal,
            ),
          );
        },
      ),
    );
  }
}
