import 'package:flutter/material.dart';
import '../../core/widgets/empty_state.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final _sections = const [
    _AdminSection(title: 'Verification Queue'),
    _AdminSection(title: 'Listings & Reviews'),
    _AdminSection(title: 'Disputes'),
    _AdminSection(title: 'Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() {
              _selectedIndex = index;
            }),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.verified_user),
                label: Text('Verify'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_alt),
                label: Text('Moderate'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.gavel),
                label: Text('Disputes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics),
                label: Text('Analytics'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _sections[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

class _AdminSection extends StatelessWidget {
  const _AdminSection({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: title,
      subtitle: 'Admin tools will appear here.',
    );
  }
}
