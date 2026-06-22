import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/publication.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';

// ── Data models for the network graph ─────────────────────────────────────────

class _AuthorNode {
  final String id;
  final String displayName;
  final int paperCount;
  final int citationCount;
  Offset position;

  _AuthorNode({
    required this.id,
    required this.displayName,
    required this.paperCount,
    required this.citationCount,
    this.position = Offset.zero,
  });
}

class _CoAuthorEdge {
  final String authorId1;
  final String authorId2;
  final List<Publication> sharedPublications;

  const _CoAuthorEdge({
    required this.authorId1,
    required this.authorId2,
    required this.sharedPublications,
  });
}

// ── Scale mode enum ───────────────────────────────────────────────────────────

enum _NetworkScaleMode { papers, citations }

// ── Screen ────────────────────────────────────────────────────────────────────

class AuthorNetworkScreen extends ConsumerWidget {
  const AuthorNetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: query.isEmpty
          ? const EmptyState(
              icon: Icons.hub_outlined,
              message:
                  'Search for a topic in the Keywords tab to see the author collaboration network.',
            )
          : const _AuthorNetworkBody(),
    );
  }
}

class _AuthorNetworkBody extends ConsumerStatefulWidget {
  const _AuthorNetworkBody();

  @override
  ConsumerState<_AuthorNetworkBody> createState() => _AuthorNetworkBodyState();
}

class _AuthorNetworkBodyState extends ConsumerState<_AuthorNetworkBody> {
  _NetworkScaleMode _scaleMode = _NetworkScaleMode.papers;

