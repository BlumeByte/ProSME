import '../../models/app_user.dart';
import '../../models/artisan_profile.dart';
import '../../models/chat_models.dart';
import '../../models/invoice.dart';
import '../../models/job_order.dart';
import '../../models/listing.dart';
import '../../models/review.dart';
import '../../config/constants.dart';

final demoUser = AppUser(
  id: 'user_1',
  role: UserRole.customer,
  name: 'Ama Customer',
  phone: '+233 200 000 111',
  email: 'ama@example.com',
  photoUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
  createdAt: DateTime.now().subtract(const Duration(days: 5)),
);

final demoArtisan = AppUser(
  id: 'artisan_1',
  role: UserRole.artisan,
  name: 'Kojo Artisan',
  phone: '+233 244 000 222',
  email: 'kojo@example.com',
  photoUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d',
  createdAt: DateTime.now().subtract(const Duration(days: 20)),
);

final demoArtisanProfile = ArtisanProfile(
  userId: demoArtisan.id,
  verifiedStatus: VerificationStatus.verified,
  nationalIdUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
  momoNumber: '+233 244 000 222',
  location: 'Accra Central',
  categories: const ['Plumbing', 'Electrical'],
  bio: 'Experienced artisan with quick response times.',
  ratingSummary: 4.8,
);

final demoListings = [
  Listing(
    id: 'listing_1',
    artisanId: demoArtisan.id,
    title: 'Emergency Plumbing',
    description: 'Fix leaks, install taps, and bathroom fittings.',
    category: 'Plumbing',
    priceMin: 80,
    priceMax: 250,
    images: const [
      'https://images.unsplash.com/photo-1503387762-592deb58ef4e',
    ],
    location: 'Osu, Accra',
    verifiedOnly: true,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Listing(
    id: 'listing_2',
    artisanId: demoArtisan.id,
    title: 'Home Electrical Repair',
    description: 'Wiring checks, fan installation, sockets.',
    category: 'Electrical',
    priceMin: 60,
    priceMax: 200,
    images: const [
      'https://images.unsplash.com/photo-1489515217757-5fd1be406fef',
    ],
    location: 'East Legon',
    verifiedOnly: true,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];

final demoReviews = [
  Review(
    id: 'review_1',
    targetId: demoListings.first.id,
    userId: demoUser.id,
    stars: 5,
    comment: 'Fast and friendly service!',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

final demoChatThreads = [
  ChatThread(
    id: 'thread_1',
    userId: demoUser.id,
    artisanId: demoArtisan.id,
    lastMessage: 'See you at 4pm.',
    updatedAt: DateTime.now(),
  ),
];

final demoMessages = [
  ChatMessage(
    id: 'msg_1',
    threadId: demoChatThreads.first.id,
    senderId: demoUser.id,
    type: MessageType.text,
    content: 'Hello, can you come today?',
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  ChatMessage(
    id: 'msg_2',
    threadId: demoChatThreads.first.id,
    senderId: demoArtisan.id,
    type: MessageType.text,
    content: 'Yes, I can be there by 4pm.',
    createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
  ),
];

final demoInvoice = Invoice(
  id: 'inv_1',
  threadId: demoChatThreads.first.id,
  listingId: demoListings.first.id,
  artisanId: demoArtisan.id,
  userId: demoUser.id,
  lines: const [
    InvoiceLine(label: 'Fix leak', quantity: 1, amount: 120),
    InvoiceLine(label: 'Replace tap', quantity: 1, amount: 80),
  ],
  subtotal: 200,
  fee: 10,
  total: 210,
  paymentMethod: PaymentMethod.cash,
  status: InvoiceStatus.pending,
);

final demoJobs = [
  JobOrder(
    id: 'job_1',
    invoiceId: demoInvoice.id,
    artisanId: demoArtisan.id,
    userId: demoUser.id,
    status: JobStatus.active,
    meetingType: 'In-person',
    schedule: DateTime.now().add(const Duration(days: 1)),
    progress: const [
      JobProgress(title: 'Accepted', detail: 'Artisan accepted job'),
      JobProgress(title: 'On the way', detail: 'Arriving soon'),
    ],
    eta: '45 mins',
  ),
];
