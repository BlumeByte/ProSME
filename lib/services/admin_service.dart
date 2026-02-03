import '../core/utils/mock_data.dart';
import '../models/artisan_profile.dart';
import '../models/discount_offer.dart';

class AdminService {
  Future<List<ArtisanProfile>> fetchVerificationQueue() async {
    return [demoArtisanProfile];
  }

  Future<List<DiscountOffer>> fetchDiscounts() async {
    return [
      DiscountOffer(
        id: 'offer_1',
        title: 'New User Bonus',
        description: '10% off for first job',
        percent: 10,
        active: true,
        start: DateTime.now().subtract(const Duration(days: 1)),
        end: DateTime.now().add(const Duration(days: 30)),
      ),
    ];
  }
}
