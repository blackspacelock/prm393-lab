import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';

class RankedListTile extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final int count;
  final int maxCount;
  final Widget? leading;

  const RankedListTile({
    super.key,
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.maxCount,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxCount > 0 ? (count / maxCount).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.base,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading ?? _RankBadge(rank: rank),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppDimensions.sm),
                SizedBox(
                  width: 80,
                  height: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      color: AppColors.primaryContainer,
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Text(
            count.toString(),
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.primaryContainer),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (rank) {
      1 => (AppColors.rankGold, AppColors.rankGoldText),
      2 => (AppColors.rankSilver, AppColors.rankSilverText),
      3 => (AppColors.rankBronze, AppColors.rankBronzeText),
      _ => (AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant),
    };

    return CircleAvatar(
      radius: 18,
      backgroundColor: bg,
      child: Text(
        rank.toString(),
        style: AppTextStyles.titleMedium.copyWith(color: fg),
      ),
    );
  }
}
