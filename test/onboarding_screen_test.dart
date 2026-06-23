import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prosme/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding screen shows get started button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingScreen()),
      ),
    );

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
