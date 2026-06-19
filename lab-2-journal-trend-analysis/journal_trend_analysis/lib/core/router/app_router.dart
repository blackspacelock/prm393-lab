import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/keyword.dart';
import '../../domain/entities/publication.dart';
import '../../domain/usecases/get_top_journals.dart';
import '../../presentation/screens/author_network_screen.dart';
import '../../presentation/screens/heatmap_screen.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/journal_detail_screen.dart';
import '../../presentation/screens/journals_screen.dart';
import '../../presentation/screens/keyword_detail_screen.dart';
import '../../presentation/screens/keywords_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/profile_screen.dart';
import '../../presentation/screens/publication_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, _) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          _MainShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/journals', builder: (_, _) => const JournalsScreen()),
        GoRoute(path: '/keywords', builder: (_, _) => const KeywordsScreen()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      ],
    ),
    GoRoute(
      path: '/publication/:id',
      builder: (context, state) {
        final pub = state.extra as Publication;
        return PublicationDetailScreen(publication: pub);
      },
    ),
    GoRoute(
      path: '/journal/:name',
      builder: (context, state) {
        final journal = state.extra as JournalWithCount;
        return JournalDetailScreen(journal: journal);
      },
    ),
    GoRoute(
      path: '/keyword/:name',
      builder: (context, state) {
        final keyword = state.extra as KeywordItem;
        return KeywordDetailScreen(keyword: keyword);
      },
    ),
    GoRoute(path: '/heatmap', builder: (_, _) => const HeatmapScreen()),
    GoRoute(path: '/network', builder: (_, _) => const AuthorNetworkScreen()),
  ],
);

class _MainShell extends StatelessWidget {
  final String location;
  final Widget child;

  const _MainShell({required this.location, required this.child});

  int get _selectedIndex {
    if (location.startsWith('/journals')) return 1;
    if (location.startsWith('/keywords')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0; // /home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => switch (i) {
          0 => context.go('/home'),
          1 => context.go('/journals'),
          2 => context.go('/keywords'),
          _ => context.go('/profile'),
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Journals',
          ),
          NavigationDestination(
            icon: Icon(Icons.label_outline),
            selectedIcon: Icon(Icons.label),
            label: 'Keywords',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
