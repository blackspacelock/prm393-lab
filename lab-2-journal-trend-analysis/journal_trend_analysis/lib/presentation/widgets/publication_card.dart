import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/publication.dart';

class PublicationCard extends StatelessWidget {
  final Publication publication;
  final VoidCallback? onTap;

  const PublicationCard({super.key, required this.publication, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.base,
              vertical: AppDimensions.md,
            ),
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
                      label: Formatter.formatYear(publication.publicationYear),
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
