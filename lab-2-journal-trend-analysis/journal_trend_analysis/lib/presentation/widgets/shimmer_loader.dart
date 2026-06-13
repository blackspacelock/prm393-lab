import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';

class ShimmerLoader extends StatelessWidget {
  final int itemCount;

  const ShimmerLoader({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading...',
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: AppDimensions.base,
          endIndent: AppDimensions.base,
          color: AppColors.outlineVariant,
        ),
        itemBuilder: (_, _) => Shimmer.fromColors(
          baseColor: AppColors.surfaceContainerHigh,
          highlightColor: AppColors.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.shapeXs),
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.shapeXs),
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: [
                    Container(
                      height: 10,
                      width: 60,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.shapeXs),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.shapeXs),
                      ),
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
