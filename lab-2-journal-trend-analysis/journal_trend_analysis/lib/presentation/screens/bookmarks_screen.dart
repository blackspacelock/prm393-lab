import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/bookmark_providers.dart';
import '../widgets/publication_card.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.base,
                  AppDimensions.md,
                  AppDimensions.base,
                  AppDimensions.sm,
                ),
                child: Text(
                  '${pubs.length} saved paper${pubs.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.outlineVariant),
              Expanded(
                child: ListView.separated(
                  itemCount: pubs.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: AppDimensions.base,
                    endIndent: AppDimensions.base,
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
                ),
              ),
            ],
          );
        },
      ),
    );
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
            child: Text(
              'Clear',
              style: TextStyle(color: Colors.red.shade700),
            ),
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
