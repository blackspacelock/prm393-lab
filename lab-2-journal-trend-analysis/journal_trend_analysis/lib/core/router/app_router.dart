import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/publication.dart';
import '../../presentation/screens/dashboard_screen.dart';
import '../../presentation/screens/publication_detail_screen.dart';
import '../../presentation/screens/search_screen.dart';
import '../../presentation/screens/trend_analysis_screen.dart';
import '../theme/app_colors.dart';

final appRouter = GoRouter(
  initialLocation: '/search',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          _ScaffoldWithNav(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
        GoRoute(
          path: '/trends',
          builder: (_, __) => const TrendAnalysisScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, __) => const DashboardScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/publication/:id',
      builder: (context, state) {
        final pub = state.extra as Publication;
        return PublicationDetailScreen(publication: pub);
      },
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  final String location;
  final Widget child;

  const _ScaffoldWithNav({required this.location, required this.child});

  int get _selectedIndex {
    if (location.startsWith('/trends')) return 1;
    if (location.startsWith('/dashboard')) return 2;
    return 0;
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
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          backgroundColor: AppColors.surfaceContainerLowest,
          indicatorColor: AppColors.secondaryContainer,
          onDestinationSelected: (i) => switch (i) {
            0 => context.go('/search'),
            1 => context.go('/trends'),
            _ => context.go('/dashboard'),
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart_outlined),
              selectedIcon: Icon(Icons.show_chart),
              label: 'Trends',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
          ],
        ),
      ),
    );
  }
}
