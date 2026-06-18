import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/publication.dart';
import '../providers/bookmark_providers.dart';
import '../widgets/publication_card.dart';

enum _BookmarkSort { citations, yearNewest, yearOldest, title }

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  final _searchController = TextEditingController();
  final _yearController = TextEditingController();
  String _query = '';
  int? _selectedYear;
  _BookmarkSort _sort = _BookmarkSort.citations;

  @override
  void dispose() {
    _searchController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookmarkNotifierProvider);
    final hasItems = state.value?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Saved Papers'),
        backgroundColor: AppColors.surfaceContainerLowest,
        actions: [
          if (hasItems)
            TextButton(
              onPressed: () => _confirmClearAll(context, ref),
              child: Text(
                'Clear all',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primaryContainer,
                ),
              ),
            ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (pubs) {
          if (pubs.isEmpty) return const _EmptyBookmarks();
          final visiblePubs = _applySearchFilterAndSort(pubs);
          final availableYears = _availableYears(pubs);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SavedPaperControls(
                controller: _searchController,
                yearController: _yearController,
                query: _query,
                selectedYear: _selectedYear,
                availableYears: availableYears,
                sort: _sort,
                onQueryChanged: (value) {
                  setState(() => _query = value.trim().toLowerCase());
                },
                onClearQuery: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                onYearChanged: _setYearFilter,
                onClearYear: () => _setYearFilter(null),
                onSortChanged: (value) => setState(() => _sort = value),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.base,
                  AppDimensions.sm,
                  AppDimensions.base,
                  AppDimensions.sm,
                ),
                child: Text(
                  '${visiblePubs.length} of ${pubs.length} saved paper${pubs.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.outlineVariant),
              Expanded(
                child: visiblePubs.isEmpty
                    ? _NoSavedPaperMatches(onClear: _resetControls)
                    : ListView.separated(
                        itemCount: visiblePubs.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: AppDimensions.base,
                          endIndent: AppDimensions.base,
                        ),
                        itemBuilder: (context, i) {
                          final pub = visiblePubs[i];
                          return PublicationCard(
                            publication: pub,
                            onTap: () => context.push(
                              '/publication/${Uri.encodeComponent(pub.id)}',
                              extra: pub,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Publication> _applySearchFilterAndSort(List<Publication> pubs) {
    final filtered = pubs.where((pub) {
      final matchesSearch =
          _query.isEmpty ||
          pub.title.toLowerCase().contains(_query) ||
          (pub.journalName?.toLowerCase().contains(_query) ?? false) ||
          pub.authors.any(
            (a) => a.displayName.toLowerCase().contains(_query),
          ) ||
          pub.concepts.any((topic) => topic.toLowerCase().contains(_query));
      if (!matchesSearch) return false;

      final year = pub.publicationYear;
      return _selectedYear == null || year == _selectedYear;
    }).toList();

    switch (_sort) {
      case _BookmarkSort.citations:
        filtered.sort((a, b) => b.citedByCount.compareTo(a.citedByCount));
      case _BookmarkSort.yearNewest:
        filtered.sort(
          (a, b) => (b.publicationYear ?? 0).compareTo(a.publicationYear ?? 0),
        );
      case _BookmarkSort.yearOldest:
        filtered.sort(
          (a, b) =>
              (a.publicationYear ?? 9999).compareTo(b.publicationYear ?? 9999),
        );
      case _BookmarkSort.title:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
    }

    return filtered;
  }

  List<int> _availableYears(List<Publication> pubs) {
    final publicationYears = pubs
        .map((pub) => pub.publicationYear)
        .whereType<int>()
        .toList();
    final currentYear = DateTime.now().year;
    final earliestYear = publicationYears.isEmpty
        ? currentYear
        : publicationYears.reduce((a, b) => a < b ? a : b);
    final years = <int>[];
    for (var year = currentYear; year >= earliestYear; year--) {
      years.add(year);
    }
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  void _setYearFilter(int? year) {
    _yearController.text = year?.toString() ?? '';
    setState(() => _selectedYear = year);
  }

  void _resetControls() {
    _searchController.clear();
    _yearController.clear();
    setState(() {
      _query = '';
      _selectedYear = null;
      _sort = _BookmarkSort.citations;
    });
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all bookmarks?'),
        content: const Text('This will remove all saved papers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Clear', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final notifier = ref.read(bookmarkNotifierProvider.notifier);
      final all = ref.read(bookmarkNotifierProvider).value ?? [];
      for (final pub in all) {
        await notifier.toggle(pub);
      }
    }
  }
}

class _SavedPaperControls extends StatelessWidget {
  final TextEditingController controller;
  final TextEditingController yearController;
  final String query;
  final int? selectedYear;
  final List<int> availableYears;
  final _BookmarkSort sort;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onClearYear;
  final ValueChanged<_BookmarkSort> onSortChanged;

  const _SavedPaperControls({
    required this.controller,
    required this.yearController,
    required this.query,
    required this.selectedYear,
    required this.availableYears,
    required this.sort,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onYearChanged,
    required this.onClearYear,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.base,
        AppDimensions.md,
        AppDimensions.base,
        AppDimensions.sm,
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Search saved papers',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: onClearQuery,
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: AppDimensions.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackControls = constraints.maxWidth < 360;
              final yearFilter = _YearFilter(
                controller: yearController,
                selectedYear: selectedYear,
                availableYears: availableYears,
                onChanged: onYearChanged,
                onClear: onClearYear,
              );
              final sortMenu = _SortMenu(value: sort, onChanged: onSortChanged);

              if (stackControls) {
                return Column(
                  children: [
                    yearFilter,
                    const SizedBox(height: AppDimensions.sm),
                    sortMenu,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: yearFilter),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(child: sortMenu),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _YearFilter extends StatelessWidget {
  final TextEditingController controller;
  final int? selectedYear;
  final List<int> availableYears;
  final ValueChanged<int?> onChanged;
  final VoidCallback onClear;

  const _YearFilter({
    required this.controller,
    required this.selectedYear,
    required this.availableYears,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<int>(
      initialValue: TextEditingValue(text: selectedYear?.toString() ?? ''),
      displayStringForOption: (year) => year.toString(),
      optionsBuilder: (value) {
        final query = value.text.trim();
        if (query.isEmpty) return availableYears;
        return availableYears.where((year) => year.toString().contains(query));
      },
      onSelected: (year) {
        controller.text = year.toString();
        onChanged(year);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            if (controller.text != textEditingController.text) {
              textEditingController.text = controller.text;
            }
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'All years',
                prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                suffixIcon: selectedYear != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          textEditingController.clear();
                          onClear();
                        },
                      )
                    : const Icon(Icons.arrow_drop_down),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (value) {
                controller.text = value;
                onChanged(int.tryParse(value.trim()));
              },
              onSubmitted: (_) => onFieldSubmitted(),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 240),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.outlineVariant),
                itemBuilder: (context, index) {
                  final year = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(year.toString()),
                    onTap: () => onSelected(year),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SortMenu extends StatelessWidget {
  final _BookmarkSort value;
  final ValueChanged<_BookmarkSort> onChanged;

  const _SortMenu({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<_BookmarkSort>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.sort, size: 20),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: const [
        DropdownMenuItem(
          value: _BookmarkSort.citations,
          child: Text('Citations'),
        ),
        DropdownMenuItem(
          value: _BookmarkSort.yearNewest,
          child: Text('Newest'),
        ),
        DropdownMenuItem(
          value: _BookmarkSort.yearOldest,
          child: Text('Oldest'),
        ),
        DropdownMenuItem(value: _BookmarkSort.title, child: Text('Title')),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _NoSavedPaperMatches extends StatelessWidget {
  final VoidCallback onClear;

  const _NoSavedPaperMatches({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off,
            size: 56,
            color: AppColors.outlineVariant,
          ),
          const SizedBox(height: AppDimensions.base),
          Text(
            'No saved papers match',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ),
    );
  }
}

class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bookmark_border,
            size: 64,
            color: AppColors.outlineVariant,
          ),
          const SizedBox(height: AppDimensions.base),
          Text(
            'No saved papers yet',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
            child: Text(
              'Tap the bookmark icon on any paper to save it here.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
