import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../config/constants.dart';
import '../../core/utils/currency.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../models/chat_models.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
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
    final settings = ref.watch(appSettingsControllerProvider);
    final currencyCode = settings.currencyCode;
    final jobsAsync = ref.watch(jobsStreamProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('Job details')),
      ),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessageState(
          message: '${settings.t('Could not load this job')}: $error',
        ),
        data: (jobs) {
          final job = _findJob(jobs, widget.jobId);
          if (job == null) {
            return _MessageState(
              message: settings.t('This job is no longer available.'),
            );
          }

          final isOwner = user?.id == job.createdBy;
          final isArtisan = user?.role == UserRole.artisan;
          final bids = ref.watch(jobBidsProvider(job.id)).valueOrNull ??
              const <JobBid>[];
          final acceptedBid =
              bids.where((bid) => bid.status == 'accepted').firstOrNull;
          final existingBid = isArtisan && user != null
              ? bids.where((bid) => bid.artisanId == user.id).firstOrNull
              : null;
          if (existingBid != null &&
              _amountController.text.isEmpty &&
              _messageController.text.isEmpty) {
            _amountController.text =
                convertFromGhs(existingBid.amount, currencyCode)
                    .toStringAsFixed(0);
            _messageController.text = existingBid.message;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _JobSummary(
                job: job,
                currencyCode: currencyCode,
                settings: settings,
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_outlined),
                  title: Text(settings.t('Before you continue')),
                  subtitle: Text(
                    settings.t(
                      'Negotiate in chat and confirm verification status before payment or site visits.',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (acceptedBid != null &&
                  user != null &&
                  (isOwner || acceptedBid.artisanId == user.id)) ...[
                _JobTrackingPanel(job: job),
                const SizedBox(height: 16),
              ],
              if (user == null)
                FilledButton(
                  onPressed: () => context.go(RouteNames.auth),
                  child: Text(settings.t('Sign in to bid or chat')),
                )
              else if (isOwner) ...[
                _EditJobCard(job: job, currencyCode: currencyCode),
                const SizedBox(height: 12),
                _BidsForOwner(job: job, currencyCode: currencyCode),
              ] else if (isArtisan &&
                  (acceptedBid == null || acceptedBid.artisanId == user.id))
                _BidForm(
                  formKey: _formKey,
                  amountController: _amountController,
                  messageController: _messageController,
                  submitting: _submitting,
                  existingBid: existingBid,
                  currencyCode: currencyCode,
                  settings: settings,
                  onSubmit: () => _submitBid(job),
                )
              else if (isArtisan && acceptedBid != null)
                _MessageState(
                  message: settings.t(
                    'This job has already been assigned to another artisan.',
                  ),
                )
              else
                _MessageState(
                  message: settings.t(
                    'Only artisans can bid on service requests.',
                  ),
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
      final currencyCode = ref.read(appSettingsControllerProvider).currencyCode;
      final amount = convertToGhs(
        double.parse(_amountController.text.trim()),
        currencyCode,
      );
      final bid = await ref.read(jobsRepositoryProvider).createBid(
            jobId: job.id,
            artisanId: user.id,
            amount: amount,
            message: _messageController.text.trim(),
          );
      if (!mounted) return;
      _amountController.clear();
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(appSettingsControllerProvider).t(
                  bid.createdAt.isBefore(
                          DateTime.now().subtract(const Duration(seconds: 2)))
                      ? 'Bid updated. Chat opens after the customer accepts it.'
                      : 'Bid sent. Chat opens after the customer accepts it.',
                ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ref.read(appSettingsControllerProvider).t('Could not send bid')}: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _JobSummary extends StatelessWidget {
  const _JobSummary({
    required this.job,
    required this.currencyCode,
    required this.settings,
  });

  final JobFeedItem job;
  final String currencyCode;
  final AppSettings settings;

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
              '${formatMoney(job.budget, currencyCode)} ${settings.t('budget')}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(job.description),
            if (job.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  job.images.first,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JobTrackingPanel extends ConsumerWidget {
  const _JobTrackingPanel({required this.job});

  final JobFeedItem job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final eventsAsync = ref.watch(jobProgressProvider(job.id));
    final status = job.workStatus;
    final canStart = status == 'accepted';
    final canComplete = status == 'accepted' || status == 'in_progress';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    settings.t('Job tracking'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(settings.t(_statusLabel(status)))),
              ],
            ),
            if (job.etaAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '${settings.t('Estimated completion')}: ${_dateTimeLabel(context, job.etaAt!)}',
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canStart)
                  FilledButton.icon(
                    onPressed: () => _updateProgress(
                      context,
                      ref,
                      status: 'in_progress',
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(settings.t('Start work')),
                  ),
                if (canComplete)
                  OutlinedButton.icon(
                    onPressed: () => _updateProgress(
                      context,
                      ref,
                      status: status,
                      etaOnly: true,
                    ),
                    icon: const Icon(Icons.schedule),
                    label: Text(settings.t('Update ETA')),
                  ),
                if (canComplete)
                  FilledButton.tonalIcon(
                    onPressed: () => _updateProgress(
                      context,
                      ref,
                      status: 'completed',
                    ),
                    icon: const Icon(Icons.task_alt),
                    label: Text(settings.t('Mark completed')),
                  ),
              ],
            ),
            const Divider(height: 28),
            Text(
              settings.t('Timeline'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            eventsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                '${settings.t('Could not load timeline')}: $error',
              ),
              data: (events) {
                if (events.isEmpty) {
                  return Text(settings.t('No progress updates yet.'));
                }
                return Column(
                  children: events.reversed
                      .map(
                        (event) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(_statusIcon(event.status)),
                          title: Text(settings.t(_statusLabel(event.status))),
                          subtitle: Text(
                            [
                              _dateTimeLabel(context, event.createdAt),
                              if (event.note.isNotEmpty) event.note,
                              if (event.etaAt != null)
                                '${settings.t('ETA')}: ${_dateTimeLabel(context, event.etaAt!)}',
                            ].join('\n'),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProgress(
    BuildContext context,
    WidgetRef ref, {
    required String status,
    bool etaOnly = false,
  }) async {
    final settings = ref.read(appSettingsControllerProvider);
    DateTime? eta = job.etaAt;
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            settings.t(etaOnly ? 'Update ETA' : _statusLabel(status)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status != 'completed')
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    eta == null
                        ? settings.t('Choose estimated completion')
                        : _dateTimeLabel(context, eta!),
                  ),
                  onTap: () async {
                    final selected = await _pickEta(context, eta);
                    if (selected != null) {
                      setDialogState(() => eta = selected);
                    }
                  },
                ),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: settings.t('Progress note (optional)'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(settings.t('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(settings.t('Save')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      noteController.dispose();
      return;
    }
    final note = noteController.text.trim();
    noteController.dispose();
    try {
      await ref.read(jobsRepositoryProvider).updateProgress(
            jobId: job.id,
            status: status,
            etaAt: eta,
            note: note,
          );
      ref.invalidate(jobProgressProvider(job.id));
      ref.invalidate(jobsStreamProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Job progress updated.'))),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${settings.t('Could not update status')}: $error'),
        ),
      );
    }
  }
}

Future<DateTime?> _pickEta(BuildContext context, DateTime? initial) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial?.isAfter(now) == true ? initial! : now,
    firstDate: now,
    lastDate: now.add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime:
        initial == null ? TimeOfDay.now() : TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _dateTimeLabel(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatMediumDate(local);
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
  );
  return '$date, $time';
}

String _statusLabel(String status) {
  switch (status) {
    case 'in_progress':
      return 'In progress';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    case 'accepted':
      return 'Accepted';
    default:
      return 'Open';
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'in_progress':
      return Icons.handyman_outlined;
    case 'completed':
      return Icons.task_alt;
    case 'cancelled':
      return Icons.cancel_outlined;
    case 'accepted':
      return Icons.handshake_outlined;
    default:
      return Icons.radio_button_checked;
  }
}

class _EditJobCard extends ConsumerWidget {
  const _EditJobCard({required this.job, required this.currencyCode});

  final JobFeedItem job;
  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(settings.t('Edit job')),
            subtitle: Text(settings.t('Update details or add an image URL.')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editJob(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(settings.t('Delete job')),
            subtitle: Text(settings.t('Permanently remove this request.')),
            onTap: () => _deleteJob(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteJob(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(appSettingsControllerProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Delete job request')),
        content: Text(
          '${settings.t('Delete')} "${job.title}" ${settings.t('permanently?')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete),
            label: Text(settings.t('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(jobsRepositoryProvider).deleteJob(job.id);
      ref.invalidate(jobsStreamProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(settings.t('Job request deleted.'))),
        );
        context.pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${settings.t('Could not delete job request')}: $error'),
          ),
        );
      }
    }
  }

  Future<void> _editJob(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(appSettingsControllerProvider);
    final titleController = TextEditingController(text: job.title);
    final descriptionController = TextEditingController(text: job.description);
    final locationController = TextEditingController(text: job.location);
    final budgetController = TextEditingController(
      text: convertFromGhs(job.budget, currencyCode).toStringAsFixed(0),
    );
    final imageController =
        TextEditingController(text: job.images.isEmpty ? '' : job.images.first);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.t('Edit job')),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: settings.t('Title')),
                  validator: (value) => _required(value, settings),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descriptionController,
                  minLines: 3,
                  maxLines: 4,
                  decoration:
                      InputDecoration(labelText: settings.t('Description')),
                  validator: (value) => _required(value, settings),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: locationController,
                  decoration:
                      InputDecoration(labelText: settings.t('Location')),
                  validator: (value) => _required(value, settings),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: budgetController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${settings.t('Budget')} ($currencyCode)',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return settings.t('Required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: imageController,
                  decoration: InputDecoration(
                    labelText: settings.t('Image URL (optional)'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop(true);
            },
            child: Text(settings.t('Save')),
          ),
        ],
      ),
    );

    if (saved == true) {
      final image = imageController.text.trim();
      try {
        await ref.read(jobsRepositoryProvider).updateJob(
              jobId: job.id,
              title: titleController.text.trim(),
              description: descriptionController.text.trim(),
              location: locationController.text.trim(),
              budget: convertToGhs(
                double.parse(budgetController.text.trim()),
                currencyCode,
              ),
              images: image.isEmpty ? const [] : [image],
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(settings.t('Job updated.'))),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${settings.t('Could not update job')}: $error'),
            ),
          );
        }
      }
    }

    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    budgetController.dispose();
    imageController.dispose();
  }
}

