import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../config/constants.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../models/chat_models.dart';
import '../../routes/route_names.dart';
import '../../services/service_providers.dart';
import 'jobs_repository.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final jobsAsync = ref.watch(jobsStreamProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: const Text('Job details'),
      ),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessageState(
          message: 'Could not load this job: $error',
        ),
        data: (jobs) {
          final job = _findJob(jobs, widget.jobId);
          if (job == null) {
            return const _MessageState(
              message: 'This job is no longer available.',
            );
          }

          final isOwner = user?.id == job.createdBy;
          final isArtisan = user?.role == UserRole.artisan;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _JobSummary(job: job),
              const SizedBox(height: 16),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.warning_amber_outlined),
                  title: Text('Before you continue'),
                  subtitle: Text(
                    'Negotiate in chat and confirm verification status before payment or site visits.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (user == null)
                FilledButton(
                  onPressed: () => context.go(RouteNames.auth),
                  child: const Text('Sign in to bid or chat'),
                )
              else if (isOwner)
                _BidsForOwner(job: job)
              else if (isArtisan)
                _BidForm(
                  formKey: _formKey,
                  amountController: _amountController,
                  messageController: _messageController,
                  submitting: _submitting,
                  onSubmit: () => _submitBid(job),
                )
              else
                const _MessageState(
                  message: 'Only artisans can bid on service requests.',
                ),
            ],
          );
        },
      ),
    );
  }

  JobFeedItem? _findJob(List<JobFeedItem> jobs, String id) {
    for (final job in jobs) {
      if (job.id == id) return job;
    }
    return null;
  }

  Future<void> _submitBid(JobFeedItem job) async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _submitting = true);
    try {
      final amount = double.parse(_amountController.text.trim());
      final bid = await ref.read(jobsRepositoryProvider).createBid(
            jobId: job.id,
            artisanId: user.id,
            amount: amount,
            message: _messageController.text.trim(),
          );
      final thread = await ref.read(chatServiceProvider).createOrOpenThread(
            userId: job.createdBy,
            artisanId: user.id,
          );
      await ref.read(chatServiceProvider).sendMessage(
            ChatMessage(
              id: _uuid.v4(),
              threadId: thread.id,
              senderId: user.id,
              type: MessageType.offer,
              content:
                  'Bid submitted: $kCurrencySymbol ${bid.amount.toStringAsFixed(2)}. ${bid.message}',
              createdAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      _amountController.clear();
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid sent. Chat opened for negotiation.')),
      );
      context.go('${RouteNames.chatThread}/${thread.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send bid: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _JobSummary extends StatelessWidget {
  const _JobSummary({required this.job});

  final JobFeedItem job;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(job.location)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$kCurrencySymbol ${job.budget.toStringAsFixed(2)} budget',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(job.description),
          ],
        ),
      ),
    );
  }
}

class _BidForm extends StatelessWidget {
  const _BidForm({
    required this.formKey,
    required this.amountController,
    required this.messageController,
    required this.submitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final TextEditingController messageController;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Send a bid', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                decoration:
                    const InputDecoration(labelText: 'Your price (GHS)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim());
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: messageController,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Explain your offer, availability, or questions.',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Message is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submitting ? null : onSubmit,
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Send bid and open chat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BidsForOwner extends ConsumerWidget {
  const _BidsForOwner({required this.job});

  final JobFeedItem job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidsAsync = ref.watch(jobBidsProvider(job.id));
    return bidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          _MessageState(message: 'Could not load bids: $error'),
      data: (bids) {
        if (bids.isEmpty) {
          return const _MessageState(
            message:
                'No bids yet. Artisans will appear here after they respond.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bids', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...bids.map((bid) => _BidTile(job: job, bid: bid)),
          ],
        );
      },
    );
  }
}

class _BidTile extends ConsumerWidget {
  const _BidTile({required this.job, required this.bid});

  final JobFeedItem job;
  final JobBid bid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$kCurrencySymbol ${bid.amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(bid.status)),
              ],
            ),
            if (bid.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(bid.message),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openChat(context, ref),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: bid.status == 'accepted'
                        ? null
                        : () => _acceptBid(context, ref),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    try {
      final thread = await ref.read(chatServiceProvider).createOrOpenThread(
            userId: job.createdBy,
            artisanId: bid.artisanId,
          );
      if (context.mounted) {
        context.go('${RouteNames.chatThread}/${thread.id}');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $error')),
        );
      }
    }
  }

  Future<void> _acceptBid(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(jobsRepositoryProvider).acceptBid(bid.id);
      if (!context.mounted) return;
      await _openChat(context, ref);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not accept bid: $error')),
        );
      }
    }
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
