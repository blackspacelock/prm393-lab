import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/topic_hierarchy.dart';
import '../providers/providers.dart';

/// A cascading filter dialog that lets users drill down:
/// Domain → Field → Subfield → Topic
/// User can confirm selection at any level.
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

  /// The deepest selection the user has made.
  TopicHierarchyItem? get _deepestSelection =>
      _selectedTopic ?? _selectedSubfield ?? _selectedField ?? _selectedDomain;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimensions.base),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
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

            // Breadcrumb
            if (_deepestSelection != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.base,
                  vertical: AppDimensions.sm,
                ),
                child: _buildBreadcrumb(),
              ),

            const Divider(height: 1),

            // Content
            Flexible(child: _buildCurrentLevel()),

            // Actions
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

  const _TopicList({
    required this.provider,
    required this.levelLabel,
    required this.onSelect,
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
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
