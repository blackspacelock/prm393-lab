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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Saved Papers'),
        backgroundColor: AppColors.surfaceContainerLowest,
        actions: [
          state.whenOrNull(
            data: (bookmarks) => bookmarks.isNotEmpty
                ? TextButton(
                    onPressed: () => _confirmClearAll(context, ref),
                    child: Text(
                      'Clear all',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  )
                : null,
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return _EmptyBookmarks();
          }
          return ListView.separated(
            itemCount: bookmarks.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              indent: AppDimensions.base,
              endIndent: AppDimensions.base,
            ),
            itemBuilder: (context, i) {
              final pub = bookmarks[i];
              return PublicationCard(
                publication: pub,
                onTap: () => context.push('/publication/${pub.id}', extra: pub),
              );
            },
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
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
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
          Text(
            'Tap the bookmark icon on any paper to save it here.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
