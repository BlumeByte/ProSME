import 'package:flutter/material.dart';

import '../../core/widgets/safe_back_button.dart';

enum LegalPageKind { privacy, terms, security }

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});

  final LegalPageKind kind;

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(kind);
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(content.title),
      ),
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
            'Marketplace role',
            'ProSME is a marketplace that helps customers and artisans discover, message, negotiate, and record service requests. ProSME is not a party to private work agreements unless a separate written contract says otherwise.',
          ),
          _LegalSection(
            'User responsibilities',
            'Users must provide accurate account information, post lawful requests, avoid abusive or misleading content, and use the platform only for legitimate service activity.',
          ),
          _LegalSection(
            'Artisan responsibilities',
            'Artisans must describe skills, prices, availability, credentials, bids, and completion status honestly. Artisans are responsible for permits, taxes, safety practices, and work quality required for their services.',
          ),
          _LegalSection(
            'Verification and trust',
            'Verification badges show that submitted documents passed a platform review at the time of review. Verification is not a guarantee of identity, licensing, insurance, work quality, safety, or future conduct.',
          ),
          _LegalSection(
            'Payments and disputes',
            'Customers and artisans are responsible for agreeing payment terms, receipts, refunds, site visits, materials, timelines, and completion details. ProSME may provide records to help review a dispute but does not guarantee payment or outcomes.',
          ),
          _LegalSection(
            'Safety and prohibited conduct',
            'Do not post illegal services, harassment, threats, fraud, stolen materials, dangerous work requests, spam, or content that violates another person’s rights. Meet in safe locations and verify details before sharing money or sensitive information.',
          ),
          _LegalSection(
            'Account actions',
            'ProSME may remove content, hide requests, limit features, reject verification, suspend accounts, or delete accounts when activity appears unsafe, fraudulent, unlawful, or harmful to the marketplace.',
          ),
          _LegalSection(
            'Platform availability',
            'The app may be updated, interrupted, delayed, or unavailable because of maintenance, network issues, third-party services, or security controls. ProSME is provided without a guarantee of uninterrupted access.',
          ),
          _LegalSection(
            'Liability limits',
            'To the fullest extent allowed by law, ProSME is not responsible for indirect losses, lost profits, failed negotiations, off-platform payments, user conduct, or service quality. Users remain responsible for their own decisions and agreements.',
          ),
          _LegalSection(
            'Changes',
            'These terms may be updated as the platform changes. Continued use of ProSME after updates means you accept the updated terms.',
          ),
        ],
      );
    case LegalPageKind.security:
      return const _LegalContent(
        title: 'Security',
        sections: [
          _LegalSection(
            'Authentication',
            'Accounts are protected through Supabase Auth with email verification, password recovery, and OAuth providers when configured.',
          ),
          _LegalSection(
            'Access controls',
            'Supabase row-level security policies restrict private data and limit verification review tools to Support accounts.',
          ),
          _LegalSection(
            'Verification documents',
            'Artisan ID files are limited to PDF or image files up to 1 MB and are stored in the configured Supabase Storage bucket.',
          ),
          _LegalSection(
            'Incident response',
            'Report suspicious behavior or security concerns through Support so the team can review accounts and platform activity.',
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
