import 'package:flutter/material.dart';

/// Fades and slides [child] up into place once, the first time it appears
/// — meant for items in a freshly loaded list, so the feed settles in
/// smoothly instead of every card just appearing at once. [index] staggers
/// each item slightly behind the last so the motion reads as one wave
/// rather than a flat pop.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
  });

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final staggeredMs = 300 + 28 * index.clamp(0, 12);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: staggeredMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
