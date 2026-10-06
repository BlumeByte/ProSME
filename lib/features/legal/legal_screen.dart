import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/safe_back_button.dart';
import '../../services/app_settings_controller.dart';

enum LegalPageKind { privacy, terms, security }

class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.kind});

  final LegalPageKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final content = _contentFor(kind);
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t(content.title)),
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
                settings.t(section.title),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(settings.t(section.body)),
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
            'Who we are',
            'ProSME (BLUMEBYTE) runs a marketplace that connects customers with artisans and service professionals. This policy explains what personal data we collect, why, who we share it with, and the choices you have.',
          ),
          _LegalSection(
            'Data you give us',
            'Account details (name, username, email, phone number, date of birth, gender, country and town), profile photo and description, listings, jobs, bids, chats and attachments, verification documents (national ID and business certificates), reports you file, and payment or wallet records.',
          ),
          _LegalSection(
            'Google sign-in',
            'If you sign in or create an account with Google, we receive your name, email address, and profile photo from Google. We never receive or store your Google password. You can remove this link by signing in with email or contacting support. Google handles your Google account under its own privacy policy.',
          ),
          _LegalSection(
            'Data collected automatically',
            'The app records technical data needed to run it: device and app version, push notification tokens, sign-in and security events, rate-limit counters, and analytics events such as searches and screen use. Location is used only when you allow it, to suggest nearby services and fill in your town.',
          ),
          _LegalSection(
            'Where your data is stored',
            'Your account, profile, listings, jobs, bids, chats, notifications and files are stored with Supabase, our hosting and database provider, in the region of our Supabase project. Supabase processes this data on our behalf. Access is controlled by database security rules, and sensitive records are readable only by you and by authorised ProSME staff.',
          ),
          _LegalSection(
            'Emails we send',
            'We send email from noreply@prosme.blumebyte.com through our mail server. These include sign-in verification codes, account and password emails, job, bid, wallet and chat notifications, verification updates, and announcements from ProSME. Each category can be turned off under Profile → Account settings → Notifications.',
          ),
          _LegalSection(
            'Who can see your contact details',
            'Your phone number and name are shown only to the other party on an accepted job, so you can call each other while the work is open. They are not shown on public listings or to anyone else. Your email address is not shown publicly.',
          ),
          _LegalSection(
            'Advertising',
            'The app shows advertisements, including full-page ads during searches and banner ads provided through Google AdMob. Ad providers may use device identifiers to show relevant or limited ads, as allowed by your device settings.',
          ),
          _LegalSection(
            'How we use data',
            'We use your data to run your account and sign-in, match customers with artisans, support verification and safety review, send the notifications you choose, record wallet and transaction history, prevent fraud and abuse, and improve the app.',
          ),
          _LegalSection(
            'Service providers',
            'We share data only with providers that help us run ProSME: Supabase (database, storage, sign-in and server functions), Google (Google sign-in and AdMob ads), our mail server (email delivery), Firebase (push notifications), Paystack (payments), and Twilio (SMS verification) when those features are used. Each acts under its own privacy policy and our instructions.',
          ),
          _LegalSection(
            'Retention',
            'We keep account data while your account is active. When you delete your account, your profile and personal details are removed. Financial and job records may be kept for the period the law requires for accounts, tax and dispute review.',
          ),
          _LegalSection(
            'Your choices and rights',
            'You can update your profile, turn notification types on or off, block or report chats, request a copy of your data, correct it, or delete your account from Profile → Account settings. To exercise any right you cannot do in the app, contact ProSME support.',
          ),
          _LegalSection(
            'Children',
            'ProSME is for people aged 18 and over. We do not knowingly collect data from anyone younger. If you believe a child has an account, contact support so we can remove it.',
          ),
          _LegalSection(
            'Changes to this policy',
            'We may update this policy as the app changes. When we make a material change we will tell you in the app or by email. This version was last updated on 6 October 2026.',
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
            'Do not post illegal services, harassment, threats, fraud, stolen materials, dangerous work requests, spam, or content that violates another person\'s rights. Meet in safe locations and verify details before sharing money or sensitive information.',
          ),
          _LegalSection(
            'Chats, reports, and blocking',
            'Chats are provided to help users discuss service requests. Users may report or block conversations that appear unsafe, abusive, fraudulent, or inappropriate. Reports may be reviewed by ProSME admins or support staff and may include message context, account IDs, timestamps, and related request records.',
          ),
          _LegalSection(
            'Account actions',
            'ProSME may remove content, hide requests, limit features, reject verification, suspend accounts, or delete accounts when activity appears unsafe, fraudulent, unlawful, or harmful to the marketplace.',
          ),
          _LegalSection(
            'Admin and support review',
            'Admin Dashboard tools may be used to review reports, account roles, verification status, listings, jobs, bids, notifications, and marketplace activity for support, safety, debugging, and abuse prevention.',
          ),
          _LegalSection(
            'Platform availability',
            'The app may be updated, interrupted, delayed, or unavailable because of maintenance, network issues, third-party services, or security controls. ProSME is provided without a guarantee of uninterrupted access.',
          ),
          _LegalSection(
            'Offline and cached data',
            'The app may temporarily store account, listing, job, and chat data on your device to improve speed and offline access. Cached data updates when connectivity returns and may be removed by signing out, clearing app data, or deleting the account.',
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
            'Accounts are protected through secure authentication with email verification, password recovery, and OAuth providers when configured.',
          ),
          _LegalSection(
            'Access controls',
            'Database access rules restrict private data and limit verification, report, and admin review tools to authorized accounts.',
          ),
          _LegalSection(
            'Verification documents',
            'Artisan ID files are limited to PDF or image files up to 1 MB and are stored in secure document storage.',
          ),
          _LegalSection(
            'Incident response',
            'Report suspicious behavior or security concerns through Support or the chat report menu so the team can review accounts and platform activity.',
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
