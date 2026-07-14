import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/publication.dart';
import '../providers/bookmark_providers.dart';

class PublicationCard extends ConsumerWidget {
  final Publication publication;
  final VoidCallback? onTap;

  const PublicationCard({super.key, required this.publication, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBookmarked = ref.watch(isBookmarkedProvider(publication.id));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppDimensions.base,
              right: AppDimensions.xs,
              top: AppDimensions.md,
              bottom: AppDimensions.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        publication.title,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (publication.journalName != null) ...[
                        const SizedBox(height: AppDimensions.xs),
                        Text(
                          publication.journalName!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppDimensions.sm),
                      Wrap(
                        spacing: AppDimensions.xs,
                        runSpacing: AppDimensions.xs,
                        children: [
                          _MetaChip(
                            label: Formatter.formatYear(
                              publication.publicationYear,
                            ),
                          ),
                          _MetaChip(
                            label:
                                '${Formatter.formatCitationCount(publication.citedByCount)} cited',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 22,
                    color: isBookmarked
                        ? AppColors.primaryContainer
                        : AppColors.onSurfaceVariant,
                  ),
                  tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
                  onPressed: () async {
                    final allowed = await ref
                        .read(bookmarkNotifierProvider.notifier)
                        .toggle(publication);
                    if (!allowed && context.mounted) context.push('/login');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}
