import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cineconnect/features/production_house/applications/applications_page.dart';
import 'package:cineconnect/features/production_house/home/home_page.dart';
import 'package:cineconnect/features/production_house/notifications/notification_bell.dart';
import 'package:cineconnect/features/production_house/opportunities/opportunities_page.dart';
import 'package:cineconnect/features/production_house/projects/projects_page.dart';
import 'package:cineconnect/features/production_house/talent_discovery/talent_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  static const _titles = [
    'CineConnect',
    'Projects',
    'Jobs',
    'Applications',
    'Talent',
  ];

  void _openTab(int index) {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    });
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
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Applications',
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