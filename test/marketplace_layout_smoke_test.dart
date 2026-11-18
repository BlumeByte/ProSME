import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prosme/config/constants.dart';
import 'package:prosme/core/widgets/app_scaffold.dart';
import 'package:prosme/features/jobs/jobs_repository.dart';
import 'package:prosme/features/listing/listing_feed_screen.dart';
import 'package:prosme/models/app_user.dart';
import 'package:prosme/models/listing.dart';
import 'package:prosme/services/service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('marketplace adapts at desktop, tablet and phone widths',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1100);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final customer = AppUser(
      id: 'customer',
      role: UserRole.customer,
      name: 'Customer',
      phone: '',
      email: '',
      photoUrl: '',
      createdAt: DateTime(2026),
    );
    final listings = [
      for (var i = 0; i < 6; i++)
        Listing(
          id: 'listing-$i',
          artisanId: 'artisan-$i',
          artisanName: 'Professional $i',
          title: 'Tailoring $i',
          description: 'Custom garments',
          category: 'Tailoring',
          priceMin: 350,
          priceMax: 500,
          images: const [],
          location: 'Accra Ghana',
          verifiedOnly: true,
          createdAt: DateTime(2026),
        ),
    ];
    var selected = -1;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((_) => Stream.value(customer)),
        listingsStreamProvider.overrideWith((_) => Stream.value(listings)),
        marketplaceArtisansProvider.overrideWith((_) async => []),
        jobsStreamProvider.overrideWith((_) => Stream.value([])),
      ],
      child: MaterialApp(
        home: AppScaffold(
          title: 'ProSME',
          selectedIndex: 0,
          onDestinationSelected: (index) => selected = index,
          destinations: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month), label: 'Bookings'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          actions: const [
            IconButton(onPressed: null, icon: Icon(Icons.refresh)),
            IconButton(onPressed: null, icon: Icon(Icons.notifications)),
            IconButton(
                onPressed: null, icon: Icon(Icons.account_balance_wallet)),
          ],
          body: const ListingFeedScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(tester.getSize(find.byType(ListingFeedScreen)).width, 1280);
    expect(tester.getCenter(find.byType(TextField).first).dy,
        tester.getCenter(find.text('Search')).dy);
    await tester.tap(find.text('Bookings'));
    expect(selected, 2);
    final names = find.text('Professional 0');
    await tester.ensureVisible(names.first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Book Now'), findsWidgets);
    for (final width in [1024.0, 768.0, 767.0, 390.0]) {
      tester.view.physicalSize = Size(width, 1100);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.byType(BottomNavigationBar),
          width < 768 ? findsOneWidget : findsNothing);
    }
  });
}
