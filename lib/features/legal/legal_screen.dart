import 'package:flutter/material.dart';

enum LegalPageKind { privacy, terms, security }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});

  final LegalPageKind kind;

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(kind);
    return Scaffold(
      appBar: AppBar(title: Text(content.title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: content.sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          final section = content.sections[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(section.body),
            ],
          );
        },
      ),
    );
  }
}

_LegalContent _contentFor(LegalPageKind kind) {
  switch (kind) {
    case LegalPageKind.privacy:
      return const _LegalContent(
        title: 'Privacy Policy',
        sections: [
          _LegalSection(
            'Data we collect',
            'ProSME stores account details, contact information, listings, jobs, chats, verification documents, saved listings, and payment preferences needed to operate the marketplace.',
          ),
          _LegalSection(
            'How data is used',
            'Data is used for authentication, service matching, artisan verification, safety review, support, notifications, and transaction records.',
          ),
          _LegalSection(
            'User rights',
            'Users may update profile details, request account deletion, and contact support about data access or correction.',
          ),
          _LegalSection(
            'Third parties',
            'The app uses Supabase for authentication, database, storage, and realtime services. Payment and map providers may process data when those features are used.',
          ),
        ],
      );
    case LegalPageKind.terms:
      return const _LegalContent(
        title: 'Terms of Service',
        sections: [
          _LegalSection(
            'Marketplace rules',
            'Users must post lawful requests and communicate respectfully. Artisans must provide accurate service descriptions and honor agreed work terms.',
          ),
          _LegalSection(
            'Verification',
            'Admin verification improves trust but does not replace user judgment. Users should review artisan status before engagement.',
          ),
          _LegalSection(
            'Payments',
            'Users and artisans are responsible for confirming payment terms, receipts, and job completion details.',
          ),
          _LegalSection(
            'Moderation',
            'ProSME may remove unsafe content, restrict accounts, or reject verification submissions that violate platform rules.',
          ),
        ],
      );
    case LegalPageKind.security:
      return const _LegalContent(
        title: 'Security',
        sections: [
          _LegalSection(
            'Authentication',
            'Accounts are protected through Supabase Auth with email, SMS OTP, and OAuth providers when configured.',
          ),
          _LegalSection(
            'Access controls',
            'Supabase row-level security policies restrict private data and limit verification review tools to admin accounts.',
          ),
          _LegalSection(
            'Verification documents',
            'Artisan ID files are limited to PDF or image files up to 1 MB and are stored in the configured Supabase Storage bucket.',
          ),
          _LegalSection(
            'Incident response',
            'Report suspicious behavior or security concerns through Support so admins can review accounts and platform activity.',
          ),
        ],
      );
  }
}

class _LegalContent {
  const _LegalContent({required this.title, required this.sections});

  final String title;
  final List<_LegalSection> sections;
}

class _LegalSection {
  const _LegalSection(this.title, this.body);

  final String title;
  final String body;
}
