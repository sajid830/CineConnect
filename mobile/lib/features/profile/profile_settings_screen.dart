import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cineconnect/app/theme.dart';
import '../../core/state/app_state.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final CineAppState appState;
  final Future<void> Function()? onSignOut;

  const ProfileSettingsScreen({
    super.key,
    required this.appState,
    this.onSignOut,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _pauseAll = false;
  bool _likesComments = true;
  bool _castingMatches = true;
  bool _messages = true;
  bool _privateAccount = false;

  @override
  Widget build(BuildContext context) {
    final talent = widget.appState.myProfile;
    if (talent == null) {
      return Scaffold(
        backgroundColor: CineColors.background,
        appBar: AppBar(
          backgroundColor: CineColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: CineColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Settings and privacy',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: CineColors.textPrimary,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: CineColors.gold),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CineColors.background,
      appBar: AppBar(
        backgroundColor: CineColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: CineColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings and privacy',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: CineColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: CineColors.textPrimary),
            onPressed: () => _showInfo('Search settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _accountHeader(talent),
          const Divider(height: 1, color: CineColors.border),
          _sectionLabel('Your account'),
          _tile(
            Icons.person_outline_rounded,
            'Personal details',
            'Name, headline, rate & availability',
            onTap: () => _openEditDetailsDialog(context, talent),
          ),
          _tile(Icons.lock_outline_rounded, 'Password and security', 'Password, login activity'),
          _tile(Icons.verified_user_outlined, 'Guild verification', '${talent.guildId} • Verified'),
          _sectionLabel('How you use CineConnect'),
          _tile(Icons.insights_outlined, 'Your activity', 'Likes, comments and applications'),
          _tile(Icons.bookmark_border_rounded, 'Saved', 'Saved reels and casting calls'),
          _tile(Icons.archive_outlined, 'Archive', 'Archived posts and stories'),
          _tile(Icons.group_outlined, 'Close friends', 'Private story audience'),
          _tile(Icons.timer_outlined, 'Time management', 'Daily reminders and limits'),
          _sectionLabel('Notifications'),
          _switchTile(
            title: 'Pause all',
            subtitle: 'Mute all notifications',
            value: _pauseAll,
            onChanged: (value) => setState(() => _pauseAll = value),
          ),
          _switchTile(
            title: 'Likes and comments',
            subtitle: 'Activity on your posts and reels',
            value: _likesComments,
            onChanged: (value) => setState(() => _likesComments = value),
          ),
          _switchTile(
            title: 'Casting matches',
            subtitle: 'New jobs matched to your skills',
            value: _castingMatches,
            onChanged: (value) => setState(() => _castingMatches = value),
          ),
          _switchTile(
            title: 'Messages',
            subtitle: 'Direct messages and requests',
            value: _messages,
            onChanged: (value) => setState(() => _messages = value),
          ),
          _sectionLabel('Privacy'),
          _tile(
            Icons.lock_outline_rounded,
            'Account privacy',
            _privateAccount ? 'Private' : 'Public',
            onTap: () {
              setState(() => _privateAccount = !_privateAccount);
              _showInfo(_privateAccount ? 'Account is now private' : 'Account is now public');
            },
          ),
          _tile(Icons.block_rounded, 'Blocked', 'Manage blocked accounts'),
          _tile(Icons.visibility_off_outlined, 'Hide story and live', 'Choose who can see you'),
          _sectionLabel('More info and support'),
          _tile(Icons.help_outline_rounded, 'Help', 'Support and common questions'),
          _tile(Icons.info_outline_rounded, 'About', 'CineConnect v1.0.0'),
          const SizedBox(height: 8),
          ListTile(
            onTap: () => _confirmLogout(context),
            leading: const Icon(Icons.logout_rounded, color: CineColors.error),
            title: const Text(
              'Log out',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: CineColors.error,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              'CineConnect • 24 Crafts Cinema Talent Network',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: CineColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountHeader(dynamic talent) {
    return InkWell(
      onTap: () => _showInfo('Switch account'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
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
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: CineColors.surface,
                ),
                child: Center(
                  child: Text(
                    talent.avatarUrl as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: CineColors.gold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    talent.fullName as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: CineColors.textPrimary,
                    ),
                  ),
                  Text(
                    talent.handle as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CineColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: CineColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: CineColors.textMuted,
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap ?? () => _showInfo(title),
      leading: Icon(icon, color: CineColors.textPrimary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: CineColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.5, color: CineColors.textMuted),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: CineColors.textMuted,
        size: 20,
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      activeThumbColor: CineColors.gold,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: CineColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.5, color: CineColors.textMuted),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  void _openEditDetailsDialog(BuildContext context, dynamic talent) {
    final nameCtrl = TextEditingController(text: talent.fullName);
    final handleCtrl = TextEditingController(text: talent.handle);
    final craftCtrl = TextEditingController(text: talent.primaryCraft);
    final headlineCtrl = TextEditingController(text: talent.headline);
    final guildCtrl = TextEditingController(text: talent.guildId);
    final locationCtrl = TextEditingController(text: talent.hubLocation);
    final rateCtrl = TextEditingController(text: talent.dailyCallSheetRate);
    final availCtrl = TextEditingController(text: talent.immediateAvailability);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13141C),
        title: const Text(
          'Edit Slate Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CineColors.gold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: handleCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Handle (@username)', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: craftCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Primary Craft', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: headlineCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Headline', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: guildCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Guild ID (e.g. ISC-9021)', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Location / Hub', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: rateCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Call-Sheet Rate', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: availCtrl,
                style: const TextStyle(color: CineColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Availability', labelStyle: TextStyle(color: CineColors.textMuted)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CineColors.gold, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await widget.appState.updateMyProfile({
                  'full_name': nameCtrl.text.trim(),
                  'handle': handleCtrl.text.trim(),
                  'role': craftCtrl.text.trim(),
                  'headline': headlineCtrl.text.trim(),
                  'guild_id': guildCtrl.text.trim(),
                  'location': locationCtrl.text.trim(),
                  'daily_call_sheet_rate': rateCtrl.text.trim(),
                  'immediate_availability': availCtrl.text.trim(),
                });
                if (context.mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not update profile')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13141C),
        title: const Text(
          'Log out of CineConnect?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You can sign back in with your talent guild account anytime.',
          style: TextStyle(fontSize: 12.5, color: CineColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: CineColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                widget.appState.clearUserData();
                if (widget.onSignOut != null) {
                  await widget.onSignOut!();
                } else {
                  await Supabase.instance.client.auth.signOut();
                }
                if (context.mounted) {
                  final goRouter = GoRouter.maybeOf(context);
                  if (goRouter != null) {
                    context.go('/role-selection');
                  } else {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: CineColors.surfaceElevated,
                      content: Text(
                        'Logged out of CineConnect',
                        style: TextStyle(color: CineColors.gold),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: CineColors.error,
                      content: Text(
                        'Sign out failed: ${e.toString()}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Log out',
              style: TextStyle(color: CineColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
