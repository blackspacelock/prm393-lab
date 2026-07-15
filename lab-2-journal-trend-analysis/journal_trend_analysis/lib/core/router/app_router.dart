import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/journal.dart';
import '../../domain/entities/publication.dart';
import '../../presentation/screens/bookmarks_screen.dart';
import '../../presentation/screens/journal_detail_screen.dart';
import '../../presentation/screens/journals_screen.dart';
import '../../presentation/screens/keywords_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/profile_screen.dart';
import '../../presentation/screens/publication_detail_screen.dart';
import '../../presentation/screens/trending_screen.dart';
import '../../firebase/analytics_service.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/widgets/analytics_view.dart';
import '../theme/app_colors.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (_, state) {
    if (state.uri.path != '/profile/bookmarks') return null;
    if (!firebaseSupported) return '/profile';
    return FirebaseAuth.instance.currentUser == null ? '/login' : null;
  },
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          _ScaffoldWithNav(location: state.uri.path, child: child),
      routes: [
        // Tab 1: Home (formerly Trending)
        GoRoute(path: '/home', builder: (_, _) => const TrendingScreen()),
        // Tab 2: Journals
        GoRoute(path: '/journals', builder: (_, _) => const JournalsScreen()),
        // Tab 3: Keywords (integrated Search + Dashboard + Heatmap + Network)
        GoRoute(path: '/keywords', builder: (_, _) => const KeywordsScreen()),
        // Tab 4: Profile
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      ],
    ),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(
      path: '/publication/:id',
      builder: (context, state) {
        final pub = state.extra as Publication;
        return AnalyticsView(
          onOpen: () =>
              analyticsService.viewPublication(pub.title, pub.publicationYear),
          child: PublicationDetailScreen(publication: pub),
        );
      },
    ),
    GoRoute(
      path: '/journals/:id',
      builder: (context, state) {
        final journal = state.extra as Journal;
        return AnalyticsView(
          onOpen: () => analyticsService.viewJournal(journal.displayName),
          child: JournalDetailScreen(journal: journal),
        );
      },
    ),
    GoRoute(
      path: '/profile/bookmarks',
      builder: (_, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Saved Papers'),
          backgroundColor: AppColors.surfaceContainerLowest,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        backgroundColor: AppColors.surface,
        body: const BookmarksScreen(),
      ),
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  final String location;
  final Widget child;

  const _ScaffoldWithNav({required this.location, required this.child});

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
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.outlineVariant, width: 0.5),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelFontSize = (constraints.maxWidth / 48).clamp(8.0, 10.0);

            return NavigationBarTheme(
              data: NavigationBarTheme.of(context).copyWith(
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontSize: labelFontSize,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.primaryContainer
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                backgroundColor: AppColors.surfaceContainerLowest,
                indicatorColor: AppColors.secondaryContainer,
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
                    icon: Icon(Icons.search_outlined),
                    selectedIcon: Icon(Icons.search),
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
          },
        ),
      ),
    );
  }
}
