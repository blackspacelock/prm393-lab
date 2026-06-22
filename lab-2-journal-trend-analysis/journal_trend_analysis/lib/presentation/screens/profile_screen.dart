import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';

/// Profile page with user info, navigation to saved papers, and upcoming features.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.base),
        children: [
          const _PlaceholderUserCard(),
          const SizedBox(height: AppDimensions.lg),
          // Saved Paper action box (UR-01)
          _ProfileActionSection(
            icon: Icons.bookmark_outline,
            title: 'Saved Papers',
            detail: 'Review and filter the publications you bookmarked.',
            onTap: () => context.push('/profile/bookmarks'),
          ),
          const SizedBox(height: AppDimensions.sm),
          // Upcoming features
          _ComingSection(
            icon: Icons.notifications_outlined,
            title: 'Notification Center',
            phaseBadge: 'Phase B7',
            detail:
                'Push notifications and received message history appear here.',
          ),
          const SizedBox(height: AppDimensions.sm),
          const _ComingSection(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Export PDF Report',
            phaseBadge: 'Phase B6',
            detail: 'Generate and upload PDF reports for the active topic.',
          ),
          const SizedBox(height: AppDimensions.sm),
          const _ComingSection(
            icon: Icons.tune_outlined,
            title: 'Remote Config',
            phaseBadge: 'Phase B8',
            detail:
                'Runtime configuration values will be displayed and refreshed here.',
          ),
          const SizedBox(height: AppDimensions.sm),
          const _ComingSection(
            icon: Icons.bug_report_outlined,
            title: 'Crashlytics Demo',
            phaseBadge: 'Phase B9',
            detail:
                'Crash logging controls and demo actions are added in Phase B.',
          ),
        ],
      ),
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────────────

class _PlaceholderUserCard extends StatelessWidget {
  const _PlaceholderUserCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.base),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.12),
          child: const Icon(Icons.person, color: AppColors.primaryContainer),
        ),
        title: Text(
          'Guest User',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Sign in to see your profile',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        trailing: FilledButton.tonal(
          onPressed: () {},
          child: const Text('Sign In'),
        ),
      ),
    );
  }
}

// ── Saved Paper Action Section ────────────────────────────────────────────────

class _ProfileActionSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  const _ProfileActionSection({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.base),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
                ),
                child: Icon(icon, color: AppColors.primaryContainer),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xs),
                    Text(
                      detail,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              const Icon(
                Icons.chevron_right,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Coming Soon Section ───────────────────────────────────────────────────────

class _ComingSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String phaseBadge;
  final String detail;

  const _ComingSection({
    required this.icon,
    required this.title,
    required this.phaseBadge,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.base),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
              ),
              child: Icon(icon, color: AppColors.primaryContainer),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _PhaseBadge(label: phaseBadge),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    detail,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  final String label;

  const _PhaseBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.shapeFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
