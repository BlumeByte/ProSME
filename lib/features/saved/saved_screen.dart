import 'package:flutter/material.dart';
import '../../core/widgets/empty_state.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Saved items',
      subtitle: 'Your bookmarked artisans will show here.',
    );
  }
}
