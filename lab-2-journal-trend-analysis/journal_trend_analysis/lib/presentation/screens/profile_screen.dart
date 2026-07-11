import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/auth_providers.dart';
import '../providers/providers.dart';
import '../providers/report_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/remote_config_providers.dart';
import '../../firebase/crashlytics_service.dart';

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
          const _UserCard(),
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
          const _NotificationCenter(),
          const SizedBox(height: AppDimensions.sm),
          const _PdfExportCard(),
          const SizedBox(height: AppDimensions.sm),
          const _RemoteConfigCard(),
          const SizedBox(height: AppDimensions.sm),
          const _CrashlyticsCard(),
        ],
      ),
    );
  }
}

class _CrashlyticsCard extends StatelessWidget {
  const _CrashlyticsCard();

  Future<void> _handled(BuildContext context) async {
    await crashlyticsService.recordHandledException();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Handled exception recorded.')),
      );
    }
  }

  Future<void> _crash(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crash the app?'),
        content: const Text(
          'The app will close immediately. Reopen it to upload the test crash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmTestCrashButton'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Crash app'),
          ),
        ],
      ),
    );
    if (confirmed == true) crashlyticsService.testCrash();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.bug_report_outlined,
                color: AppColors.primaryContainer,
              ),
              title: Text('Crashlytics Demo'),
              subtitle: Text('Send non-fatal and fatal test reports.'),
            ),
            Wrap(
              spacing: AppDimensions.sm,
              children: [
                FilledButton.tonal(
                  key: const Key('handledExceptionButton'),
                  onPressed: () => _handled(context),
                  child: const Text('Handled exception'),
                ),
                FilledButton.tonal(
                  key: const Key('testCrashButton'),
                  onPressed: () => _crash(context),
                  child: const Text('Test crash'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteConfigCard extends ConsumerWidget {
  const _RemoteConfigCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limits = ref.watch(remoteLimitsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.tune_outlined,
                color: AppColors.primaryContainer,
              ),
              title: const Text('Remote Config'),
              subtitle: const Text('Display limits controlled by Firebase.'),
              trailing: IconButton(
                key: const Key('refreshRemoteConfigButton'),
                tooltip: 'Refresh Remote Config',
                onPressed: () => ref.invalidate(remoteLimitsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            limits.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Remote Config failed: $error'),
              data: (value) => Column(
                key: const Key('remoteConfigValues'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maximum journals displayed: ${value.maxJournals}'),
                  Text('Maximum keywords displayed: ${value.maxKeywords}'),
                  Text(
                    value.updated
                        ? 'New values activated.'
                        : 'Using current or default values.',
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

class _NotificationCenter extends ConsumerStatefulWidget {
  const _NotificationCenter();

  @override
  ConsumerState<_NotificationCenter> createState() =>
      _NotificationCenterState();
}

class _NotificationCenterState extends ConsumerState<_NotificationCenter> {
  bool _enabling = false;
  String? _token;

  Future<void> _enable() async {
    setState(() => _enabling = true);
    try {
      final token = await ref.read(notificationServiceProvider).enable();
      if (mounted) setState(() => _token = token);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notifications failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(notificationHistoryProvider).value ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.notifications_outlined,
                color: AppColors.primaryContainer,
              ),
              title: const Text('Notification Center'),
              subtitle: Text(
                history.isEmpty
                    ? 'No notifications received yet.'
                    : '${history.length} notification(s)',
              ),
              trailing: FilledButton.tonal(
                key: const Key('enableNotificationsButton'),
                onPressed: _enabling ? null : _enable,
                child: _enabling
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enable'),
              ),
            ),
            if (_token != null) ...[
              const Text('FCM test token:'),
              SelectableText(_token!, key: const Key('fcmToken')),
              const SizedBox(height: AppDimensions.sm),
            ],
            ...history.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.title),
                subtitle: Text(item.body),
                trailing: Text(
                  '${item.receivedAt.hour.toString().padLeft(2, '0')}:${item.receivedAt.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfExportCard extends ConsumerStatefulWidget {
  const _PdfExportCard();

  @override
  ConsumerState<_PdfExportCard> createState() => _PdfExportCardState();
}

class _PdfExportCardState extends ConsumerState<_PdfExportCard> {
  bool _uploading = false;
  String? _url;

  Future<void> _export() async {
    final user = ref.read(authStateProvider).value;
    final topic = ref.read(searchQueryProvider).trim();
    final publications = ref.read(publicationsProvider).value ?? [];
    if (user == null || topic.isEmpty || publications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search for a topic before exporting.')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final url = await ref.read(reportServiceProvider).export(
        userId: user.uid,
        topic: topic,
        summary: ref.read(dashboardSummaryProvider),
        authors: ref.read(topAuthorsProvider),
        journals: ref.read(topJournalsProvider),
        publications: publications,
      );
      if (mounted) setState(() => _url = url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.primaryContainer,
              ),
              title: const Text('Export PDF Report'),
              subtitle: const Text(
                'Generate and upload analytics for the active topic.',
              ),
              trailing: FilledButton.tonal(
                key: const Key('exportPdfButton'),
                onPressed: _uploading ? null : _export,
                child: _uploading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Export'),
              ),
            ),
            if (_url != null) ...[
              const SizedBox(height: AppDimensions.sm),
              const Text('Uploaded file URL:'),
              SelectableText(_url!, key: const Key('uploadedPdfUrl')),
            ],
          ],
        ),
      ),
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────────────

class _UserCard extends ConsumerWidget {
  const _UserCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppDimensions.base),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.12),
          backgroundImage: user?.photoURL == null
              ? null
              : NetworkImage(user!.photoURL!),
          child: user?.photoURL == null
              ? const Icon(Icons.person, color: AppColors.primaryContainer)
              : null,
        ),
        title: Text(
          user?.displayName ?? 'Google user',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          user?.email ?? '',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        trailing: TextButton(
          key: const Key('signOutButton'),
          onPressed: () async {
            try {
              await ref.read(authServiceProvider).signOut();
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sign out failed: $error')),
                );
              }
            }
          },
          child: const Text('Sign Out'),
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
