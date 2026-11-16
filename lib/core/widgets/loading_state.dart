import 'package:flutter/material.dart';

/// A loading placeholder that fades in (so it never just pops onto screen)
/// and gives the label a slow breathing pulse, so a long load reads as
/// "still working" rather than a frozen spinner.
class LoadingState extends StatefulWidget {
  const LoadingState({super.key, this.label = 'Loading...'});

  final String label;

  @override
  State<LoadingState> createState() => _LoadingStateState();
}

class _LoadingStateState extends State<LoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (context, entrance, child) => Opacity(
          opacity: entrance,
          child: Transform.scale(
            scale: 0.92 + (0.08 * entrance),
            child: child,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: Tween<double>(begin: 0.55, end: 1).animate(_pulse),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }
}
