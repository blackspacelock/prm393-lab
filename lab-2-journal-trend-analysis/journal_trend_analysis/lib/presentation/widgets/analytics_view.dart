import 'dart:async';
import 'package:flutter/widgets.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key, required this.onOpen, required this.child});

  final Future<void> Function() onOpen;
  final Widget child;

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.onOpen());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
