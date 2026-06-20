import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/export_helper.dart';
import '../../core/utils/formatter.dart';
import '../../domain/entities/publication.dart';
import '../providers/bookmark_providers.dart';
import '../providers/providers.dart';
import '../widgets/author_chip.dart';

class PublicationDetailScreen extends ConsumerWidget {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open DOI link')));
    }
  }

  void _searchText(BuildContext context, WidgetRef ref, String text) {
    ref.read(selectedTopicFilterProvider.notifier).state = null;
    ref.read(searchPageProvider.notifier).state = 1;
    ref.read(searchQueryProvider.notifier).state = text;
    context.go('/keywords');
  }

  Future<void> _openExportSheet(BuildContext context) async {
    final format = await showModalBottomSheet<_PaperExportFormat>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.shapeMd),
        ),
      ),
      builder: (_) => const _PaperExportSheet(),
    );

    if (format == null || !context.mounted) return;

    switch (format) {
      case _PaperExportFormat.bibtex:
        await Share.share(
          ExportHelper.toBibTeX([publication]),
          subject: '${publication.title} (BibTeX)',
        );
      case _PaperExportFormat.ris:
        await Share.share(
          ExportHelper.toRIS([publication]),
          subject: '${publication.title} (RIS)',
        );
      case _PaperExportFormat.csv:
        await Share.share(
          ExportHelper.toCSV([publication]),
          subject: '${publication.title} (CSV)',
        );
      case _PaperExportFormat.copyText:
        await Clipboard.setData(
          ClipboardData(text: ExportHelper.toPlainCitation(publication)),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Citation copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abstract = Formatter.reconstructAbstract(
      publication.abstractInvertedIndex,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: BackButton(color: AppColors.primaryContainer),
        title: const Text('Publication Details'),
        backgroundColor: AppColors.surfaceContainerLowest,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Export / Share',
            onPressed: () => _openExportSheet(context),
          ),
          Consumer(
            builder: (context, ref, _) {
              final isBookmarked = ref.watch(
                isBookmarkedProvider(publication.id),
              );
              return IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked
                      ? AppColors.primaryContainer
                      : AppColors.onSurfaceVariant,
                ),
                tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
                onPressed: () => ref
                    .read(bookmarkNotifierProvider.notifier)
                    .toggle(publication),
              );
            },
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
                  top: BorderSide(color: AppColors.outlineVariant, width: 0.5),
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
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
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
              style: AppTextStyles.headlineMedium.copyWith(
                fontSize: 22,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimensions.md),

            // Metadata pills
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                if (publication.publicationYear != null)
                  _InfoChip(
                    label: Formatter.formatYear(publication.publicationYear),
                  ),
                if (publication.journalName != null)
                  _JournalChip(label: publication.journalName!),
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
                borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
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
                    Formatter.formatCitationCount(publication.citedByCount),
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Text(
                    'citations',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.base),

            // Citation over years LINE chart
            if (publication.countsByYear.isNotEmpty)
              _CitationLineChart(countsByYear: publication.countsByYear),

            // Authors section — clickable with hover
            if (publication.authors.isNotEmpty) ...[
              Text(
                'Authors',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: publication.authors.map((author) {
                  return _HoverChip(
                    label: author.displayName,
                    onTap: () => _searchText(context, ref, author.displayName),
                    leading: AuthorChip(displayName: author.displayName),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.base),
            ],

            // Abstract
            if (abstract.isNotEmpty) ...[
              Text(
                'Abstract',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              _ExpandableAbstract(text: abstract),
              const SizedBox(height: AppDimensions.base),
            ],

            // Research topics — clickable with hover
            if (publication.concepts.isNotEmpty) ...[
              Text(
                'Research Topics',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: publication.concepts.take(10).map((c) {
                  return _HoverChip(
                    label: c,
                    onTap: () => _searchText(context, ref, c),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.base),
            ],

            // Stats row — journal name full display
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatMiniCard(
                      label: 'Year',
                      value: Formatter.formatYear(publication.publicationYear),
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
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

/// A chip with hover/press effect that searches on tap.
class _HoverChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Widget? leading;

  const _HoverChip({required this.label, required this.onTap, this.leading});

  @override
  State<_HoverChip> createState() => _HoverChipState();
}

class _HoverChipState extends State<_HoverChip> {
  bool _hovering = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _hovering || _pressing;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.xs,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryContainer.withValues(alpha: 0.2)
                : AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
            border: Border.all(
              color: isActive ? AppColors.primaryContainer : Colors.transparent,
              width: 1,
            ),
          ),
          child: widget.leading != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.leading!,
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.label,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: isActive
                              ? AppColors.primaryContainer
                              : AppColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  widget.label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: isActive
                        ? AppColors.primaryContainer
                        : AppColors.onSecondaryContainer,
                  ),
                ),
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
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _JournalChip extends StatelessWidget {
  final String label;
  const _JournalChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Icon(
            Icons.library_books,
            size: 12,
            color: AppColors.primaryContainer,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: AppColors.primaryContainer,
              ),
            ),
          ),
        ],
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
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryContainer,
              ),
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
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onSurface,
            ),
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
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.onSurface,
              ),
              maxLines: _expanded ? null : 4,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.clip,
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
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.primaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

/// Citation LINE chart with total/mean boxes and year filter.
class _CitationLineChart extends StatefulWidget {
  final List<YearlyCitation> countsByYear;
  const _CitationLineChart({required this.countsByYear});

  @override
  State<_CitationLineChart> createState() => _CitationLineChartState();
}

class _CitationLineChartState extends State<_CitationLineChart> {
  int? _fromYear;
  int? _toYear;

  List<YearlyCitation> get _filteredData {
    var data = widget.countsByYear;
    if (_fromYear != null) {
      data = data.where((e) => e.year >= _fromYear!).toList();
    }
    if (_toYear != null) {
      data = data.where((e) => e.year <= _toYear!).toList();
    }
    return data;
  }

  int get _total => _filteredData.fold(0, (s, e) => s + e.citedByCount);
  double get _mean => _filteredData.isEmpty ? 0 : _total / _filteredData.length;

  @override
  Widget build(BuildContext context) {
    final data = _filteredData;
    if (widget.countsByYear.isEmpty) return const SizedBox.shrink();

    final allYears = widget.countsByYear.map((e) => e.year).toList();
    final minYear = allYears.reduce((a, b) => a < b ? a : b);
    final maxYear = allYears.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Citations by Year',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: AppDimensions.sm),

        // Total + Mean
        Row(
          children: [
            Expanded(
              child: _MiniBox(
                label: 'Total',
                value: Formatter.formatCitationCount(_total),
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: _MiniBox(
                label: 'Mean/Year',
                value: _mean.toStringAsFixed(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),

        // Year filter
        Row(
          children: [
            Text('From: ', style: AppTextStyles.labelSmall),
            DropdownButton<int?>(
              value: _fromYear,
              hint: Text('$minYear', style: AppTextStyles.labelSmall),
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...allYears.map(
                  (y) => DropdownMenuItem(value: y, child: Text('$y')),
                ),
              ],
              onChanged: (val) => setState(() {
                _fromYear = val;
                if (_toYear != null && val != null && _toYear! < val) {
                  _toYear = val;
                }
              }),
            ),
            const SizedBox(width: AppDimensions.base),
            Text('To: ', style: AppTextStyles.labelSmall),
            DropdownButton<int?>(
              value: _toYear,
              hint: Text('$maxYear', style: AppTextStyles.labelSmall),
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                ...allYears
                    .where((y) => _fromYear == null || y >= _fromYear!)
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y'))),
              ],
              onChanged: (val) => setState(() => _toYear = val),
            ),
            const Spacer(),
            if (_fromYear != null || _toYear != null)
              GestureDetector(
                onTap: () => setState(() {
                  _fromYear = null;
                  _toYear = null;
                }),
                child: Text(
                  'Reset',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryContainer,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),

        // Line chart
        if (data.isNotEmpty)
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: null,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: AppColors.outlineVariant, strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        if (data.length > 10 && idx % 2 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          "'${data[idx].year % 100}",
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 9,
                            color: AppColors.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final idx = spot.x.toInt();
                        final year = idx < data.length ? data[idx].year : 0;
                        return LineTooltipItem(
                          '$year: ${spot.y.toInt()} citations',
                          AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      data.length,
                      (i) =>
                          FlSpot(i.toDouble(), data[i].citedByCount.toDouble()),
                    ),
                    isCurved: true,
                    color: AppColors.primaryContainer,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: data.length <= 15,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: AppColors.primaryContainer,
                            strokeWidth: 0,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryContainer.withValues(alpha: 0.1),
                    ),
                  ),
                ],
                minY: 0,
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(AppDimensions.base),
            child: Text('No data for selected range'),
          ),
        const SizedBox(height: AppDimensions.base),
      ],
    );
  }
}

// ── Paper export ──────────────────────────────────────────────────────────────

enum _PaperExportFormat { bibtex, ris, csv, copyText }

class _PaperExportSheet extends StatelessWidget {
  const _PaperExportSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.base,
          AppDimensions.base,
          AppDimensions.base,
          AppDimensions.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.base),
            Text(
              'Export / Share',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Choose a format for this paper.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.base),
            _ExportTile(
              icon: Icons.copy_outlined,
              label: 'Copy citation',
              description: 'Plain text — paste anywhere',
              onTap: () =>
                  Navigator.of(context).pop(_PaperExportFormat.copyText),
            ),
            const Divider(height: 1),
            _ExportTile(
              icon: Icons.code,
              label: 'BibTeX',
              description: 'For LaTeX, Overleaf, Zotero',
              onTap: () => Navigator.of(context).pop(_PaperExportFormat.bibtex),
            ),
            const Divider(height: 1),
            _ExportTile(
              icon: Icons.description_outlined,
              label: 'RIS',
              description: 'For Mendeley, EndNote, RefWorks',
              onTap: () => Navigator.of(context).pop(_PaperExportFormat.ris),
            ),
            const Divider(height: 1),
            _ExportTile(
              icon: Icons.table_chart_outlined,
              label: 'CSV',
              description: 'For Excel, Google Sheets',
              onTap: () => Navigator.of(context).pop(_PaperExportFormat.csv),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryContainer),
      title: Text(
        label,
        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface),
      ),
      subtitle: Text(
        description,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

// ── Shared mini card ──────────────────────────────────────────────────────────

class _MiniBox extends StatelessWidget {
  final String label;
  final String value;
  const _MiniBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
