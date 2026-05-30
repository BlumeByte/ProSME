import 'package:flutter/material.dart';

const bool kDevMode = bool.fromEnvironment('DEV_MODE', defaultValue: false);
const String kAppName = 'ProSME';

// Supabase configuration – replace with your project URL and anon key.
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://your-project.supabase.co',
);
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'your-anon-key',
);

const Color kPrimaryGreen = Color(0xFF1E7F3E);
const List<String> kSupportedLanguages = ['English', 'Twi', 'Ewe'];

enum UserRole { customer, artisan, admin }

enum VerificationStatus { pending, verified, rejected }

enum PaymentMethod { cash, paystack }

enum InvoiceStatus { pending, paid, cash }

enum JobStatus { active, completed, cancelled }
