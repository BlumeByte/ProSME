import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/location_data.dart';
import '../../core/utils/service_categories.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';
import 'jobs_repository.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';
  CountryOption? _selectedCountry;
  RegionOption? _selectedRegion;
  String _scope = 'open';
  bool _newestFirst = true;
  Set<String> _hiddenJobIds = const {};

  @override
  void initState() {
    super.initState();
    _loadHiddenJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHiddenJobs() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hiddenJobIds =
          (prefs.getStringList('hidden_jobs_${user.id}') ?? const []).toSet();
    });
  }

  Future<void> _hideJob(String jobId, {bool showNotice = true}) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final next = {..._hiddenJobIds, jobId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hidden_jobs_${user.id}', next.toList());
    if (!mounted) return;
    setState(() => _hiddenJobIds = next);
    if (showNotice) {
      final settings = ref.read(appSettingsControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Request removed from your list.'))),
      );
    }
  }

  Future<void> _confirmDeleteOrHideJob(JobFeedItem job) async {
    final settings = ref.read(appSettingsControllerProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final ownsJob = job.createdBy == user.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          settings.t(ownsJob ? 'Delete job request' : 'Remove job request'),
        ),
        content: Text(
          ownsJob
              ? '${settings.t('Delete')} "${job.title}" ${settings.t('permanently?')}'
              : '${settings.t('Remove')} "${job.title}" ${settings.t('from your list?')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(settings.t('Cancel')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete),
            label: Text(settings.t(ownsJob ? 'Delete' : 'Remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (ownsJob) {
        await ref.read(jobsRepositoryProvider).deleteJob(job.id);
        ref.invalidate(jobsStreamProvider);
      } else {
        await _hideJob(job.id, showNotice: false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.t(ownsJob
                ? 'Job request deleted.'
                : 'Request removed from your list.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${settings.t('Could not delete job request')}: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(appSettingsControllerProvider);
    final currencyCode = settings.currencyCode;
    if (user == null) {
      return Center(child: Text(settings.t('Please sign in to view jobs.')));
    }

    final canCreateJob =
        user.role == UserRole.customer || user.role == UserRole.artisan;
    final isArtisan = user.role == UserRole.artisan;
    final jobsAsync = ref.watch(jobsStreamProvider);
    final myBids = isArtisan
        ? ref.watch(artisanBidsProvider(user.id)).valueOrNull ?? const []
        : const <JobBid>[];
    final bidJobIds = myBids.map((bid) => bid.jobId).toSet();
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(settings.t('Bookings')),
              actions: [
                if (canCreateJob)
                  IconButton(
                    onPressed: () => _openCreateJobSheet(context, ref),
                    icon: const Icon(Icons.add),
                    tooltip: settings.t('Create job'),
                  ),
              ],
            )
          : null,
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${settings.t('Could not load jobs')}: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (jobs) {
          final visibleJobs = _filterJobs(
            jobs.where((job) => !_hiddenJobIds.contains(job.id)).toList(),
            bidJobIds: bidJobIds,
            isArtisan: isArtisan,
          );
          if (jobs.isEmpty) {
            return Center(
              child: Text(
                settings.t('No bookings yet. Create your first request.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(jobsStreamProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: visibleJobs.length + (isArtisan ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (isArtisan && index == 0) {
                  return _ArtisanJobFilters(
                    searchController: _searchController,
                    query: _query,
                    category: _category,
                    selectedCountry: _selectedCountry,
                    selectedRegion: _selectedRegion,
                    scope: _scope,
                    newestFirst: _newestFirst,
                    onSearchChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    onCategoryChanged: (value) =>
                        setState(() => _category = value),
                    onCountryChanged: (value) => setState(() {
                      _selectedCountry = value;
                      _selectedRegion = null;
                    }),
                    onRegionChanged: (value) =>
                        setState(() => _selectedRegion = value),
                    onScopeChanged: (value) => setState(() => _scope = value),
                    onSortChanged: () =>
                        setState(() => _newestFirst = !_newestFirst),
                    settings: settings,
                  );
                }
                final job = visibleJobs[index - (isArtisan ? 1 : 0)];
                final hasBid = bidJobIds.contains(job.id);
                final card = Card(
                  child: ListTile(
                    title: Text(job.title),
                    subtitle: Text(
                      '${job.location} - ${formatMoney(job.budget, currencyCode)}\n${_formatDateTime(job.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: FilledButton(
                      onPressed: () =>
                          context.push('${RouteNames.jobDetail}/${job.id}'),
                      child: Text(
                        isArtisan
                            ? settings.t(hasBid ? 'Edit bid' : 'Bid')
                            : job.createdBy == user.id
                                ? settings.t('View bids')
                                : settings.t('View'),
                      ),
                    ),
                    onTap: () =>
                        context.push('${RouteNames.jobDetail}/${job.id}'),
                    onLongPress: () => _confirmDeleteOrHideJob(job),
                  ),
                );
                if (!isArtisan && job.createdBy != user.id) return card;
                return Dismissible(
                  key: ValueKey('job_${job.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await _confirmDeleteOrHideJob(job);
                    return false;
                  },
                  child: card,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: canCreateJob
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateJobSheet(context, ref),
              icon: const Icon(Icons.add),
              label: Text(settings.t('Create')),
            )
          : null,
    );
  }

  List<JobFeedItem> _filterJobs(
    List<JobFeedItem> jobs, {
    required Set<String> bidJobIds,
    required bool isArtisan,
  }) {
    final filtered = jobs.where((job) {
      final text =
          '${job.title} ${job.description} ${job.location}'.toLowerCase();
      final queryMatches = _query.isEmpty || text.contains(_query);
      final categoryMatches = _category == 'All' ||
          normalizeServiceCategory(job.title) == _category ||
          normalizeServiceCategory(job.description) == _category ||
          text.contains(_category.toLowerCase());
      final countryMatches = _selectedCountry == null ||
          text.contains(_selectedCountry!.name.toLowerCase());
      final regionMatches = _selectedRegion == null ||
          text.contains(_selectedRegion!.name.toLowerCase());
      final scopeMatches = !isArtisan ||
          _scope == 'all' ||
          (_scope == 'open' && !bidJobIds.contains(job.id)) ||
          (_scope == 'bids' && bidJobIds.contains(job.id));
      return queryMatches &&
          categoryMatches &&
          countryMatches &&
          regionMatches &&
          scopeMatches;
    }).toList(growable: false);
    filtered.sort((a, b) => _newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return filtered;
  }
}

String _formatDateTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.month}/${value.day}/${value.year} $hour:$minute $suffix';
}

class _ArtisanJobFilters extends StatelessWidget {
  const _ArtisanJobFilters({
    required this.searchController,
    required this.query,
    required this.category,
    required this.selectedCountry,
    required this.selectedRegion,
    required this.scope,
    required this.newestFirst,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onCountryChanged,
    required this.onRegionChanged,
    required this.onScopeChanged,
    required this.onSortChanged,
    required this.settings,
  });

  final TextEditingController searchController;
  final String query;
  final String category;
  final CountryOption? selectedCountry;
  final RegionOption? selectedRegion;
  final String scope;
  final bool newestFirst;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<CountryOption?> onCountryChanged;
  final ValueChanged<RegionOption?> onRegionChanged;
  final ValueChanged<String> onScopeChanged;
  final VoidCallback onSortChanged;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...kServiceCategories.map((item) => item.name)];
    final regions = selectedCountry?.regions ?? const <RegionOption>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: settings.t('Search job requests'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                decoration: InputDecoration(labelText: settings.t('Type')),
                items: categories
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(settings.t(item),
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) onCategoryChanged(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onSortChanged,
              icon: Icon(
                newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              ),
              tooltip:
                  settings.t(newestFirst ? 'Newest first' : 'Oldest first'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<CountryOption?>(
                initialValue: selectedCountry,
                isExpanded: true,
                decoration: InputDecoration(labelText: settings.t('Country')),
                items: <CountryOption?>[null, ...kCountries]
                    .map(
                      (country) => DropdownMenuItem(
                        value: country,
                        child: Text(
                          country?.name ?? 'Any country',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onCountryChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<RegionOption?>(
                initialValue: selectedRegion,
                isExpanded: true,
                decoration: InputDecoration(labelText: settings.t('Region')),
                items: <RegionOption?>[null, ...regions]
                    .map(
                      (region) => DropdownMenuItem(
                        value: region,
                        child: Text(
                          region?.name ?? 'Any region',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: selectedCountry == null ? null : onRegionChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'open', label: Text(settings.t('Open'))),
            ButtonSegment(value: 'bids', label: Text(settings.t('My bids'))),
            ButtonSegment(value: 'all', label: Text(settings.t('All'))),
          ],
          selected: {scope},
          onSelectionChanged: (selection) => onScopeChanged(selection.first),
        ),
      ],
    );
  }
}

Future<void> _openCreateJobSheet(BuildContext context, WidgetRef ref) async {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  final budgetController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final settings = ref.read(appSettingsControllerProvider);
  final currencyCode = settings.currencyCode;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        settings.t('Create job'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: settings.t('Title')),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? settings.t('Title is required')
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: descriptionController,
                  minLines: 3,
                  maxLines: 4,
                  decoration:
                      InputDecoration(labelText: settings.t('Description')),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? settings.t('Description is required')
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: locationController,
                  decoration:
                      InputDecoration(labelText: settings.t('Location')),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? settings.t('Location is required')
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: budgetController,
                  decoration:
                      InputDecoration(labelText: 'Budget ($currencyCode)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final budget = double.tryParse(value ?? '');
                    if (budget == null || budget <= 0) {
                      return 'Enter a valid budget';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final user = ref.read(authStateProvider).valueOrNull;
                      if (user == null) return;
                      try {
                        await ref.read(jobsRepositoryProvider).createJob(
                              title: titleController.text.trim(),
                              description: descriptionController.text.trim(),
                              location: locationController.text.trim(),
                              budget: convertToGhs(
                                double.parse(budgetController.text),
                                currencyCode,
                              ),
                              createdBy: user.id,
                            );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                settings.t('Job created successfully.'),
                              ),
                            ),
                          );
                        }
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${settings.t('Failed to create job')}: $error',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(settings.t('Create job')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  titleController.dispose();
  descriptionController.dispose();
  locationController.dispose();
  budgetController.dispose();
}
