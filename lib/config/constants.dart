import 'package:flutter/material.dart';

const bool kDevMode = true;
const String kAppName = 'ProSME';

const Color kPrimaryGreen = Color(0xFF1E7F3E);
const List<String> kSupportedLanguages = ['English', 'Twi', 'Ewe'];

enum UserRole { customer, artisan, admin }

enum VerificationStatus { pending, verified, rejected }

enum PaymentMethod { cash, paystack }

enum InvoiceStatus { pending, paid, cash }

enum JobStatus { active, completed, cancelled }
