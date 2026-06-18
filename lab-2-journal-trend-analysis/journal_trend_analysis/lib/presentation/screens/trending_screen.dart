import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/publication_card.dart';
import '../widgets/shimmer_loader.dart';

// ── Domain category definitions ───────────────────────────────────────────────

class _Category {
  final String label;
  final String? conceptId;
  final IconData icon;

  const _Category({required this.label, required this.icon, this.conceptId});
}

const _categories = [
  _Category(label: 'All Fields', icon: Icons.auto_awesome, conceptId: null),
  _Category(
    label: 'AI & ML',
    icon: Icons.psychology,
    conceptId: 'C154945302',
  ),
  _Category(
    label: 'Medicine',
    icon: Icons.health_and_safety_outlined,
    conceptId: 'C71924100',
  ),
  _Category(
    label: 'Physics',
    icon: Icons.science_outlined,
    conceptId: 'C121332964',
  ),
  _Category(
    label: 'Biology',
    icon: Icons.biotech_outlined,
    conceptId: 'C86803240',
  ),
  _Category(
    label: 'Comp. Sci.',
    icon: Icons.computer_outlined,
    conceptId: 'C41008148',
  ),
  _Category(
    label: 'Chemistry',
    icon: Icons.blender_outlined,
    conceptId: 'C185592680',
  ),
  _Category(
    label: 'Economics',
    icon: Icons.trending_up_outlined,
    conceptId: 'C162324750',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class TrendingScreen extends ConsumerStatefulWidget {
  const TrendingScreen({super.key});

  @override
  ConsumerState<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends ConsumerState<TrendingScreen> {
  int _selectedIndex = 0;

  String? get _conceptId => _categories[_selectedIndex].conceptId;

  @override
  Widget build(BuildContext context) {
    final pubAsync = ref.watch(trendingPublicationsProvider(_conceptId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('All Trending'),
        backgroundColor: AppColors.surfaceContainerLowest,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _CategoryChips(
            selectedIndex: _selectedIndex,
            onSelected: (i) => setState(() => _selectedIndex = i),
          ),
        ),
      ),
      body: pubAsync.when(
        loading: () => const ShimmerLoader(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(trendingPublicationsProvider(_conceptId)),
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
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _CategoryChips({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.base,
          vertical: AppDimensions.sm,
        ),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppDimensions.sm),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = i == selectedIndex;
          return ChoiceChip(
            avatar: Icon(
              cat.icon,
              size: 16,
              color: selected
                  ? AppColors.onSecondaryContainer
                  : AppColors.onSurfaceVariant,
            ),
            label: Text(
              cat.label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected
                    ? AppColors.onSecondaryContainer
                    : AppColors.onSurface,
              ),
            ),
            selected: selected,
            onSelected: (_) => onSelected(i),
            backgroundColor: AppColors.surfaceContainerLowest,
            selectedColor: AppColors.secondaryContainer,
            side: BorderSide(
              color: selected
                  ? AppColors.primaryContainer
                  : AppColors.outlineVariant,
              width: 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}
