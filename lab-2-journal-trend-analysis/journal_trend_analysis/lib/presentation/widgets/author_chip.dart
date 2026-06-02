import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';

class AuthorChip extends StatelessWidget {
  final String displayName;

  const AuthorChip({super.key, required this.displayName});

  String get _initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      padding: const EdgeInsets.only(left: 4, top: 4, right: 12, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.citationChipBg,
            child: Text(
              _initials,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.citationChipText,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Text(
            displayName,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }
}
