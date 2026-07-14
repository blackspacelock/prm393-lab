import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../providers/auth_providers.dart';
import '../providers/providers.dart';
import '../providers/report_providers.dart';
import '../providers/notification_providers.dart';
import '../../firebase/crashlytics_service.dart';

/// Profile page with user info, navigation to saved papers, and upcoming features.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.value == null) return const _GuestProfile();

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
          const _CrashlyticsActions(),
        ],
      ),
    );
  }
}

class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(AppDimensions.base),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: AppColors.primaryContainer,
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  'Sign in to use profile features',
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.sm),
                const Text(
                  'Saved papers, notifications, and PDF reports require an account.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.lg),
                FilledButton.icon(
                  key: const Key('guestSignInButton'),
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CrashlyticsActions extends StatelessWidget {
  const _CrashlyticsActions();

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
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            key: const Key('handledExceptionButton'),
            tooltip: 'Test handled exception',
            onPressed: () => _handled(context),
            icon: const Icon(Icons.bug_report_outlined),
          ),
          const SizedBox(width: AppDimensions.sm),
          IconButton.filledTonal(
            key: const Key('testCrashButton'),
            tooltip: 'Test fatal crash',
            onPressed: () => _crash(context),
            icon: const Icon(Icons.warning_amber_rounded),
          ),
        ],
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

  Future<void> _enable() async {
    setState(() => _enabling = true);
    try {
      await ref.read(notificationServiceProvider).enable();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notifications enabled.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Notifications failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _enabling = false);
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
                Icons.notifications_outlined,
                color: AppColors.primaryContainer,
              ),
              title: const Text('Notification Center'),
              subtitle: const Text('Receive research update notifications.'),
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
      final url = await ref
          .read(reportServiceProvider)
          .export(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openPdf() async {
    final url = _url;
    if (url == null) return;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the PDF link.')),
      );
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
              OutlinedButton.icon(
                key: const Key('openPdfButton'),
                onPressed: _openPdf,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open PDF'),
              ),
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