  @override
  Widget build(BuildContext context) {
    final pubs = ref.watch(publicationsProvider).value ?? [];

    if (pubs.isEmpty) {
      return const EmptyState(
        icon: Icons.hub_outlined,
        message: 'No publications loaded yet.',
      );
    }

    // Build network data
    final networkData = _buildNetworkData(pubs);
    final nodes = networkData.$1;
    final edges = networkData.$2;

    if (nodes.isEmpty) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        message: 'No author data available.',
      );
    }

    return Column(
      children: [
        // Current topic indicator
        Consumer(
          builder: (context, ref, _) {
            final query = ref.watch(searchQueryProvider);
            if (query.isEmpty) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.base,
                vertical: AppDimensions.sm,
              ),
              color: AppColors.citationChipBg,
              child: Row(
                children: [
                  const Icon(Icons.topic, size: 16, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      'Topic: $query',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.citationChipText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Segmented button (like Heatmap's Countries/Institutions toggle)
        Padding(
          padding: const EdgeInsets.all(AppDimensions.base),
          child: SegmentedButton<_NetworkScaleMode>(
            segments: const [
              ButtonSegment(
                value: _NetworkScaleMode.papers,
                icon: Icon(Icons.article_outlined, size: 18),
                label: Text('Scale by Papers'),
              ),
              ButtonSegment(
                value: _NetworkScaleMode.citations,
                icon: Icon(Icons.format_quote_outlined, size: 18),
                label: Text('Scale by Citations'),
              ),
            ],
            selected: {_scaleMode},
            onSelectionChanged: (selected) {
              setState(() => _scaleMode = selected.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.secondaryContainer,
              selectedForegroundColor: AppColors.onSecondaryContainer,
            ),
          ),
        ),
        // Network graph
        Expanded(
          child: _NetworkGraphView(
            nodes: nodes,
            edges: edges,
            scaleMode: _scaleMode,
            publications: pubs,
          ),
        ),
      ],
    );
  }

  (List<_AuthorNode>, List<_CoAuthorEdge>) _buildNetworkData(
    List<Publication> pubs,
  ) {
    // Aggregate author stats
    final Map<String, _AuthorNode> nodeMap = {};
    for (final pub in pubs) {
      for (final author in pub.authors) {
        final key = author.id.isNotEmpty ? author.id : author.displayName;
        if (nodeMap.containsKey(key)) {
          final existing = nodeMap[key]!;
          nodeMap[key] = _AuthorNode(
            id: existing.id,
            displayName: existing.displayName,
            paperCount: existing.paperCount + 1,
            citationCount: existing.citationCount + pub.citedByCount,
            position: existing.position,
          );
        } else {
          nodeMap[key] = _AuthorNode(
            id: key,
            displayName: author.displayName,
            paperCount: 1,
            citationCount: pub.citedByCount,
          );
        }
      }
    }

    // Build co-authorship edges
    final Map<String, _CoAuthorEdge> edgeMap = {};
    for (final pub in pubs) {
      final authorKeys = pub.authors
          .map((a) => a.id.isNotEmpty ? a.id : a.displayName)
          .toSet()
          .toList();
      for (int i = 0; i < authorKeys.length; i++) {
        for (int j = i + 1; j < authorKeys.length; j++) {
          final edgeKey = _edgeKey(authorKeys[i], authorKeys[j]);
          if (edgeMap.containsKey(edgeKey)) {
            edgeMap[edgeKey]!.sharedPublications.add(pub);
          } else {
            edgeMap[edgeKey] = _CoAuthorEdge(
              authorId1: authorKeys[i],
              authorId2: authorKeys[j],
              sharedPublications: [pub],
            );
          }
        }
      }
    }

    // Only keep top authors to avoid overcrowding (max 30)
    final sortedNodes = nodeMap.values.toList()
      ..sort((a, b) => b.paperCount.compareTo(a.paperCount));
    final topNodes = sortedNodes.take(30).toList();
    final topNodeIds = topNodes.map((n) => n.id).toSet();

    // Filter edges to only include top nodes
    final filteredEdges = edgeMap.values
        .where(
          (e) =>
              topNodeIds.contains(e.authorId1) &&
              topNodeIds.contains(e.authorId2),
        )
        .toList();

    return (topNodes, filteredEdges);
  }

  String _edgeKey(String id1, String id2) {
    final sorted = [id1, id2]..sort();
    return '${sorted[0]}|||${sorted[1]}';
  }
}

// ── Network Graph View (with force layout) ────────────────────────────────────

class _NetworkGraphView extends StatefulWidget {
  final List<_AuthorNode> nodes;
  final List<_CoAuthorEdge> edges;
  final _NetworkScaleMode scaleMode;
  final List<Publication> publications;

  const _NetworkGraphView({
    required this.nodes,
    required this.edges,
    required this.scaleMode,
    required this.publications,
  });

  @override
  State<_NetworkGraphView> createState() => _NetworkGraphViewState();
}

class _NetworkGraphViewState extends State<_NetworkGraphView> {
  late List<_AuthorNode> _nodes;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _nodes = widget.nodes;
    _layoutNodes();
  }

  @override
  void didUpdateWidget(covariant _NetworkGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes) {
      _nodes = widget.nodes;
      _layoutNodes();
    }
  }

  void _layoutNodes() {
    final random = Random(42);
    final count = _nodes.length;

    // Pre-compute radii for overlap-aware repulsion
    final radii = List.generate(count, (i) => _getNodeRadius(_nodes[i]));

    // Canvas center scales with node count to give more room
    final canvasSize = max(600.0, count * 40.0);
    final center = Offset(canvasSize / 2, canvasSize / 2);

    // Initialize positions in a circle with enough spacing
    final initRadius = canvasSize * 0.35;
    for (int i = 0; i < count; i++) {
      final angle = (2 * pi * i) / count;
      final jitter = random.nextDouble() * 30;
      _nodes[i].position = Offset(
        center.dx + (initRadius + jitter) * cos(angle),
        center.dy + (initRadius + jitter) * sin(angle),
      );
    }

    // Force simulation — 200 iterations for better convergence
    for (int iter = 0; iter < 200; iter++) {
      final forces = List.generate(count, (_) => Offset.zero);
      final cooling = 1.0 - (iter / 200) * 0.85;

      // Repulsive forces — overlap-aware: uses sum of radii as minimum distance
      for (int i = 0; i < count; i++) {
        for (int j = i + 1; j < count; j++) {
          final diff = _nodes[i].position - _nodes[j].position;
          final dist = max(diff.distance, 0.1);
          final minDist =
              radii[i] + radii[j] + 20.0; // 20px padding between nodes

          // Strong repulsion when overlapping, normal repulsion otherwise
          double repulsion;
          if (dist < minDist) {
            // Very strong push when overlapping
            repulsion = (minDist - dist) * 5.0 + 12000.0 / (dist * dist);
          } else {
            repulsion = 12000.0 / (dist * dist);
          }

          final force = diff / dist * repulsion;
          forces[i] += force;
          forces[j] -= force;
        }
      }

      // Attractive forces along edges
      for (final edge in widget.edges) {
        final iIdx = _nodes.indexWhere((n) => n.id == edge.authorId1);
        final jIdx = _nodes.indexWhere((n) => n.id == edge.authorId2);
        if (iIdx < 0 || jIdx < 0) continue;

        final diff = _nodes[jIdx].position - _nodes[iIdx].position;
        final dist = max(diff.distance, 1.0);
        final minDist = radii[iIdx] + radii[jIdx] + 20.0;
        // Only attract if beyond minimum separation
        if (dist > minDist) {
          final attraction = (dist - minDist) * 0.008;
          final force = diff / dist * attraction;
          forces[iIdx] += force;
          forces[jIdx] -= force;
        }
      }

      // Gentle center gravity to prevent drift
      for (int i = 0; i < count; i++) {
        final toCenter = center - _nodes[i].position;
        forces[i] += toCenter * 0.003;
      }

      // Apply forces with cooling
      for (int i = 0; i < count; i++) {
        final displacement = forces[i] * cooling;
        const maxDisp = 25.0;
        final dist = displacement.distance;
        if (dist > maxDisp) {
          _nodes[i].position += displacement / dist * maxDisp;
        } else {
          _nodes[i].position += displacement;
        }
      }
    }

    // Final overlap resolution pass — push apart any still-overlapping nodes
    for (int pass = 0; pass < 50; pass++) {
      bool anyOverlap = false;
      for (int i = 0; i < count; i++) {
        for (int j = i + 1; j < count; j++) {
          final diff = _nodes[i].position - _nodes[j].position;
          final dist = max(diff.distance, 0.1);
          final minDist = radii[i] + radii[j] + 16.0;
          if (dist < minDist) {
            anyOverlap = true;
            final overlap = (minDist - dist) / 2.0 + 1.0;
            final push = diff / dist * overlap;
            _nodes[i].position += push;
            _nodes[j].position -= push;
          }
        }
      }
      if (!anyOverlap) break;
    }
  }

  double _getNodeRadius(_AuthorNode node) {
    final value = widget.scaleMode == _NetworkScaleMode.papers
        ? node.paperCount
        : node.citationCount;
    final maxValue = widget.scaleMode == _NetworkScaleMode.papers
        ? _nodes.map((n) => n.paperCount).reduce(max)
        : _nodes.map((n) => n.citationCount).reduce(max);
    final minRadius = 20.0;
    final maxRadius = 50.0;
    if (maxValue == 0) return minRadius;
    final ratio = value / maxValue;
    return minRadius + (maxRadius - minRadius) * ratio;
  }

  @override
  Widget build(BuildContext context) {
    final canvasSize = _computeCanvasSize();

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: InteractiveViewer(
        transformationController: _transformController,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(300),
        minScale: 0.15,
        maxScale: 4.0,
        panEnabled: _draggedNodeIndex == null,
        scaleEnabled: _draggedNodeIndex == null,
        child: GestureDetector(
          onTapUp: (details) => _handleTap(details.localPosition),
          behavior: HitTestBehavior.translucent,
          child: CustomPaint(
            size: Size(canvasSize, canvasSize),
            painter: _NetworkPainter(
              nodes: _nodes,
              edges: widget.edges,
              scaleMode: widget.scaleMode,
              getNodeRadius: _getNodeRadius,
            ),
            child: SizedBox(width: canvasSize, height: canvasSize),
          ),
        ),
      ),
    );
  }

  // ── Node dragging via raw pointer events ──────────────────────────────────

  int? _draggedNodeIndex;
  Offset? _pointerDownPos;
  static const _dragThreshold = 8.0;

  Offset _toLocalCanvas(Offset globalPos) {
    final matrix = _transformController.value;
    final inverseMatrix = Matrix4.inverted(matrix);

    final renderBox = context.findRenderObject() as RenderBox;
    final localToWidget = renderBox.globalToLocal(globalPos);

    final transformed = MatrixUtils.transformPoint(
      inverseMatrix,
      localToWidget,
    );
    return transformed;
  }

  void _onPointerDown(PointerDownEvent event) {
    final canvasPos = _toLocalCanvas(event.position);
    _pointerDownPos = canvasPos;
    for (int i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      final radius = _getNodeRadius(node);
      if ((canvasPos - node.position).distance <= radius) {
        setState(() {
          _draggedNodeIndex = i;
        });
        return;
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_draggedNodeIndex != null) {
      final canvasPos = _toLocalCanvas(event.position);
      setState(() {
        _nodes[_draggedNodeIndex!].position = canvasPos;
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final canvasPos = _toLocalCanvas(event.position);
    final wasDrag =
        _draggedNodeIndex != null &&
        _pointerDownPos != null &&
        (canvasPos - _pointerDownPos!).distance > _dragThreshold;

    if (_draggedNodeIndex != null && !wasDrag) {
      // It was a tap on a node, not a drag
      final node = _nodes[_draggedNodeIndex!];
      _showAuthorPublications(context, node);
    }

    setState(() {
      _draggedNodeIndex = null;
      _pointerDownPos = null;
    });
  }

  double _computeCanvasSize() {
    if (_nodes.isEmpty) return 600;
    double maxExtent = 0;
    for (final node in _nodes) {
      final r = _getNodeRadius(node);
      maxExtent = max(maxExtent, node.position.dx + r);
      maxExtent = max(maxExtent, node.position.dy + r);
    }
    return max(600, maxExtent + 80);
  }

  void _handleTap(Offset tapPosition) {
    // If tap lands on a node, ignore — node taps handled by pointer events
    for (final node in _nodes) {
      final radius = _getNodeRadius(node);
      if ((tapPosition - node.position).distance <= radius) {
        return;
      }
    }

    // Check if tapped on an edge
    for (final edge in widget.edges) {
      final node1 = _nodes.where((n) => n.id == edge.authorId1).firstOrNull;
      final node2 = _nodes.where((n) => n.id == edge.authorId2).firstOrNull;
      if (node1 == null || node2 == null) continue;

      final distToLine = _pointToLineDistance(
        tapPosition,
        node1.position,
        node2.position,
      );

      if (distToLine < 12.0) {
        _showSharedPublications(context, node1, node2, edge);
        return;
      }
    }
  }

  double _pointToLineDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final lineVec = lineEnd - lineStart;
    final pointVec = point - lineStart;
    final lineLen = lineVec.distance;
    if (lineLen == 0) return (point - lineStart).distance;

    final t =
        (pointVec.dx * lineVec.dx + pointVec.dy * lineVec.dy) /
        (lineLen * lineLen);
    final clampedT = t.clamp(0.0, 1.0);
    final projection = lineStart + lineVec * clampedT;
    return (point - projection).distance;
  }

  void _showSharedPublications(
    BuildContext context,
    _AuthorNode author1,
    _AuthorNode author2,
    _CoAuthorEdge edge,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.shapeMd),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => _SharedPublicationsSheet(
          author1: author1,
          author2: author2,
          publications: edge.sharedPublications,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showAuthorPublications(BuildContext context, _AuthorNode author) {
    // Find all publications this author participated in
    final authorPubs = widget.publications.where((pub) {
      return pub.authors.any((a) {
        final key = a.id.isNotEmpty ? a.id : a.displayName;
        return key == author.id;
      });
    }).toList();

    if (authorPubs.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.shapeMd),
        ),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => _AuthorPublicationsSheet(
          author: author,
          publications: authorPubs,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }
}

// ── Custom painter for the network ────────────────────────────────────────────

class _NetworkPainter extends CustomPainter {
  final List<_AuthorNode> nodes;
  final List<_CoAuthorEdge> edges;
  final _NetworkScaleMode scaleMode;
  final double Function(_AuthorNode) getNodeRadius;

  _NetworkPainter({
    required this.nodes,
    required this.edges,
    required this.scaleMode,
    required this.getNodeRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final edgePaint = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final edgeHighlightPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.4)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Draw edges
    for (final edge in edges) {
      final node1 = nodes.where((n) => n.id == edge.authorId1).firstOrNull;
      final node2 = nodes.where((n) => n.id == edge.authorId2).firstOrNull;
      if (node1 == null || node2 == null) continue;

      final paint = edge.sharedPublications.length > 1
          ? edgeHighlightPaint
          : edgePaint;
      canvas.drawLine(node1.position, node2.position, paint);
    }

    // Draw nodes
    for (final node in nodes) {
      final radius = getNodeRadius(node);

      // Node circle
      final nodePaint = Paint()
        ..color = _nodeColor(node)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, radius, nodePaint);

      // Node border
      final borderPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(node.position, radius, borderPaint);

      // Count value for the current scale mode
      final countValue = scaleMode == _NetworkScaleMode.papers
          ? node.paperCount
          : node.citationCount;
      final countLabel = scaleMode == _NetworkScaleMode.papers
          ? '$countValue papers'
          : '$countValue cit.';

      // Author name — positioned above center inside the circle
      final nameFontSize = (radius * 0.28).clamp(8.0, 13.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: _truncateName(node.displayName, radius),
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: nameFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '...',
      );
      textPainter.layout(maxWidth: radius * 1.6);

      // Count label — inside the circle, below the name
      final countFontSize = (radius * 0.22).clamp(7.0, 11.0);
      final countPainter = TextPainter(
        text: TextSpan(
          text: countLabel,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: countFontSize,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      countPainter.layout(maxWidth: radius * 1.6);

      // Vertically center both lines together inside the circle
      final totalTextHeight = textPainter.height + 2 + countPainter.height;
      final startY = node.position.dy - totalTextHeight / 2;

      textPainter.paint(
        canvas,
        Offset(node.position.dx - textPainter.width / 2, startY),
      );
      countPainter.paint(
        canvas,
        Offset(
          node.position.dx - countPainter.width / 2,
          startY + textPainter.height + 2,
        ),
      );
    }
  }

  String _truncateName(String name, double radius) {
    final maxChars = (radius * 0.4).round().clamp(4, 20);
    if (name.length <= maxChars) return name;
    return '${name.substring(0, maxChars - 1)}...';
  }

  Color _nodeColor(_AuthorNode node) {
    final value = scaleMode == _NetworkScaleMode.papers
        ? node.paperCount
        : node.citationCount;
    final maxValue = scaleMode == _NetworkScaleMode.papers
        ? nodes.map((n) => n.paperCount).reduce(max)
        : nodes.map((n) => n.citationCount).reduce(max);
    if (maxValue == 0) return const Color(0xFFE3F2FD);
    final ratio = value / maxValue;
    if (ratio > 0.7) return const Color(0xFFBBDEFB);
    if (ratio > 0.4) return const Color(0xFFE3F2FD);
    return const Color(0xFFF3F8FF);
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter oldDelegate) {
    return oldDelegate.scaleMode != scaleMode ||
        oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges;
  }
}

// ── Shared publications bottom sheet ──────────────────────────────────────────

class _SharedPublicationsSheet extends StatelessWidget {
  final _AuthorNode author1;
  final _AuthorNode author2;
  final List<Publication> publications;
  final ScrollController scrollController;

  const _SharedPublicationsSheet({
    required this.author1,
    required this.author2,
    required this.publications,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: AppDimensions.sm),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.all(AppDimensions.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Co-authored papers',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppDimensions.xs),
              Row(
                children: [
                  _authorChip(author1.displayName),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.sm,
                    ),
                    child: Icon(
                      Icons.link,
                      size: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  _authorChip(author2.displayName),
                ],
              ),
              const SizedBox(height: AppDimensions.xs),
              Text(
                '${publications.length} shared publication${publications.length > 1 ? 's' : ''}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Publication list
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.all(AppDimensions.base),
            itemCount: publications.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppDimensions.sm),
            itemBuilder: (context, index) {
              final pub = publications[index];
              return _PublicationTile(publication: pub);
            },
          ),
        ),
      ],
    );
  }

  Widget _authorChip(String name) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sm,
          vertical: AppDimensions.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.citationChipBg,
          borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
        ),
        child: Text(
          name,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.citationChipText,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Author publications bottom sheet ──────────────────────────────────────────

class _AuthorPublicationsSheet extends StatelessWidget {
  final _AuthorNode author;
  final List<Publication> publications;
  final ScrollController scrollController;

  const _AuthorPublicationsSheet({
    required this.author,
    required this.publications,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: AppDimensions.sm),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.all(AppDimensions.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, size: 20, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Text(
                      author.displayName,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  _statChip(
                    Icons.article_outlined,
                    '${author.paperCount} papers',
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  _statChip(
                    Icons.format_quote,
                    '${author.citationCount} citations',
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Publication list
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.all(AppDimensions.base),
            itemCount: publications.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppDimensions.sm),
            itemBuilder: (context, index) {
              final pub = publications[index];
              return _PublicationTile(publication: pub);
            },
          ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.citationChipBg,
        borderRadius: BorderRadius.circular(AppDimensions.shapeSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.citationChipText),
          const SizedBox(width: AppDimensions.xs),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.citationChipText,
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicationTile extends StatelessWidget {
  final Publication publication;

  const _PublicationTile({required this.publication});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Close the bottom sheet first, then navigate
        Navigator.of(context).pop();
        context.push(
          '/publication/${Uri.encodeComponent(publication.id)}',
          extra: publication,
        );
      },
      child: Card(
        elevation: 0,
        color: AppColors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.shapeMd),
          side: const BorderSide(color: AppColors.outlineVariant, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                publication.title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.onSurface,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  if (publication.publicationYear != null) ...[
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppDimensions.xs),
                    Text(
                      '${publication.publicationYear}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                  ],
                  Icon(
                    Icons.format_quote,
                    size: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Text(
                    '${publication.citedByCount} citations',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (publication.journalName != null) ...[
                const SizedBox(height: AppDimensions.xs),
                Text(
                  publication.journalName!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
