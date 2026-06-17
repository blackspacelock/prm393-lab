import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';

class RankedListTile extends StatefulWidget {
  final int rank;
  final String title;
  final String subtitle;
  final int count;
  final int maxCount;
  final Widget? leading;
  final VoidCallback? onTap;

  const RankedListTile({
    super.key,
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.maxCount,
    this.leading,
    this.onTap,
  });

  @override
  State<RankedListTile> createState() => _RankedListTileState();
}

class _RankedListTileState extends State<RankedListTile> {
  bool _hovering = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final paperLabel = widget.count == 1 ? 'paper' : 'papers';
    final isActive = _hovering || _pressing;

    return MouseRegion(
      onEnter: widget.onTap != null
          ? (_) => setState(() => _hovering = true)
          : null,
      onExit: widget.onTap != null
          ? (_) => setState(() => _hovering = false)
          : null,
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _pressing = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) => setState(() => _pressing = false)
            : null,
        onTapCancel: widget.onTap != null
            ? () => setState(() => _pressing = false)
            : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.base,
            vertical: AppDimensions.sm,
          ),
          decoration: BoxDecoration(
            color: isActive && widget.onTap != null
                ? AppColors.primaryContainer.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              widget.leading ?? _RankBadge(rank: widget.rank),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isActive && widget.onTap != null
                            ? AppColors.primaryContainer
                            : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              _CountBadge(label: '${widget.count} $paperLabel'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;

  const _CountBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
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
      radius: 16,
      backgroundColor: bg,
      child: Text(
        rank.toString(),
        style: AppTextStyles.labelLarge.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