class _BidForm extends StatelessWidget {
  const _BidForm({
    required this.formKey,
    required this.amountController,
    required this.messageController,
    required this.submitting,
    required this.existingBid,
    required this.currencyCode,
    required this.settings,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final TextEditingController messageController;
  final bool submitting;
  final JobBid? existingBid;
  final String currencyCode;
  final AppSettings settings;
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
              Text(
                settings
                    .t(existingBid == null ? 'Send a bid' : 'Edit your bid'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (existingBid != null) ...[
                const SizedBox(height: 6),
                Text(
                  settings.t(
                    existingBid!.status == 'accepted'
                        ? 'This bid has been accepted and can no longer be changed.'
                        : 'You already bid on this job. Update your amount or message here.',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: '${settings.t('Your price')} ($currencyCode)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim());
                  if (amount == null || amount <= 0) {
                    return settings.t('Enter a valid price');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: messageController,
                minLines: 3,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: settings.t('Message'),
                  hintText: settings.t(
                    'Explain your offer, availability, or questions.',
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return settings.t('Message is required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: submitting || existingBid?.status == 'accepted'
                      ? null
                      : onSubmit,
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    settings.t(
                      existingBid == null
                          ? 'Send bid and open chat'
                          : 'Update bid and open chat',
                    ),
                  ),
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
  const _BidsForOwner({required this.job, required this.currencyCode});

  final JobFeedItem job;
  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final bidsAsync = ref.watch(jobBidsProvider(job.id));
    return bidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _MessageState(
          message: '${settings.t('Could not load bids')}: $error'),
      data: (bids) {
        if (bids.isEmpty) {
          return _MessageState(
            message: settings.t(
              'No bids yet. Artisans will appear here after they respond.',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(settings.t('Bids'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...bids.map(
              (bid) => _BidTile(job: job, bid: bid, currencyCode: currencyCode),
            ),
          ],
        );
      },
    );
  }
}

class _BidTile extends ConsumerWidget {
  const _BidTile({
    required this.job,
    required this.bid,
    required this.currencyCode,
  });

  final JobFeedItem job;
  final JobBid bid;
  final String currencyCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(appSettingsControllerProvider);
    final ratings = ref.watch(jobRatingsProvider(job.id)).valueOrNull ??
        const <JobRating>[];
    final existingRating = ratings
        .where((rating) => rating.artisanId == bid.artisanId)
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage:
                      (bid.artisanAvatarUrl?.trim().isNotEmpty ?? false)
                          ? NetworkImage(bid.artisanAvatarUrl!)
                          : null,
                  child: (bid.artisanAvatarUrl?.trim().isNotEmpty ?? false)
                      ? null
                      : const Icon(Icons.person_outline),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bid.artisanName ?? 'Artisan ${bid.artisanId}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${bid.acceptedBidCount} ${settings.t(bid.acceptedBidCount == 1 ? 'won bid' : 'won bids')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    bid.artisanVerified
                        ? Icons.verified
                        : Icons.pending_actions_outlined,
                    size: 16,
                  ),
                  label: Text(
                    bid.artisanVerified ? settings.t('Verified') : bid.status,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              formatMoney(bid.amount, currencyCode),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (bid.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(bid.message),
            ],
            if (existingRating != null) ...[
              const SizedBox(height: 8),
              Text(
                '${settings.t('Rated')} ${existingRating.stars}/5${existingRating.comment.isEmpty ? '' : ': ${existingRating.comment}'}',
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: bid.status == 'accepted'
                        ? () => _openChat(context, ref)
                        : null,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(
                      settings.t(
                        bid.status == 'accepted' ? 'Chat' : 'Chat after accept',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: bid.status == 'accepted'
                        ? null
                        : () => _acceptBid(context, ref),
                    child: Text(settings.t('Accept')),
                  ),
                ),
              ],
            ),
            if (bid.status == 'accepted' &&
                user != null &&
                job.workStatus == 'completed') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _rateArtisan(context, ref, user.id),
                  icon: const Icon(Icons.star_outline),
                  label: Text(
                    settings.t(
                      existingRating == null ? 'Rate artisan' : 'Update rating',
                    ),
                  ),
                ),
              ),
            ],
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
        context.push('${RouteNames.chatThread}/${thread.id}');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ref.read(appSettingsControllerProvider).t('Could not open chat')}: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _acceptBid(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(jobsRepositoryProvider).acceptBid(bid.id);
      if (!context.mounted) return;
      final thread = await ref.read(chatServiceProvider).createOrOpenThread(
            userId: job.createdBy,
            artisanId: bid.artisanId,
          );
      final settings = ref.read(appSettingsControllerProvider);
      final locationLine = _jobLocationMessage(job, settings);
      await ref.read(chatServiceProvider).sendMessage(
            ChatMessage(
              id: const Uuid().v4(),
              threadId: thread.id,
              senderId: job.createdBy,
              type: MessageType.offer,
              content:
                  '${settings.t('Bid accepted for')} ${job.title}: ${formatMoney(bid.amount, currencyCode)}.\n$locationLine',
              createdAt: DateTime.now(),
            ),
          );
      if (context.mounted) {
        context.push('${RouteNames.chatThread}/${thread.id}');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${ref.read(appSettingsControllerProvider).t('Could not accept bid')}: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _rateArtisan(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final settings = ref.read(appSettingsControllerProvider);
    var stars = 5;
    final commentController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(settings.t('Rate artisan')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1')),
                    ButtonSegment(value: 2, label: Text('2')),
                    ButtonSegment(value: 3, label: Text('3')),
                    ButtonSegment(value: 4, label: Text('4')),
                    ButtonSegment(value: 5, label: Text('5')),
                  ],
                  selected: {stars},
                  onSelectionChanged: (selection) {
                    setDialogState(() => stars = selection.first);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: settings.t('Comment'),
                    hintText: settings.t('Describe the completed job.'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(settings.t('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(settings.t('Save rating')),
              ),
            ],
          );
        },
      ),
    );
    if (submitted != true) {
      commentController.dispose();
      return;
    }
    final comment = commentController.text.trim();
    commentController.dispose();
    try {
      await ref.read(jobsRepositoryProvider).rateJob(
            jobId: job.id,
            artisanId: bid.artisanId,
            userId: userId,
            stars: stars,
            comment: comment,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(settings.t('Rating saved.'))),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${settings.t('Could not save rating')}: $error'),
          ),
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

String? _required(String? value, AppSettings settings) {
  return value == null || value.trim().isEmpty ? settings.t('Required') : null;
}

String _jobLocationMessage(JobFeedItem job, AppSettings settings) {
  final hasCoordinates = job.locationLat != null && job.locationLng != null;
  if (!hasCoordinates) {
    return '${settings.t('Work location')}: ${job.location}';
  }
  final mapsUrl =
      'https://www.google.com/maps/search/?api=1&query=${job.locationLat},${job.locationLng}';
  return '${settings.t('Work location')}: ${job.location}\n${settings.t('Directions')}: $mapsUrl';
}
