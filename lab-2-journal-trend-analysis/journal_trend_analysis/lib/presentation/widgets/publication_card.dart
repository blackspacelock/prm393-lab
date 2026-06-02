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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.base,
          vertical: 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    publication.title,
                    style: AppTextStyles.titleLarge
                        .copyWith(color: AppColors.onSurface),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (publication.journalName != null) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      publication.journalName!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppDimensions.sm),
                  Row(
                    children: [
                      _MetaChip(
                          label: Formatter.formatYear(
                              publication.publicationYear)),
                      const SizedBox(width: AppDimensions.xs),
                      _MetaChip(
                          label:
                              '${Formatter.formatCitationCount(publication.citedByCount)} cited'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Column(
              children: [
                const Icon(
                  Icons.star_outline,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  Formatter.formatCitationCount(publication.citedByCount),
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
