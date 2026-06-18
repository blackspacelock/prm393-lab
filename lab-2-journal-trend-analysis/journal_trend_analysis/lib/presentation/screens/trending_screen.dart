import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/topic_hierarchy.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/publication_card.dart';
import '../widgets/shimmer_loader.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class TrendingScreen extends ConsumerStatefulWidget {
  const TrendingScreen({super.key});

  @override
  ConsumerState<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends ConsumerState<TrendingScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(trendingCategoriesProvider);
    final categories = categoriesAsync.value ?? const <TopicHierarchyItem>[];
    if (_selectedIndex > categories.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = 0);
      });
    }
    final selectedDomainId =
        _selectedIndex == 0 || _selectedIndex > categories.length
        ? null
        : categories[_selectedIndex - 1].id;
    final pubAsync = ref.watch(trendingPublicationsProvider(selectedDomainId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('All Trending'),
        backgroundColor: AppColors.surfaceContainerLowest,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _CategoryChips(
            categoriesAsync: categoriesAsync,
            selectedIndex: _selectedIndex,
            onSelected: (i) => setState(() => _selectedIndex = i),
          ),
        ),
      ),
      body: pubAsync.when(
        loading: () => const ShimmerLoader(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(trendingPublicationsProvider(selectedDomainId)),
        ),
        data: (pubs) {
          if (pubs.isEmpty) {
            return const EmptyState(
              icon: Icons.trending_up,
              message: 'No trending papers found for this category.',
            );
          }
          return ListView.separated(
            itemCount: pubs.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              indent: AppDimensions.base,
              endIndent: AppDimensions.base,
              color: AppColors.outlineVariant,
            ),
            itemBuilder: (context, i) {
              final pub = pubs[i];
              return PublicationCard(
                publication: pub,
                onTap: () => context.push(
                  '/publication/${Uri.encodeComponent(pub.id)}',
                  extra: pub,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Category chip row ─────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final AsyncValue<List<TopicHierarchyItem>> categoriesAsync;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _CategoryChips({
    required this.categoriesAsync,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return categoriesAsync.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.base,
            vertical: AppDimensions.sm,
          ),
          children: [
            _CategoryChip(
              icon: Icons.auto_awesome,
              label: 'All Fields',
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
          ],
        ),
      ),
      data: (categories) => SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.base,
            vertical: AppDimensions.sm,
          ),
          itemCount: categories.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: AppDimensions.sm),
          itemBuilder: (_, i) {
            if (i == 0) {
              return _CategoryChip(
                icon: Icons.auto_awesome,
                label: 'All Fields',
                selected: selectedIndex == 0,
                onTap: () => onSelected(0),
              );
            }
            final category = categories[i - 1];
            return _CategoryChip(
              icon: Icons.category_outlined,
              label: category.displayName,
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected
            ? AppColors.onSecondaryContainer
            : AppColors.onSurfaceVariant,
      ),
      label: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: selected
              ? AppColors.onSecondaryContainer
              : AppColors.onSurface,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.surfaceContainerLowest,
      selectedColor: AppColors.secondaryContainer,
      side: BorderSide(
        color: selected ? AppColors.primaryContainer : AppColors.outlineVariant,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
