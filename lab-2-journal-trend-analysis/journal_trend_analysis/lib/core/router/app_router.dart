import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/publication.dart';
import '../../presentation/screens/author_network_screen.dart';
import '../../presentation/screens/bookmarks_screen.dart';
import '../../presentation/screens/heatmap_screen.dart';
import '../../presentation/screens/publication_detail_screen.dart';
import '../../presentation/screens/search_screen.dart';
import '../../presentation/screens/trend_analysis_screen.dart';
import '../../presentation/screens/trending_screen.dart';
import '../theme/app_colors.dart';

final appRouter = GoRouter(
  initialLocation: '/trending',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          _ScaffoldWithNav(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/trending', builder: (_, _) => const TrendingScreen()),
        GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => const TrendAnalysisScreen(),
        ),
        GoRoute(path: '/heatmap', builder: (_, _) => const HeatmapScreen()),
        GoRoute(
          path: '/network',
          builder: (_, _) => const AuthorNetworkScreen(),
        ),
        GoRoute(path: '/bookmarks', builder: (_, _) => const BookmarksScreen()),
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
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/dashboard')) return 2;
    if (location.startsWith('/heatmap')) return 3;
    if (location.startsWith('/network')) return 4;
    if (location.startsWith('/bookmarks')) return 5;
    return 0; // /trending
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
                  0 => context.go('/trending'),
                  1 => context.go('/search'),
                  2 => context.go('/dashboard'),
                  3 => context.go('/heatmap'),
                  4 => context.go('/network'),
                  _ => context.go('/bookmarks'),
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.local_fire_department_outlined),
                    selectedIcon: Icon(Icons.local_fire_department),
                    label: 'Trending',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_outlined),
                    selectedIcon: Icon(Icons.search),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: 'Dashboard',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map_outlined),
                    selectedIcon: Icon(Icons.map),
                    label: 'Heatmap',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.hub_outlined),
                    selectedIcon: Icon(Icons.hub),
                    label: 'Network',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bookmark_border),
                    selectedIcon: Icon(Icons.bookmark),
                    label: 'Saved',
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
