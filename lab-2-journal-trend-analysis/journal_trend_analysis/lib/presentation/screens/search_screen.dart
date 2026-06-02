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

const _suggestions = [
  'AI',
  'Software Engineering',
  'Data Science',
  'Cybersecurity',
  'IoT',
  'Blockchain',
];

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    ref.read(searchQueryProvider.notifier).state = trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final pubAsync = ref.watch(publicationsProvider);
    final query = ref.watch(searchQueryProvider);

    ref.listen(publicationsProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.error}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => ref.invalidate(publicationsProvider),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Trend Analyzer'),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: const Icon(
          Icons.analytics,
          color: AppColors.onSurfaceVariant,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.base,
              AppDimensions.md,
              AppDimensions.base,
              0,
            ),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search research topics…',
                hintStyle: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.shapeFull),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.shapeFull),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.shapeFull),
                  borderSide: const BorderSide(
                    color: AppColors.primaryContainer,
                    width: 2,
                  ),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.base),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppDimensions.sm),
              itemBuilder: (_, i) {
                final selected = query == _suggestions[i];
                return FilterChip(
                  label: Text(_suggestions[i]),
                  selected: selected,
                  onSelected: (_) {
                    _controller.text = _suggestions[i];
                    _submit(_suggestions[i]);
                  },
                  backgroundColor: AppColors.surfaceContainerHighest,
                  selectedColor: AppColors.secondaryContainer,
                  labelStyle: AppTextStyles.labelLarge.copyWith(
                    color: selected
                        ? AppColors.onSecondaryContainer
                        : AppColors.onSurfaceVariant,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primaryContainer
                        : AppColors.outlineVariant,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.shapeSm),
                  ),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Expanded(
            child: pubAsync.when(
              loading: () => const ShimmerLoader(),
              error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(publicationsProvider),
              ),
              data: (pubs) {
                if (pubs.isEmpty) {
                  return EmptyState(
                    icon: Icons.find_in_page,
                    message: query.isEmpty
                        ? 'Search for publications above'
                        : 'No results found for "$query"',
                    actionLabel: query.isNotEmpty ? 'Clear' : null,
                    onAction: query.isNotEmpty
                        ? () {
                            _controller.clear();
                            ref
                                .read(searchQueryProvider.notifier)
                                .state = '';
                          }
                        : null,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppDimensions.base,
                        bottom: AppDimensions.xs,
                      ),
                      child: Text(
                        "Results for '$query' · ${pubs.length} papers",
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: pubs.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: AppDimensions.base,
                          endIndent: AppDimensions.base,
                          color: AppColors.outlineVariant,
                        ),
                        itemBuilder: (_, i) => PublicationCard(
                          publication: pubs[i],
                          onTap: () => context.push(
                            '/publication/${Uri.encodeComponent(pubs[i].id)}',
                            extra: pubs[i],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
