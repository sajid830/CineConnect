import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/core/services/realtime_events_service.dart';
import 'package:cineconnect/features/production_house/applications/applications_page.dart';
import 'package:cineconnect/features/production_house/applications/applications_provider.dart';
import 'package:cineconnect/features/production_house/home/home_page.dart';
import 'package:cineconnect/features/production_house/notifications/notification_bell.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_page.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_provider.dart';
import 'package:cineconnect/features/production_house/projects/projects_page.dart';
import 'package:cineconnect/features/production_house/projects/projects_provider.dart';
import 'package:cineconnect/features/production_house/talent_discovery/talent_page.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  static const _titles = [
    'CineConnect',
    'Projects',
    'Casting calls',
    'Applications',
    'Talent',
  ];

  void _openTab(int index) {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _selectedIndex = index);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
        leading: IconButton(
          tooltip: 'Company profile',
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => context.push('/company-profile'),
        ),
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/ph-chat'),
          ),
          const NotificationBell(),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(onOpenTab: _openTab),
          const ProjectsPage(),
          const OpportunitiesPage(),
          const ApplicationsPage(),
          const TalentPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _openTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_creation_outlined),
            selectedIcon: Icon(Icons.movie_creation),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Casting',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Talent',
          ),
        ],
      ),
    );
  }
}