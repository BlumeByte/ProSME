import 'dart:async';

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
  List<CountryOption> _countries = kCountries;
  bool _loadingCountries = false;
  bool _loadingRegions = false;
  String _scope = 'open';
  bool _newestFirst = true;
  Set<String> _hiddenJobIds = const {};
  String? _hiddenJobsUserId;

  @override
  void initState() {
    super.initState();
    _loadHiddenJobs();
    _loadCountries();
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

  Future<void> _loadCountries() async {
    setState(() => _loadingCountries = true);
    try {
      final countries = await loadWorldCountries();
      if (!mounted) return;
      setState(() => _countries = countries);
    } catch (_) {
      // Keep the curated in-app country fallback if the package asset fails.
    } finally {
      if (mounted) setState(() => _loadingCountries = false);
    }
  }

  Future<void> _selectCountry(CountryOption? country) async {
    setState(() {
      _selectedCountry = country;
      _selectedRegion = null;
      _loadingRegions = country != null;
    });
    if (country == null) return;
    try {
      final hydrated = await loadCountryRegions(country);
      if (!mounted) return;
      setState(() {
        _selectedCountry = hydrated;
        _countries = _countries
            .map((item) => item.code == hydrated.code ? hydrated : item)
            .toList(growable: false);
      });
    } catch (_) {
      // Region/city typing remains available when hydration fails.
    } finally {
      if (mounted) setState(() => _loadingRegions = false);
    }
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
      _hiddenJobsUserId = null;
      return Center(child: Text(settings.t('Please sign in to view jobs.')));
    }
    if (_hiddenJobsUserId != user.id) {
      _hiddenJobsUserId = user.id;
      _hiddenJobIds = const {};
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHiddenJobs());
    }

    final canCreateJob =
        user.role == UserRole.customer || user.role == UserRole.artisan;
    final isArtisan = user.role == UserRole.artisan;
    final jobsAsync = ref.watch(jobsStreamProvider);
    final myBids = isArtisan
        ? ref.watch(artisanBidsProvider(user.id)).valueOrNull ?? const []
        : const <JobBid>[];
    final bidJobIds = myBids.map((bid) => bid.jobId).toSet();
    final acceptedJobIds = myBids
        .where((bid) => bid.status == 'accepted')
        .map((bid) => bid.jobId)
        .toSet();
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
          final participantJobs = jobs.where((job) {
            if (_hiddenJobIds.contains(job.id)) return false;
            if (job.workStatus == 'open') return true;
            return job.createdBy == user.id || acceptedJobIds.contains(job.id);
          }).toList(growable: false);
          final visibleJobs = _filterJobs(
            participantJobs,
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
          if (visibleJobs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(jobsStreamProvider),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (isArtisan) ...[
                    _ArtisanJobFilters(
                      searchController: _searchController,
                      query: _query,
                      category: _category,
                      selectedCountry: _selectedCountry,
                      selectedRegion: _selectedRegion,
                      countries: _countries,
                      loadingCountries: _loadingCountries,
                      loadingRegions: _loadingRegions,
                      scope: _scope,
                      newestFirst: _newestFirst,
                      onSearchChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      onCategoryChanged: (value) =>
                          setState(() => _category = value),
                      onCountryChanged: _selectCountry,
                      onRegionChanged: (value) =>
                          setState(() => _selectedRegion = value),
                      onScopeChanged: (value) => setState(() => _scope = value),
                      onSortChanged: () =>
                          setState(() => _newestFirst = !_newestFirst),
                      settings: settings,
                    ),
                    const SizedBox(height: 16),
                  ],
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Text(
                        settings.t('No matching jobs found.'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
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
                    countries: _countries,
                    loadingCountries: _loadingCountries,
                    loadingRegions: _loadingRegions,
                    scope: _scope,
                    newestFirst: _newestFirst,
                    onSearchChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    onCategoryChanged: (value) =>
                        setState(() => _category = value),
                    onCountryChanged: _selectCountry,
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
                final shownAmount = job.acceptedAmount ?? job.budget;
                final amountLabel = job.acceptedAmount == null
                    ? settings.t('Budget')
                    : settings.t('Accepted amount');
                final canTrack = job.workStatus != 'open' &&
                    (job.createdBy == user.id ||
                        acceptedJobIds.contains(job.id));
                final card = Card(
                  child: ListTile(
                    title: Text(job.title),
                    subtitle: Text(
                      '${job.location} - $amountLabel: ${formatMoney(shownAmount, currencyCode)}\n${settings.t(_jobStatusText(job.workStatus))} - ${_formatDateTime(job.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: FilledButton(
                      onPressed: () =>
                          context.push('${RouteNames.jobDetail}/${job.id}'),
                      child: Text(
                        canTrack
                            ? settings.t('Track')
                            : isArtisan
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

String _jobStatusText(String status) {
  switch (status) {
    case 'accepted':
      return 'Accepted';
    case 'start_pending':
      return 'Start pending';
    case 'in_progress':
      return 'In progress';
    case 'completion_pending':
      return 'Completion pending';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return 'Open';
  }
}

class _ArtisanJobFilters extends StatelessWidget {
  const _ArtisanJobFilters({
    required this.searchController,
    required this.query,
    required this.category,
    required this.selectedCountry,
    required this.selectedRegion,
    required this.countries,
    required this.loadingCountries,
    required this.loadingRegions,
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
  final List<CountryOption> countries;
  final bool loadingCountries;
  final bool loadingRegions;
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
                decoration: InputDecoration(
                  labelText: settings.t('Country'),
                  suffixIcon: loadingCountries
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                items: <CountryOption?>[null, ...countries]
                    .map(
                      (country) => DropdownMenuItem(
                        value: country,
                        child: Text(
                          country?.name ?? settings.t('Any country'),
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
                decoration: InputDecoration(
                  labelText: settings.t('Region'),
                  suffixIcon: loadingRegions
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                items: <RegionOption?>[null, ...regions]
                    .map(
                      (region) => DropdownMenuItem(
                        value: region,
                        child: Text(
                          region?.name ?? settings.t('Any region'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: selectedCountry == null || loadingRegions
                    ? null
                    : onRegionChanged,
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
  final user = ref.read(authStateProvider).valueOrNull;
  var countries = await loadWorldCountries();
  CountryOption? selectedCountry;
  RegionOption? selectedRegion;
  CityOption? selectedCity;
  String? selectedTown;
  var countryText = '';
  var regionText = '';
  var cityText = '';
  var townText = '';
  var loadingRegions = false;
  if (user != null) {
    for (final country in countries) {
      if (country.name.toLowerCase() == user.country.toLowerCase() ||
          country.code.toLowerCase() == user.country.toLowerCase()) {
        selectedCountry = country;
        countryText = country.name;
        break;
      }
    }
  }
  if (selectedCountry != null) {
    final hydrated = await loadCountryRegions(selectedCountry);
    selectedCountry = hydrated;
    countries = countries
        .map((country) => country.code == hydrated.code ? hydrated : country)
        .toList(growable: false);
  }
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(builder: (context, setSheetState) {
        final regions = selectedCountry?.regions ?? const <RegionOption>[];
        final cities = selectedRegion?.cities ?? const <CityOption>[];
        final towns = selectedCity?.towns ?? const <String>[];
        Future<void> selectCountryName(String value) async {
          countryText = value.trim();
          final country = _bestCountryMatch(countries, countryText);
          setSheetState(() {
            selectedCountry = country;
            selectedRegion = null;
            selectedCity = null;
            selectedTown = null;
            regionText = '';
            cityText = '';
            townText = '';
            loadingRegions = country != null;
          });
          if (country == null) return;
          final hydrated = await loadCountryRegions(country);
          if (!context.mounted) return;
          setSheetState(() {
            selectedCountry = hydrated;
            countries = countries
                .map((item) => item.code == hydrated.code ? hydrated : item)
                .toList(growable: false);
            loadingRegions = false;
          });
        }

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
                  _LocationAutocompleteField(
                    label: settings.t('Country'),
                    initialValue: countryText,
                    options: countries.map((country) => country.name),
                    onChanged: (value) {
                      countryText = value.trim();
                      final match = _exactCountryMatch(countries, countryText);
                      if (match == null || match == selectedCountry) return;
                      unawaited(selectCountryName(match.name));
                    },
                    onSelected: (value) => unawaited(selectCountryName(value)),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? settings.t('Country is required')
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _LocationAutocompleteField(
                    label: settings.t('Region'),
                    initialValue: regionText,
                    options: regions.map((region) => region.name),
                    enabled: !loadingRegions,
                    suffixIcon: loadingRegions
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    onChanged: (value) {
                      regionText = value.trim();
                      final match = _exactRegionMatch(regions, regionText);
                      if (match == null || match == selectedRegion) return;
                      setSheetState(() {
                        selectedRegion = match;
                        selectedCity = null;
                        selectedTown = null;
                        cityText = '';
                        townText = '';
                      });
                    },
                    onSelected: (value) {
                      final region = _bestRegionMatch(regions, value);
                      setSheetState(() {
                        regionText = value.trim();
                        selectedRegion = region;
                        selectedCity = null;
                        selectedTown = null;
                        cityText = '';
                        townText = '';
                      });
                    },
                    validator: (value) => value == null || value.trim().isEmpty
                        ? settings.t('Region is required')
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _LocationAutocompleteField(
                    label: settings.t('City'),
                    initialValue: cityText,
                    options: cities.map((city) => city.name),
                    onChanged: (value) {
                      cityText = value.trim();
                      final match = _exactCityMatch(cities, cityText);
                      if (match == null || match == selectedCity) return;
                      setSheetState(() {
                        selectedCity = match;
                        selectedTown = null;
                        townText = '';
                      });
                    },
                    onSelected: (value) {
                      final city = _bestCityMatch(cities, value);
                      setSheetState(() {
                        cityText = value.trim();
                        selectedCity = city;
                        selectedTown = null;
                        townText = '';
                      });
                    },
                    validator: (value) => value == null || value.trim().isEmpty
                        ? settings.t('City is required')
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _LocationAutocompleteField(
                    label: settings.t('Town'),
                    initialValue: townText,
                    options: towns.where((town) => town != 'Any'),
                    onChanged: (value) {
                      townText = value.trim();
                      selectedTown = townText.isEmpty ? null : townText;
                    },
                    onSelected: (value) {
                      setSheetState(() {
                        townText = value.trim();
                        selectedTown = townText.isEmpty ? null : townText;
                      });
                    },
                    helperText: settings.t('Optional'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: settings.t('Street, area, or landmark'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: budgetController,
                    decoration: InputDecoration(
                      labelText: '${settings.t('Budget')} ($currencyCode)',
                    ),
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
                        if (user == null) return;
                        final location = _composeJobLocation(
                          details: locationController.text,
                          country: countryText,
                          region: regionText,
                          city: cityText,
                          town: selectedTown ?? townText,
                        );
                        try {
                          await ref.read(jobsRepositoryProvider).createJob(
                                title: titleController.text.trim(),
                                description: descriptionController.text.trim(),
                                location: location,
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
      });
    },
  );
  titleController.dispose();
  descriptionController.dispose();
  locationController.dispose();
  budgetController.dispose();
}

String _composeJobLocation({
  required String details,
  required String country,
  required String region,
  required String city,
  required String? town,
}) {
  final parts = <String>[
    details.trim(),
    if (town != null && town != 'Any') town,
    city,
    region,
    country,
  ].where((part) => part.trim().isNotEmpty).toList(growable: false);
  return parts.join(', ');
}

class _LocationAutocompleteField extends StatelessWidget {
  const _LocationAutocompleteField({
    required this.label,
    required this.options,
    required this.onChanged,
    required this.onSelected,
    this.initialValue = '',
    this.validator,
    this.enabled = true,
    this.suffixIcon,
    this.helperText,
  });

  final String label;
  final String initialValue;
  final Iterable<String> options;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelected;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final Widget? suffixIcon;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      key: ValueKey('$label|$initialValue|${options.length}|$enabled'),
      initialValue: TextEditingValue(text: initialValue),
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        final cleaned = options
            .where((option) => option.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        if (query.isEmpty) return cleaned.take(12);
        return cleaned
            .where((option) => option.toLowerCase().contains(query))
            .take(12);
      },
      onSelected: onSelected,
      fieldViewBuilder: (
        context,
        controller,
        focusNode,
        onFieldSubmitted,
      ) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            suffixIcon: suffixIcon,
          ),
          textInputAction: TextInputAction.next,
          onChanged: onChanged,
          validator: validator,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option, overflow: TextOverflow.ellipsis),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

CountryOption? _exactCountryMatch(
  Iterable<CountryOption> countries,
  String value,
) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final country in countries) {
    if (country.name.toLowerCase() == normalized ||
        country.code.toLowerCase() == normalized) {
      return country;
    }
  }
  return null;
}

CountryOption? _bestCountryMatch(
  Iterable<CountryOption> countries,
  String value,
) {
  return _exactCountryMatch(countries, value);
}

RegionOption? _exactRegionMatch(Iterable<RegionOption> regions, String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final region in regions) {
    if (region.name.toLowerCase() == normalized ||
        region.code?.toLowerCase() == normalized) {
      return region;
    }
  }
  return null;
}

RegionOption? _bestRegionMatch(Iterable<RegionOption> regions, String value) {
  return _exactRegionMatch(regions, value);
}

CityOption? _exactCityMatch(Iterable<CityOption> cities, String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final city in cities) {
    if (city.name.toLowerCase() == normalized) return city;
  }
  return null;
}

CityOption? _bestCityMatch(Iterable<CityOption> cities, String value) {
  return _exactCityMatch(cities, value);
}
