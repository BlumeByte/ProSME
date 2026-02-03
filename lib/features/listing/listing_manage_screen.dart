import 'package:flutter/material.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/primary_button.dart';

class ListingManageScreen extends StatelessWidget {
  const ListingManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(title: 'My Listings'),
        const SizedBox(height: 12),
        const EmptyState(
          title: 'No listings yet',
          subtitle: 'Create your first service listing.',
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Create listing',
          icon: Icons.add,
          onPressed: () {},
        ),
      ],
    );
  }
}
