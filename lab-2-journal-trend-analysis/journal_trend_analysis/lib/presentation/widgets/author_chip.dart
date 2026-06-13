import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
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
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: AppColors.citationChipBg,
        child: Text(
          _initials,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.citationChipText,
          ),
        ),
      ),
      label: Text(
        displayName,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface),
      ),
      backgroundColor: AppColors.surfaceContainerLowest,
      side: const BorderSide(color: AppColors.outlineVariant),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
