import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/keyword.dart';

class KeywordDetailScreen extends ConsumerWidget {
  final KeywordItem keyword;

  const KeywordDetailScreen({required this.keyword, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(keyword.name)),
        body: const Center(child: Text('Keyword Detail — TODO')),
      );
}
