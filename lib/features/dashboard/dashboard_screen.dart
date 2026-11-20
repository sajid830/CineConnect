import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import '../applications/applications_page.dart';
import '../home/home_page.dart';
import '../notifications/notification_bell.dart';
import '../opportunities/opportunities_page.dart';
import '../projects/projects_page.dart';
import '../talent_discovery/talent_page.dart';

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
    'Casting calls',
    'Applications',
    'Talent',
  ];

  void _openTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
        leading: IconButton(
          tooltip: 'Company profile',
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => context.push('/profile'),
        ),
        title: Text(_titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/chats'),
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