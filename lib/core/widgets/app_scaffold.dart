import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<BottomNavigationBarItem> destinations;
  final List<Widget>? actions;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const desktopBreakpoint = 768.0;
  static const maxContentWidth = 1280.0;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= desktopBreakpoint;
    return Scaffold(
      appBar: desktop
          ? PreferredSize(
              preferredSize: const Size.fromHeight(72),
              child: _buildDesktopHeader(context),
            )
          : AppBar(title: Text(title), actions: actions),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: SizedBox(width: double.infinity, child: body),
          ),
        ),
      ),
      bottomNavigationBar: desktop
          ? null
          : BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: onDestinationSelected,
              type: BottomNavigationBarType.fixed,
              items: destinations,
            ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 16;
    final showIcons = MediaQuery.sizeOf(context).width >= 1040;
    return Material(
      color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => onDestinationSelected(0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/prosme_logo.png',
                              width: 28,
                              height: 28,
                            ),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'ProSME',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final (index, item) in destinations.indexed)
                          Flexible(
                            child: _buildDestination(theme.colorScheme, index,
                                item, largeText, showIcons),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions ?? const [],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDestination(
    ColorScheme scheme,
    int index,
    BottomNavigationBarItem item,
    bool largeText,
    bool showIcons,
  ) {
    final label = item.label ?? '';
    final selected = index == selectedIndex;
    final icon = selected ? item.activeIcon : item.icon;
    return Tooltip(
      message: label,
      child: Semantics(
        selected: selected,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            backgroundColor: selected ? scheme.secondaryContainer : null,
            foregroundColor: selected ? scheme.onSecondaryContainer : null,
          ),
          onPressed: () => onDestinationSelected(index),
          child: largeText
              ? icon
              : showIcons
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon,
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(label,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    )
                  : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
