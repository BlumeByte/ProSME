import 'package:flutter/material.dart';

const bool kDevMode = bool.fromEnvironment('DEV_MODE', defaultValue: false);
const String kAppName = 'Pro SME';
const String kCurrencySymbol = 'GHS';

// Supabase configuration – override at build time via --dart-define.
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://wbnvifrzckjttyxhmlcf.supabase.co',
);
const String kSupabaseAnonKeyPlaceholder =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndibnZpZnJ6Y2tqdHR5eGhtbGNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzODE0MTIsImV4cCI6MjA5MTk1NzQxMn0.w1AhJHFzXeuV86KLv3xc3xiflqeB06bp6Q2YcBg3vkY';
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: kSupabaseAnonKeyPlaceholder,
);
const String kGoogleOAuthRedirectUrl = String.fromEnvironment(
  'GOOGLE_OAUTH_REDIRECT_URL',
  // Override with your Android applicationId, e.g. com.yourcompany.prosme://login-callback
  defaultValue: 'com.prosme.app://login-callback',
);
const String kPaystackCheckoutUrl = String.fromEnvironment(
  'PAYSTACK_CHECKOUT_URL',
  defaultValue: '',
);

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

enum UserRole { customer, artisan, admin, developer }

enum VerificationStatus { pending, verified, rejected }

enum PaymentMethod { cash, paystack }

enum InvoiceStatus { pending, paid, cash }

enum JobStatus { active, completed, cancelled }
