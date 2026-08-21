import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.bottomNavigationBar,
    this.drawer,
    this.desktopDestinations,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.maxContentWidth = 1480,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final List<NavigationRailDestination>? desktopDestinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useDesktopNavigation = width >= 960 &&
        desktopDestinations != null &&
        desktopDestinations!.isNotEmpty &&
        onDestinationSelected != null;
    final content = useDesktopNavigation
        ? Row(
            children: [
              NavigationRail(
                extended: width >= 1280,
                minExtendedWidth: 220,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: width >= 1280
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                groupAlignment: -0.88,
                destinations: desktopDestinations!,
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: body,
                  ),
                ),
              ),
            ],
          )
        : body;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      drawer: drawer,
      body: SafeArea(child: content),
      bottomNavigationBar: useDesktopNavigation ? null : bottomNavigationBar,
    );
  }
}
