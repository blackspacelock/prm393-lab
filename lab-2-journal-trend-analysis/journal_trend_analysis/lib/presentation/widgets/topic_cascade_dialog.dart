import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/topic_hierarchy.dart';
import '../providers/providers.dart';

/// A cascading filter dialog with:
/// • A "Trending" chip strip (8+ topics from current publications) at the top
/// • A Domain → Field → Subfield → Topic cascade browser below
class TopicCascadeDialog extends ConsumerStatefulWidget {
  const TopicCascadeDialog({super.key});

  @override
  ConsumerState<TopicCascadeDialog> createState() => _TopicCascadeDialogState();
}

class _TopicCascadeDialogState extends ConsumerState<TopicCascadeDialog> {
  TopicHierarchyItem? _selectedDomain;
  TopicHierarchyItem? _selectedField;
  TopicHierarchyItem? _selectedSubfield;
  TopicHierarchyItem? _selectedTopic;

  TopicHierarchyItem? get _deepestSelection =>
      _selectedTopic ?? _selectedSubfield ?? _selectedField ?? _selectedDomain;

  void _confirmTrending(String name) {
    final item = TopicHierarchyItem(
      id: name,
      displayName: name,
      level:
          TopicLevel.journal, // maps filterKey → default.search (text search)
    );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final trendingTopics = ref.watch(trendingTopicsProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimensions.base),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.base,
                AppDimensions.base,
                AppDimensions.sm,
                0,
              ),
              child: Row(
                children: [
                  Text(
                    'Browse Topics',
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Trending chips ───────────────────────────────────────────────
            if (trendingTopics.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.base,
                  AppDimensions.sm,
                  AppDimensions.base,
                  AppDimensions.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Trending',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.base,
                  ),
                  itemCount: trendingTopics.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppDimensions.xs),
                  itemBuilder: (_, i) {
                    final topic = trendingTopics[i];
                    return ActionChip(
                      label: Text(
                        topic,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: AppColors.outlineVariant),
                      backgroundColor: AppColors.surfaceContainerLowest,
                      onPressed: () => _confirmTrending(topic),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              const Divider(height: 1),
            ],

            // ── Browse category label ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.base,
                AppDimensions.sm,
                AppDimensions.base,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Browse Categories',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            // ── Breadcrumb ───────────────────────────────────────────────────
            if (_deepestSelection != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.base,
                  vertical: AppDimensions.sm,
                ),
                child: _buildBreadcrumb(),
              ),

            const Divider(height: 1),

            // ── Cascade list ─────────────────────────────────────────────────
            Flexible(child: _buildCurrentLevel()),

            // ── Confirm actions ──────────────────────────────────────────────
            if (_deepestSelection != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedDomain = null;
                        _selectedField = null;
                        _selectedSubfield = null;
                        _selectedTopic = null;
                      }),
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_deepestSelection),
                      child: Text('Search "${_deepestSelection!.displayName}"'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final items = <Widget>[];

    void addCrumb(String label, VoidCallback onTap) {
      items.add(
        GestureDetector(
          onTap: onTap,
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primaryContainer,
            ),
          ),
        ),
      );
    }

    if (_selectedDomain != null) {
      addCrumb(_selectedDomain!.displayName, () {
        setState(() {
          _selectedField = null;
          _selectedSubfield = null;
          _selectedTopic = null;
        });
      });
    }
    if (_selectedField != null) {
      items.add(const Text(' › ', style: TextStyle(fontSize: 12)));
      addCrumb(_selectedField!.displayName, () {
        setState(() {
          _selectedSubfield = null;
          _selectedTopic = null;
        });
      });
    }
    if (_selectedSubfield != null) {
      items.add(const Text(' › ', style: TextStyle(fontSize: 12)));
      addCrumb(_selectedSubfield!.displayName, () {
        setState(() {
          _selectedTopic = null;
        });
      });
    }
    if (_selectedTopic != null) {
      items.add(const Text(' › ', style: TextStyle(fontSize: 12)));
      items.add(
        Text(
          _selectedTopic!.displayName,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: items),
    );
  }

  Widget _buildCurrentLevel() {
    if (_selectedSubfield != null && _selectedTopic == null) {
      // Show topics
      return _TopicList(
        provider: topicsProvider(_selectedSubfield!.id),
        levelLabel: 'Topic',
        onSelect: (item) => setState(() => _selectedTopic = item),
      );
    }
    if (_selectedField != null && _selectedSubfield == null) {
      // Show subfields
      return _TopicList(
        provider: subfieldsProvider(_selectedField!.id),
        levelLabel: 'Subfield',
        onSelect: (item) => setState(() => _selectedSubfield = item),
      );
    }
    if (_selectedDomain != null && _selectedField == null) {
      // Show fields
      return _TopicList(
        provider: fieldsProvider(_selectedDomain!.id),
        levelLabel: 'Field',
        onSelect: (item) => setState(() => _selectedField = item),
      );
    }
    // Show domains
    return _TopicList(
      provider: domainsProvider,
      levelLabel: 'Domain',
      onSelect: (item) => setState(() => _selectedDomain = item),
    );
  }
}

