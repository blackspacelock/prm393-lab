import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import 'author_network_screen.dart';
import 'heatmap_screen.dart';
import 'search_screen.dart';
import 'trend_analysis_screen.dart';

/// Integrated Keywords page with 4 sub-tabs:
/// Keywords (search), Dashboard, Heatmap, Network.
class KeywordsScreen extends ConsumerStatefulWidget {
  const KeywordsScreen({super.key});

  @override
  ConsumerState<KeywordsScreen> createState() => _KeywordsScreenState();
}

class _KeywordsScreenState extends ConsumerState<KeywordsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Keywords'),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryContainer,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.primaryContainer,
          labelStyle: AppTextStyles.labelLarge,
          unselectedLabelStyle: AppTextStyles.labelMedium,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
          tabs: const [
            Tab(text: 'Search'),
            Tab(text: 'Dashboard'),
            Tab(text: 'Heatmap'),
            Tab(text: 'Network'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Tab 1: Search (current Search functionality)
          SearchScreen(),
          // Tab 2: Dashboard (trend analysis)
          TrendAnalysisScreen(),
          // Tab 3: Heatmap
          HeatmapScreen(),
          // Tab 4: Author Network
          AuthorNetworkScreen(),
        ],
      ),
    );
  }
}
