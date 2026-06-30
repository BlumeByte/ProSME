import 'package:flutter/material.dart';

const bool kMockMode = bool.fromEnvironment('MOCK_MODE', defaultValue: false);
const String kAppName = 'ProSME';
const String kCurrencySymbol = 'GHS';

// Supabase configuration – override at build time via --dart-define.
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://wbnvifrzckjttyxhmlcf.supabase.co',
);
const String kSupabaseAnonKeyPlaceholder = 'YOUR_SUPABASE_ANON_KEY';
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: kSupabaseAnonKeyPlaceholder,
);
const String kGoogleOAuthRedirectUrl = String.fromEnvironment(
  'GOOGLE_OAUTH_REDIRECT_URL',
  // Override with your Android applicationId, e.g. com.yourcompany.prosme://login-callback
  defaultValue: 'com.prosme.app://login-callback',
);
const String kPasswordRecoveryRedirectUrl = String.fromEnvironment(
  'PASSWORD_RECOVERY_REDIRECT_URL',
  defaultValue: 'https://prosme.blumebyte.com/reset-password',
);
const String kEmailVerificationRedirectUrl = String.fromEnvironment(
  'EMAIL_VERIFICATION_REDIRECT_URL',
  defaultValue: 'https://prosme.blumebyte.com/login',
);
const String kPaystackCheckoutUrl = String.fromEnvironment(
  'PAYSTACK_CHECKOUT_URL',
  defaultValue: '',
);
const double kVerificationCustomerMonthlyUsd = 2;
const double kVerificationArtisanMonthlyUsd = 3;
const double kUsdToGhsEstimate = 11.289456;

// OAuth 2.1 / OIDC endpoints – derived from kSupabaseUrl.
// Share these with third-party applications that integrate with this server.
const String kOAuthAuthorizationEndpoint =
    '$kSupabaseUrl/auth/v1/oauth/authorize';
const String kOAuthTokenEndpoint = '$kSupabaseUrl/auth/v1/oauth/token';
const String kOAuthJwksEndpoint = '$kSupabaseUrl/auth/v1/.well-known/jwks.json';
const String kOAuthOidcDiscoveryEndpoint =
    '$kSupabaseUrl/auth/v1/.well-known/openid-configuration';

const Color kPrimaryGreen = Color(0xFF1E7F3E);
const List<String> kSupportedLanguages = ['English', 'Twi', 'Ewe'];

enum UserRole { customer, artisan, admin }

enum VerificationStatus { pending, verified, rejected }

enum PaymentMethod { cash, paystack }

enum InvoiceStatus { pending, paid, cash }

enum JobStatus { active, completed, cancelled }