class _TopicList extends ConsumerWidget {
  final ProviderBase<AsyncValue<List<TopicHierarchyItem>>> provider;
  final String levelLabel;
  final ValueChanged<TopicHierarchyItem> onSelect;
  final bool cardStyle;

  const _TopicList({
    required this.provider,
    required this.levelLabel,
    required this.onSelect,
    this.cardStyle = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncItems = ref.watch(provider);

    return asyncItems.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppDimensions.xxl),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.base),
          child: Text('Error loading: $e'),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.base),
              child: Text('No items found'),
            ),
          );
        }
        if (!cardStyle) {
          return ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              indent: AppDimensions.base,
              endIndent: AppDimensions.base,
            ),
            itemBuilder: (_, i) {
              final item = items[i];
              return ListTile(
                title: Text(
                  item.displayName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                subtitle: item.worksCount != null
                    ? Text(
                        '${_formatCount(item.worksCount!)} works',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right, size: 20),
                dense: true,
                onTap: () => onSelect(item),
              );
            },
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.base,
            AppDimensions.sm,
            AppDimensions.base,
            AppDimensions.base,
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.sm),
          itemBuilder: (_, i) {
            final item = items[i];
            return Material(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
              child: InkWell(
                onTap: () => onSelect(item),
                borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.shapeSm,
                          ),
                        ),
                        child: Icon(
                          _iconForLevel(levelLabel),
                          size: 18,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.displayName,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.worksCount != null) ...[
                              const SizedBox(height: AppDimensions.xs),
                              Text(
                                '${_formatCount(item.worksCount!)} works',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconForLevel(String level) {
    return switch (level) {
      'Field' => Icons.school_outlined,
      'Subfield' => Icons.account_tree_outlined,
      'Topic' => Icons.topic_outlined,
      _ => Icons.category_outlined,
    };
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

// ── Topic Browser Dialog (home page pop-up) ───────────────────────────────────

/// Pop-up topic picker for the home page Browse button.
/// Shows trending topic chips at the top, then the domain → field → … cascade.
class TopicBrowserDialog extends ConsumerStatefulWidget {
  const TopicBrowserDialog({super.key});

  @override
  ConsumerState<TopicBrowserDialog> createState() => _TopicBrowserDialogState();
}

class _TopicBrowserDialogState extends ConsumerState<TopicBrowserDialog> {
  // Start at field level (19 OpenAlex fields) — skips the 4-item domain level.
  TopicHierarchyItem? _selectedField;
  TopicHierarchyItem? _selectedSubfield;
  TopicHierarchyItem? _selectedTopic;

  TopicHierarchyItem? get _deepestSelection =>
      _selectedTopic ?? _selectedSubfield ?? _selectedField;

  void _pop([TopicHierarchyItem? result]) => Navigator.of(context).pop(result);

  void _selectTrending(String name) => _pop(
    TopicHierarchyItem(
      id: name,
      displayName: name,
      level: TopicLevel.journal, // filterKey → default.search (text search)
    ),
  );

  @override
  Widget build(BuildContext context) {
    final trendingTopics = ref.watch(trendingTopicsProvider);
    final stepLabel = _selectedSubfield != null
        ? 'Choose a topic'
        : _selectedField != null
        ? 'Choose a subfield'
        : 'Choose a field';

    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimensions.base),
      backgroundColor: AppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.base,
                AppDimensions.base,
                AppDimensions.sm,
                AppDimensions.base,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.shapeSm,
                      ),
                    ),
                    child: const Icon(
                      Icons.explore_outlined,
                      color: AppColors.primaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explore Topics',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.xs),
                        Text(
                          'Find a research area, then use it to filter papers and trends.',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Trending topics ───────────────────────────────────────────────
            if (trendingTopics.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.base,
                  AppDimensions.md,
                  AppDimensions.base,
                  AppDimensions.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      'Quick Picks',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Tap to search',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.base,
                ),
                child: Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: AppDimensions.sm,
                  children: trendingTopics.take(8).map((topic) {
                    return ActionChip(
                      avatar: const Icon(
                        Icons.trending_up,
                        size: 14,
                        color: AppColors.primaryContainer,
                      ),
                      label: Text(
                        topic,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      side: const BorderSide(color: AppColors.outlineVariant),
                      backgroundColor: AppColors.surfaceContainerHigh,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _selectTrending(topic),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
            ],

            // ── Browse categories header ───────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.base,
                trendingTopics.isEmpty ? AppDimensions.md : 0,
                AppDimensions.base,
                AppDimensions.sm,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      size: 18,
                      color: AppColors.primaryContainer,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stepLabel,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.xs),
                          Text(
                            _selectedField == null
                                ? 'Start broad with an academic field.'
                                : 'Narrow the selection for better results.',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Breadcrumb ───────────────────────────────────────────────────
            if (_deepestSelection != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.base,
                  0,
                  AppDimensions.base,
                  AppDimensions.sm,
                ),
                child: _buildBreadcrumb(),
              ),

            // ── Cascade list ──────────────────────────────────────────────────
            Flexible(child: _buildCurrentLevel()),

            // ── Confirm / reset ───────────────────────────────────────────────
            if (_deepestSelection != null) ...[
              const Divider(height: 1),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => setState(() {
                            _selectedField = null;
                            _selectedSubfield = null;
                            _selectedTopic = null;
                          }),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () => _pop(_deepestSelection),
                          icon: const Icon(Icons.search, size: 18),
                          label: Text(
                            'Search',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final items = <Widget>[];

    void addCrumb(String label, VoidCallback onTap) {
      items.add(
        GestureDetector(
          onTap: onTap,
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primaryContainer,
            ),
          ),
        ),
      );
    }

    if (_selectedField != null) {
      addCrumb(_selectedField!.displayName, () {
        setState(() {
          _selectedSubfield = null;
          _selectedTopic = null;
        });
      });
    }
    if (_selectedSubfield != null) {
      items.add(const Text(' › ', style: TextStyle(fontSize: 12)));
      addCrumb(_selectedSubfield!.displayName, () {
        setState(() => _selectedTopic = null);
      });
    }
    if (_selectedTopic != null) {
      items.add(const Text(' › ', style: TextStyle(fontSize: 12)));
      items.add(
        Text(
          _selectedTopic!.displayName,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: items),
    );
  }

  Widget _buildCurrentLevel() {
    if (_selectedSubfield != null && _selectedTopic == null) {
      return _TopicList(
        provider: topicsProvider(_selectedSubfield!.id),
        levelLabel: 'Topic',
        onSelect: (item) => setState(() => _selectedTopic = item),
        cardStyle: true,
      );
    }
    if (_selectedField != null && _selectedSubfield == null) {
      return _TopicList(
        provider: subfieldsProvider(_selectedField!.id),
        levelLabel: 'Subfield',
        onSelect: (item) => setState(() => _selectedSubfield = item),
        cardStyle: true,
      );
    }
    // Default: show all ~19 OpenAlex fields (no domain filter)
    return _TopicList(
      provider: fieldsProvider(null),
      levelLabel: 'Field',
      onSelect: (item) => setState(() => _selectedField = item),
      cardStyle: true,
    );
  }
}
