import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/get_top_journals.dart';

class JournalDetailScreen extends ConsumerWidget {
  final JournalWithCount journal;

  const JournalDetailScreen({required this.journal, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(journal.name)),
        body: const Center(child: Text('Journal Detail — TODO')),
      );
}
