import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/publication.dart';
import '../widgets/author_chip.dart';

class PublicationDetailScreen extends StatelessWidget {
  final Publication publication;

  const PublicationDetailScreen({super.key, required this.publication});

  Future<void> _openDoi(BuildContext context) async {
    final doi = publication.doi;
    if (doi == null) return;

    final raw = doi.startsWith('http') ? doi : 'https://doi.org/$doi';
    final uri = Uri.parse(raw);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open DOI link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final abstract =
        Formatter.reconstructAbstract(publication.abstractInvertedIndex);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: BackButton(color: AppColors.primaryContainer),
        title: const Text('Publication Details'),
        backgroundColor: AppColors.surfaceContainerLowest,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: publication.doi != null
          ? Container(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.base,
                AppDimensions.md,
                AppDimensions.base,
                AppDimensions.base,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(
                      color: AppColors.outlineVariant, width: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openDoi(context),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open paper'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.onPrimary,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    publication.doi!,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.base,
          AppDimensions.base,
          AppDimensions.base,
          AppDimensions.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero title
            Text(
              publication.title,
              style: AppTextStyles.headlineMedium
                  .copyWith(color: AppColors.onSurface),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppDimensions.md),

            // Metadata pills
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                if (publication.publicationYear != null)
                  _InfoChip(
                    label:
                        Formatter.formatYear(publication.publicationYear),
                  ),
                if (publication.journalName != null)
                  _InfoChip(label: publication.journalName!),
                if (publication.doi != null)
                  _DoiChip(
                    doi: publication.doi!,
                    onTap: () => _openDoi(context),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.base),

            // Citation card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.base),
              decoration: BoxDecoration(
                color: AppColors.citationChipBg,
                borderRadius:
                    BorderRadius.circular(AppDimensions.shapeMd),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 24,
                    color: AppColors.primaryContainer,
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Text(
                    Formatter.formatCitationCount(
                        publication.citedByCount),
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Text(
                    'citations',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.base),

            // Authors section
            if (publication.authors.isNotEmpty) ...[
              Text(
                'Authors',
                style: AppTextStyles.titleLarge
                    .copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: AppDimensions.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0;
                        i < publication.authors.length;
                        i++) ...[
                      if (i > 0)
                        const SizedBox(width: AppDimensions.sm),
                      AuthorChip(
                          displayName:
                              publication.authors[i].displayName),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.base),
            ],

            // Abstract
            if (abstract.isNotEmpty) ...[
              Text(
                'Abstract',
                style: AppTextStyles.titleLarge
                    .copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: AppDimensions.sm),
              _ExpandableAbstract(text: abstract),
              const SizedBox(height: AppDimensions.base),
            ],

            // Research topics
            if (publication.concepts.isNotEmpty) ...[
              Text(
                'Research Topics',
                style: AppTextStyles.titleLarge
                    .copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: publication.concepts
                    .take(10)
                    .map(
                      (c) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.md,
                          vertical: AppDimensions.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.shapeSm),
                        ),
                        child: Text(
                          c,
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.onSurface),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppDimensions.base),
            ],

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _StatMiniCard(
                    label: 'Year',
                    value: Formatter.formatYear(
                        publication.publicationYear),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: _StatMiniCard(
                    label: 'Authors',
                    value: publication.authors.length.toString(),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: _StatMiniCard(
                    label: 'Journal',
                    value: publication.journalName ?? 'N/A',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

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
        style: AppTextStyles.bodySmall
            .copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

class _DoiChip extends StatelessWidget {
  final String doi;
  final VoidCallback onTap;
  const _DoiChip({required this.doi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: AppDimensions.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.citationChipBg,
          borderRadius: BorderRadius.circular(AppDimensions.shapeXs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DOI',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.primaryContainer),
            ),
            const SizedBox(width: AppDimensions.xs),
            const Icon(
              Icons.open_in_new,
              size: 16,
              color: AppColors.primaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatMiniCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            value,
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ExpandableAbstract extends StatefulWidget {
  final String text;
  const _ExpandableAbstract({required this.text});

  @override
  State<_ExpandableAbstract> createState() => _ExpandableAbstractState();
}

class _ExpandableAbstractState extends State<_ExpandableAbstract> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Text(
              widget.text,
              style: AppTextStyles.bodyLarge
                  .copyWith(color: AppColors.onSurface),
              maxLines: _expanded ? null : 4,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.clip,
            ),
            if (!_expanded)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.surface.withValues(alpha: 0),
                        AppColors.surface,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.xs),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Show less' : 'Show more',
            style: AppTextStyles.labelLarge
                .copyWith(color: AppColors.primaryContainer),
          ),
        ),
      ],
    );
  }
}
