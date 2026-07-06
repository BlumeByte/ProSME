import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/currency.dart';
import '../../core/utils/location_data.dart';
import '../../core/utils/service_categories.dart';
import '../../core/utils/town_neighborhood_data.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/location_lookup_service.dart';
import '../../services/notification_service.dart';
import '../../services/service_providers.dart';
import '../../models/listing.dart';
import '../jobs/jobs_repository.dart';

bool _matchesLocation(String target, String query) {
  final tokens = query
      .toLowerCase()
      .split(RegExp(r'[\s,]+'))
      .where((token) => token.length > 2)
      .toList(growable: false);
  if (tokens.isEmpty) return true;
  return tokens.any((token) => fuzzyContains(target, token));
}

enum _ArtisanUpdateSort { newest, priceLow, priceHigh, rating, category }

List<Listing> _sortedArtisanUpdates(
  List<Listing> listings,
  _ArtisanUpdateSort sort,
) {
  final sorted = List<Listing>.from(listings);
  switch (sort) {
    case _ArtisanUpdateSort.newest:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case _ArtisanUpdateSort.priceLow:
      sorted.sort((a, b) => a.priceMin.compareTo(b.priceMin));
      break;
    case _ArtisanUpdateSort.priceHigh:
      sorted.sort((a, b) => b.priceMax.compareTo(a.priceMax));
      break;
    case _ArtisanUpdateSort.rating:
      sorted.sort((a, b) {
        final rating = b.ratingAverage.compareTo(a.ratingAverage);
        return rating == 0 ? b.ratingCount.compareTo(a.ratingCount) : rating;
      });
      break;
    case _ArtisanUpdateSort.category:
      sorted.sort((a, b) {
        final category = normalizeServiceCategory(a.category)
            .compareTo(normalizeServiceCategory(b.category));
        return category == 0 ? b.createdAt.compareTo(a.createdAt) : category;
      });
      break;
  }
  return sorted;
}

class ListingFeedScreen extends ConsumerStatefulWidget {
  const ListingFeedScreen(
      {super.key,
      this.openingBanner,
      this.onOpenUploadTab,
      this.onLeaveHomeContent});

  final Widget? openingBanner;
  final VoidCallback? onOpenUploadTab;
  final VoidCallback? onLeaveHomeContent;

  @override
  ConsumerState<ListingFeedScreen> createState() => _ListingFeedScreenState();
}

class _ListingFeedScreenState extends ConsumerState<ListingFeedScreen> {
  final _serviceController = TextEditingController();
  final _locationController = TextEditingController();
  final _locationLookup = LocationLookupService();
  String _serviceQuery = '';
  String _locationQuery = '';
  String? _selectedCategory;
  CountryOption? _selectedCountry;
  RegionOption? _selectedRegion;
  CityOption? _selectedCity;
  String? _selectedTown;
  List<CountryOption> _countries = kCountries;
  bool _appliedUserCountry = false;
  bool _loadingCountries = false;
  bool _loadingRegions = false;
  bool _showSearchResults = false;
  bool _locating = false;
  bool _locationLookupBusy = false;
  bool _seenInitialListings = false;
  int _locationLookupRun = 0;
  String? _latestListingId;
  List<String> _recentSearches = const [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadCountries();
  }

  @override
  void dispose() {
    _serviceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final typedLocation = _locationController.text.trim();
    final parts = [
      typedLocation,
      _selectedTown,
      _selectedCity?.name,
      _selectedRegion?.name,
      _selectedCountry?.name,
    ].whereType<String>().where((item) => item.trim().isNotEmpty).toList();
    setState(() {
      _serviceQuery = _serviceController.text.trim().toLowerCase();
      _locationQuery = parts.join(' ').toLowerCase();
      _selectedCategory = null;
      _showSearchResults =
          _serviceQuery.isNotEmpty || _locationQuery.isNotEmpty;
    });
    _saveRecentSearch();
    unawaited(_enrichTypedLocation(typedLocation));
  }

  Future<void> _enrichTypedLocation(String typedLocation) async {
    final run = ++_locationLookupRun;
    if (typedLocation.length < 3) {
      setState(() => _locationLookupBusy = false);
      return;
    }
    setState(() => _locationLookupBusy = true);
    final result = await _locationLookup.searchOne(
      typedLocation,
      countryCode: _selectedCountry?.code,
    );
    if (!mounted || run != _locationLookupRun) return;
    setState(() {
      _locationLookupBusy = false;
      if (result == null) return;
      final parts = [
        _locationController.text.trim(),
        result.searchText,
        _selectedTown,
        _selectedCity?.name,
        _selectedRegion?.name,
        _selectedCountry?.name,
      ].whereType<String>().where((item) => item.trim().isNotEmpty);
      _locationQuery = parts.join(' ').toLowerCase();
      if (!_showSearchResults) {
        _showSearchResults =
            _serviceQuery.isNotEmpty || _locationQuery.isNotEmpty;
      }
    });
  }

  void _applyCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _serviceController.text = category;
      _serviceQuery = category.toLowerCase();
      _showSearchResults = true;
    });
    _saveRecentSearch();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? const [];
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
      _selectedCity = null;
      _selectedTown = null;
    });
    if (country == null) return;
    setState(() => _loadingRegions = true);
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
      // Region/city/town typing remains available when hydration fails.
    } finally {
      if (mounted) setState(() => _loadingRegions = false);
    }
  }

  Future<void> _saveRecentSearch() async {
    final query = [
      _serviceController.text.trim(),
      _selectedTown ??
          _selectedCity?.name ??
          _selectedRegion?.name ??
          _selectedCountry?.name ??
          '',
    ].where((item) => item.isNotEmpty).join(' in ');
    if (query.trim().isEmpty) return;
    final next = [query, ..._recentSearches.where((item) => item != query)]
        .take(8)
        .toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_searches', next);
    if (mounted) setState(() => _recentSearches = next);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_searches');
    if (mounted) setState(() => _recentSearches = const []);
  }

  Future<void> _usePhoneLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          final settings = ref.read(appSettingsControllerProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(settings.t('Location permission is required.')),
            ),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _locationController.text =
            '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
      });
      _applySearch();
    } catch (error) {
      if (mounted) {
        final settings = ref.read(appSettingsControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${settings.t('Could not access phone location')}: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _clearSearchResults() {
    setState(() {
      _showSearchResults = false;
      _serviceQuery = '';
      _locationQuery = '';
      _selectedCategory = null;
      _serviceController.clear();
      _locationController.clear();
    });
  }

  Future<bool> _confirmUnverified(_ProfessionalPreview pro) async {
    if (pro.isVerified) return true;
    final settings = ref.read(appSettingsControllerProvider);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(settings.t('Unverified artisan')),
            content: Text(
              '${pro.name} ${settings.t('has not been verified by ProSME Support yet. Continue only if you are comfortable engaging this artisan.')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(settings.t('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(settings.t('Continue')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _bookProfessional(_ProfessionalPreview pro) async {
    if (pro.isBusy) {
      _showUnavailable();
      return;
    }
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      context.go(RouteNames.auth);
      return;
    }
    if (user.id == pro.artisanId) {
      final settings = ref.read(appSettingsControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.t('You cannot book your own listing.')),
        ),
      );
      return;
    }
    if (!await _confirmUnverified(pro)) return;
    if (mounted) {
      widget.onLeaveHomeContent?.call();
      context.push('${RouteNames.listingDetail}/${pro.listingId}');
    }
  }

  void _showUnavailable() {
    final settings = ref.read(appSettingsControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(settings.t('This artisan is currently unavailable.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final settings = ref.watch(appSettingsControllerProvider);
    final currencyCode = settings.currencyCode;
    final scheme = Theme.of(context).colorScheme;
    if (!_appliedUserCountry && user != null && !_loadingCountries) {
      final userCountry = user.country.trim().toLowerCase();
      if (userCountry.isNotEmpty) {
        _appliedUserCountry = true;
        final country = _countries.firstWhere(
          (item) =>
              item.name.toLowerCase() == userCountry ||
              item.code.toLowerCase() == userCountry,
          orElse: () => countryByName(user.country),
        );
        if (country.name.toLowerCase() == userCountry ||
            country.code.toLowerCase() == userCountry) {
          unawaited(_selectCountry(country));
        }
      }
    }

    final listingsAsync = ref.watch(listingsStreamProvider);
    return listingsAsync.when(
      error: (_, __) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              settings.t(
                'Could not load professionals. Please check your connection and try again.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      data: (listings) {
        _notifyOnNewListing(listings);
        final filtered = listings.where((listing) {
          final serviceText =
              '${listing.title} ${listing.description} ${listing.category}'
                  .toLowerCase();
          final locationText = listing.location.toLowerCase();
          final serviceMatches = _serviceQuery.isEmpty ||
              fuzzyContains(serviceText, _serviceQuery);
          final categoryMatches = _selectedCategory == null ||
              normalizeServiceCategory(listing.category) == _selectedCategory ||
              fuzzyContains(listing.category, _selectedCategory!);
          final locationMatches = _locationQuery.isEmpty ||
              _matchesLocation(locationText, _locationQuery);
          return serviceMatches && categoryMatches && locationMatches;
        }).toList(growable: false);

        final categoryCounts = <String, int>{};
        for (final listing in filtered) {
          final category = normalizeServiceCategory(listing.category);
          categoryCounts.update(category, (value) => value + 1,
              ifAbsent: () => 1);
        }
        final categoryCards = kServiceCategories
            .map((item) => _CategoryPreview(
                  item.name,
                  item.icon,
                  categoryCounts[item.name] ?? 0,
                ))
            .where((item) => item.count > 0)
            .toList(growable: false);

        final professionalsById = <String, _ProfessionalPreview>{};
        for (final listing in filtered) {
          final existing = professionalsById[listing.artisanId];
          if (existing == null) {
            professionalsById[listing.artisanId] = _ProfessionalPreview(
              artisanId: listing.artisanId,
              listingId: listing.id,
              name: (listing.artisanName?.trim().isNotEmpty ?? false)
                  ? listing.artisanName!.trim()
                  : 'Professional',
              avatarUrl: listing.artisanPhotoUrl,
              location: listing.location,
              minPrice: listing.priceMin,
              categories: {normalizeServiceCategory(listing.category)},
              isVerified: listing.verifiedOnly,
              listingCount: 1,
              ratingAverage: listing.ratingAverage,
              ratingCount: listing.ratingCount,
              wonBidCount: listing.wonBidCount,
              isBusy: listing.artisanBusy,
            );
            continue;
          }
          professionalsById[listing.artisanId] = existing.copyWith(
            location: existing.location.isNotEmpty
                ? existing.location
                : listing.location,
            minPrice: listing.priceMin < existing.minPrice
                ? listing.priceMin
                : existing.minPrice,
            categories: {
              ...existing.categories,
              normalizeServiceCategory(listing.category),
            },
            isVerified: existing.isVerified || listing.verifiedOnly,
            listingCount: existing.listingCount + 1,
            ratingAverage: listing.ratingAverage > existing.ratingAverage
                ? listing.ratingAverage
                : existing.ratingAverage,
            ratingCount: listing.ratingCount > existing.ratingCount
                ? listing.ratingCount
                : existing.ratingCount,
            wonBidCount: listing.wonBidCount > existing.wonBidCount
                ? listing.wonBidCount
                : existing.wonBidCount,
            isBusy: existing.isBusy || listing.artisanBusy,
          );
        }

        final featured = professionalsById.values.toList()
          ..sort((a, b) => b.listingCount.compareTo(a.listingCount));
        final showingAllProfessionals = _showSearchResults &&
            _serviceQuery.isEmpty &&
            _locationQuery.isEmpty &&
            _selectedCategory == null;

        if (_showSearchResults) {
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _clearSearchResults();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _clearSearchResults,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: settings.t('Back'),
                    ),
                    Expanded(
                      child: Text(
                        settings.t('Search results'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                _SearchControls(
                  serviceController: _serviceController,
                  locationController: _locationController,
                  selectedCountry: _selectedCountry,
                  selectedRegion: _selectedRegion,
                  selectedCity: _selectedCity,
                  selectedTown: _selectedTown,
                  countries: _countries,
                  locating: _locating,
                  lookingUpLocation: _locationLookupBusy,
                  loadingLocations: _loadingCountries || _loadingRegions,
                  onCountryChanged: _selectCountry,
                  onRegionChanged: (region) => setState(() {
                    _selectedRegion = region;
                    _selectedCity = null;
                    _selectedTown = null;
                  }),
                  onCityChanged: (city) => setState(() {
                    _selectedCity = city;
                    _selectedTown = null;
                  }),
                  onTownChanged: (town) => setState(() => _selectedTown = town),
                  onSearch: _applySearch,
                  onUseLocation: _usePhoneLocation,
                  settings: settings,
                ),
                const SizedBox(height: 16),
                if (_recentSearches.isNotEmpty) ...[
                  _RecentSearches(
                    searches: _recentSearches,
                    settings: settings,
                    onClear: _clearRecentSearches,
                    onTap: (value) {
                      _serviceController.text = value;
                      _applySearch();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                    showingAllProfessionals
                        ? settings.t('Open service requests')
                        : settings.t('Matching requests'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _OpenJobsPreview(
                  userId: user?.id,
                  query: _serviceQuery,
                  locationQuery: _locationQuery,
                  currencyCode: currencyCode,
                  settings: settings,
                  onLeaveHomeContent: widget.onLeaveHomeContent,
                ),
                const SizedBox(height: 18),
                Text(
                    showingAllProfessionals
                        ? settings.t('All professionals')
                        : settings.t('Matching professionals'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (featured.isEmpty)
                  Text(settings.t('No professionals found.'))
                else
                  ...featured.map((pro) => _ProfessionalCard(
                        pro: pro,
                        currencyCode: currencyCode,
                        settings: settings,
                        onOpenProfile: () {
                          widget.onLeaveHomeContent?.call();
                          context.push(
                            '${RouteNames.artisanProfile}/${pro.artisanId}',
                          );
                        },
                        onBook: () => _bookProfessional(pro),
                      )),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            if (widget.openingBanner != null) ...[
              widget.openingBanner!,
              const SizedBox(height: 12),
            ],
            _SearchControls(
              serviceController: _serviceController,
              locationController: _locationController,
              selectedCountry: _selectedCountry,
              selectedRegion: _selectedRegion,
              selectedCity: _selectedCity,
              selectedTown: _selectedTown,
              countries: _countries,
              locating: _locating,
              lookingUpLocation: _locationLookupBusy,
              loadingLocations: _loadingCountries || _loadingRegions,
              onCountryChanged: _selectCountry,
              onRegionChanged: (region) => setState(() {
                _selectedRegion = region;
                _selectedCity = null;
                _selectedTown = null;
              }),
              onCityChanged: (city) => setState(() {
                _selectedCity = city;
                _selectedTown = null;
              }),
              onTownChanged: (town) => setState(() => _selectedTown = town),
              onSearch: _applySearch,
              onUseLocation: _usePhoneLocation,
              settings: settings,
            ),
            if (_recentSearches.isNotEmpty) ...[
              const SizedBox(height: 12),
              _RecentSearches(
                searches: _recentSearches,
                settings: settings,
                onClear: _clearRecentSearches,
                onTap: (value) {
                  _serviceController.text = value;
                  _applySearch();
                },
              ),
            ],
            if (categoryCards.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                settings.t('Popular Services'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categoryCards.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) {
                  final item = categoryCards[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      _applyCategory(item.name);
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item.icon, color: scheme.primary),
                            const SizedBox(height: 8),
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.count} ${settings.t('pros')}',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    settings.t('Open Service Requests'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: user == null
                      ? () => context.go(RouteNames.auth)
                      : widget.onOpenUploadTab,
                  icon: const Icon(Icons.add),
                  label: Text(settings.t('Post')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _OpenJobsPreview(
              userId: user?.id,
              currencyCode: currencyCode,
              settings: settings,
              onLeaveHomeContent: widget.onLeaveHomeContent,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    settings.t('Latest Artisan Updates'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (listings.isNotEmpty)
                  TextButton(
                    onPressed: () => _showAllArtisanUpdates(
                      listings: listings,
                      settings: settings,
                      userId: user?.id,
                    ),
                    child: Text(settings.t('View All')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (listings.isEmpty)
              Text(settings.t('No artisan updates yet.'))
            else
              ..._sortedArtisanUpdates(
                listings,
                _ArtisanUpdateSort.newest,
              ).take(3).map(
                    (listing) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.campaign_outlined),
                        title: Text(listing.title),
                        subtitle: Text(
                          '${normalizeServiceCategory(listing.category)} - ${listing.location}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: user == null
                            ? () => context.go(RouteNames.auth)
                            : () {
                                widget.onLeaveHomeContent?.call();
                                context.push(
                                  '${RouteNames.listingDetail}/${listing.id}',
                                );
                              },
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    settings.t('Featured Professionals'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _serviceController.clear();
                    _locationController.clear();
                    setState(() {
                      _serviceQuery = '';
                      _locationQuery = '';
                      _selectedCategory = null;
                      _selectedRegion = null;
                      _selectedCity = null;
                      _selectedTown = null;
                      _showSearchResults = true;
                    });
                  },
                  child: Text(settings.t('View All')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (featured.isEmpty)
              Text(settings.t('No professionals found for this search.'))
            else
              ...featured.take(5).map(
                    (pro) => _ProfessionalCard(
                      pro: pro,
                      currencyCode: currencyCode,
                      settings: settings,
                      onOpenProfile: () {
                        widget.onLeaveHomeContent?.call();
                        context.push(
                          '${RouteNames.artisanProfile}/${pro.artisanId}',
                        );
                      },
                      onBook: () => _bookProfessional(pro),
                    ),
                  ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  void _notifyOnNewListing(List<Listing> listings) {
    if (listings.isEmpty) return;
    final latest = listings.first;
    if (!_seenInitialListings) {
      _seenInitialListings = true;
      _latestListingId = latest.id;
      return;
    }
    if (_latestListingId == latest.id) return;
    _latestListingId = latest.id;
    final settings = ref.read(appSettingsControllerProvider);
    if (!settings.phoneNotifications) return;
    NotificationService().showSimpleNotification(
      title: settings.t('New listing'),
      body: latest.title,
    );
  }

  void _showAllArtisanUpdates({
    required List<Listing> listings,
    required AppSettings settings,
    required String? userId,
  }) {
    widget.onLeaveHomeContent?.call();
    final homeContext = context;
    var sort = _ArtisanUpdateSort.newest;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final sorted = _sortedArtisanUpdates(listings, sort);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.86,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            settings.t('Latest Artisan Updates'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: settings.t('Close'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: DropdownButtonFormField<_ArtisanUpdateSort>(
                      initialValue: sort,
                      decoration: InputDecoration(
                        labelText: settings.t('Sort'),
                        prefixIcon: const Icon(Icons.sort),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: _ArtisanUpdateSort.newest,
                          child: Text(settings.t('Newest first')),
                        ),
                        DropdownMenuItem(
                          value: _ArtisanUpdateSort.priceLow,
                          child: Text(settings.t('Lowest price')),
                        ),
                        DropdownMenuItem(
                          value: _ArtisanUpdateSort.priceHigh,
                          child: Text(settings.t('Highest price')),
                        ),
                        DropdownMenuItem(
                          value: _ArtisanUpdateSort.rating,
                          child: Text(settings.t('Highest rated')),
                        ),
                        DropdownMenuItem(
                          value: _ArtisanUpdateSort.category,
                          child: Text(settings.t('Category')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => sort = value);
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final listing = sorted[index];
                        return Card(
                          child: ListTile(
                            leading: listing.images.isEmpty
                                ? const Icon(Icons.campaign_outlined)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      listing.images.first,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.campaign_outlined,
                                      ),
                                    ),
                                  ),
                            title: Text(listing.title),
                            subtitle: Text(
                              '${normalizeServiceCategory(listing.category)} - ${listing.location}\n${formatMoney(listing.priceMin, settings.currencyCode)} - ${listing.ratingAverage.toStringAsFixed(1)}/5',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: userId == null
                                ? () {
                                    Navigator.of(context).pop();
                                    homeContext.go(RouteNames.auth);
                                  }
                                : () {
                                    Navigator.of(context).pop();
                                    homeContext.push(
                                      '${RouteNames.listingDetail}/${listing.id}',
                                    );
                                  },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryPreview {
  const _CategoryPreview(this.name, this.icon, this.count);

  final String name;
  final IconData icon;
  final int count;
}

class _SearchControls extends StatelessWidget {
  const _SearchControls({
    required this.serviceController,
    required this.locationController,
    required this.selectedCountry,
    required this.selectedRegion,
    required this.selectedCity,
    required this.selectedTown,
    required this.countries,
    required this.locating,
    required this.lookingUpLocation,
    required this.loadingLocations,
    required this.onCountryChanged,
    required this.onRegionChanged,
    required this.onCityChanged,
    required this.onTownChanged,
    required this.onSearch,
    required this.onUseLocation,
    required this.settings,
  });

  final TextEditingController serviceController;
  final TextEditingController locationController;
  final CountryOption? selectedCountry;
  final RegionOption? selectedRegion;
  final CityOption? selectedCity;
  final String? selectedTown;
  final List<CountryOption> countries;
  final bool locating;
  final bool lookingUpLocation;
  final bool loadingLocations;
  final ValueChanged<CountryOption?> onCountryChanged;
  final ValueChanged<RegionOption?> onRegionChanged;
  final ValueChanged<CityOption?> onCityChanged;
  final ValueChanged<String?> onTownChanged;
  final VoidCallback onSearch;
  final VoidCallback onUseLocation;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final regions = selectedCountry?.regions ?? const <RegionOption>[];
    final cities = selectedRegion?.cities ?? const <CityOption>[];
    final towns = selectedCity?.towns ?? const <String>[];
    return Column(
      children: [
        TextField(
          controller: serviceController,
          onSubmitted: (_) => onSearch(),
          decoration: InputDecoration(
            hintText: settings.t('What service or job do you need?'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: locationController,
          onSubmitted: (_) => onSearch(),
          decoration: InputDecoration(
            hintText: settings.t('Type location, street, or area'),
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: IconButton(
              onPressed: locating || lookingUpLocation ? null : onUseLocation,
              icon: locating || lookingUpLocation
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              tooltip: settings.t('Use phone location'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PickerField(
                label: settings.t('Country'),
                value: selectedCountry?.name ?? settings.t('Any'),
                onTap: () async {
                  final selected = await _pickOption<CountryOption?>(
                    context,
                    title: settings.t('Country'),
                    options: <CountryOption?>[null, ...countries],
                    labelFor: (country) => country?.name ?? settings.t('Any'),
                    settings: settings,
                  );
                  if (selected != null) onCountryChanged(selected.value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PickerField(
                label: settings.t('Region'),
                value: loadingLocations
                    ? settings.t('Loading...')
                    : selectedRegion?.name ?? settings.t('Any'),
                onTap: loadingLocations
                    ? () {}
                    : () async {
                        final selected = await _pickOption<RegionOption?>(
                          context,
                          title: settings.t('Region'),
                          options: <RegionOption?>[
                            null,
                            ...regions,
                          ],
                          labelFor: (region) =>
                              region?.name ?? settings.t('Any'),
                          customOptionForQuery: selectedCountry == null
                              ? null
                              : (value) => RegionOption(
                                    name: value,
                                    cities: const [],
                                  ),
                          settings: settings,
                        );
                        if (selected != null) onRegionChanged(selected.value);
                      },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PickerField(
                label: settings.t('City'),
                value: selectedCity?.name ?? settings.t('Any'),
                onTap: () async {
                  final selected = await _pickOption<CityOption?>(
                    context,
                    title: settings.t('City'),
                    options: <CityOption?>[null, ...cities],
                    labelFor: (city) => city?.name ?? settings.t('Any'),
                    customOptionForQuery: selectedCountry == null
                        ? null
                        : (value) => CityOption(
                              name: value,
                              towns: townsForLocation(
                                countryCode: selectedCountry!.code,
                                stateName: selectedRegion?.name ?? '',
                                cityName: value,
                              ),
                            ),
                    settings: settings,
                  );
                  if (selected != null) onCityChanged(selected.value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PickerField(
                label: settings.t('Town'),
                value: selectedTown ?? settings.t('Any'),
                onTap: () async {
                  final selected = await _pickOption<String?>(
                    context,
                    title: settings.t('Town'),
                    options: <String?>[null, ...towns],
                    labelFor: (town) => town ?? settings.t('Any'),
                    customOptionForQuery:
                        selectedCountry == null ? null : (value) => value,
                    settings: settings,
                  );
                  if (selected != null) onTownChanged(selected.value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
            ),
            onPressed: onSearch,
            child: Text(settings.t('Search')),
          ),
        ),
      ],
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.searches,
    required this.onTap,
    required this.onClear,
    required this.settings,
  });

  final List<String> searches;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                settings.t('Recent searches'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all, size: 18),
              label: Text(settings.t('Clear all')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: searches
              .map(
                (search) => ActionChip(
                  avatar: const Icon(Icons.history, size: 16),
                  label: Text(search),
                  onPressed: () => onTap(search),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _PickerResult<T> {
  const _PickerResult(this.value);

  final T value;
}

Future<_PickerResult<T>?> _pickOption<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T option) labelFor,
  required AppSettings settings,
  T Function(String query)? customOptionForQuery,
}) {
  String query = '';
  return showModalBottomSheet<_PickerResult<T>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            child: Builder(
              builder: (context) {
                final filtered = query.isEmpty
                    ? options
                    : options
                        .where((option) => labelFor(option)
                            .toLowerCase()
                            .contains(query.toLowerCase()))
                        .toList(growable: false);
                final normalizedQuery = query.toLowerCase();
                final hasExactMatch = normalizedQuery.isEmpty ||
                    filtered.any(
                      (option) =>
                          labelFor(option).toLowerCase() == normalizedQuery,
                    );
                final hasCustomOption =
                    customOptionForQuery != null && !hasExactMatch;
                final customOffset = hasCustomOption ? 1 : 0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            tooltip: settings.t('Close'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '${settings.t('Search')} $title',
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (value) =>
                            setSheetState(() => query = value.trim()),
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length + customOffset,
                        itemBuilder: (context, index) {
                          if (hasCustomOption && index == 0) {
                            final option = customOptionForQuery(query);
                            return ListTile(
                              leading:
                                  const Icon(Icons.add_location_alt_outlined),
                              title: Text('${settings.t('Use')} "$query"'),
                              onTap: () => Navigator.of(context)
                                  .pop(_PickerResult(option)),
                            );
                          }
                          final option = filtered[index - customOffset];
                          return ListTile(
                            title: Text(labelFor(option)),
                            onTap: () => Navigator.of(context)
                                .pop(_PickerResult(option)),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

class _OpenJobsPreview extends ConsumerWidget {
  const _OpenJobsPreview({
    required this.userId,
    required this.currencyCode,
    required this.settings,
    this.query = '',
    this.locationQuery = '',
    this.onLeaveHomeContent,
  });

  final String? userId;
  final String currencyCode;
  final AppSettings settings;
  final String query;
  final String locationQuery;
  final VoidCallback? onLeaveHomeContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsStreamProvider);
    return jobsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Text(
        settings.t(
          'Could not load service requests. Please check your connection and try again.',
        ),
      ),
      data: (jobs) {
        final filtered = jobs.where((job) {
          final jobText = '${job.title} ${job.description}'.toLowerCase();
          final locationText = job.location.toLowerCase();
          final queryMatches = query.isEmpty || fuzzyContains(jobText, query);
          final locationMatches = locationQuery.isEmpty ||
              _matchesLocation(locationText, locationQuery);
          return queryMatches && locationMatches;
        }).toList(growable: false);
        if (filtered.isEmpty) {
          return Text(settings.t('No service requests posted yet.'));
        }
        return Column(
          children: filtered.take(8).map((job) {
            final shownAmount = job.acceptedAmount ?? job.budget;
            final amountLabel = job.acceptedAmount == null
                ? settings.t('Budget')
                : settings.t('Accepted amount');
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(job.title),
                subtitle: Text(
                  '${job.location} - $amountLabel: ${formatMoney(shownAmount, currencyCode)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: userId == null
                    ? () => context.go(RouteNames.auth)
                    : () {
                        onLeaveHomeContent?.call();
                        context.push('${RouteNames.jobDetail}/${job.id}');
                      },
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({
    required this.pro,
    required this.currencyCode,
    required this.settings,
    required this.onOpenProfile,
    required this.onBook,
  });

  final _ProfessionalPreview pro;
  final String currencyCode;
  final AppSettings settings;
  final VoidCallback onOpenProfile;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unavailableColor = Colors.red.shade700;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpenProfile,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    foregroundImage: (pro.avatarUrl?.isNotEmpty ?? false)
                        ? NetworkImage(pro.avatarUrl!)
                        : null,
                    onForegroundImageError: (pro.avatarUrl?.isNotEmpty ?? false)
                        ? (_, __) {}
                        : null,
                    child: Text(
                      (pro.name.trim().isNotEmpty ? pro.name.trim()[0] : 'P')
                          .toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pro.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (pro.isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified,
                                        size: 14, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      settings.t('Verified'),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pro.location,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pro.listingCount} ${settings.t(pro.listingCount == 1 ? 'active service' : 'active services')}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pro.ratingAverage.toStringAsFixed(1)}/5 (${pro.ratingCount}) - ${pro.wonBidCount} ${settings.t('won bids')}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        if (pro.isBusy) ...[
                          const SizedBox(height: 4),
                          Text(
                            settings.t('Unavailable'),
                            style: TextStyle(
                              color: unavailableColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: pro.categories
                    .where((item) => item.trim().isNotEmpty)
                    .take(3)
                    .map((item) => Chip(label: Text(item)))
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              Text(
                '${settings.t('From')} ${formatMoney(pro.minPrice, currencyCode)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.account_circle_outlined, size: 18),
                label: Text(
                  pro.ratingCount > 0
                      ? '${settings.t('Profile')} & ${pro.ratingCount} ${settings.t(pro.ratingCount == 1 ? 'comment' : 'comments')}'
                      : settings.t('View profile & comments'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: pro.isBusy ? null : onBook,
                  icon: Icon(
                    pro.isBusy ? Icons.block : Icons.request_quote_outlined,
                    size: 18,
                  ),
                  style: pro.isBusy
                      ? FilledButton.styleFrom(
                          backgroundColor: unavailableColor,
                        )
                      : null,
                  label: Text(settings.t(pro.isBusy ? 'Busy' : 'Book Now')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfessionalPreview {
  const _ProfessionalPreview({
    required this.artisanId,
    required this.listingId,
    required this.name,
    required this.avatarUrl,
    required this.location,
    required this.minPrice,
    required this.categories,
    required this.isVerified,
    required this.listingCount,
    required this.ratingAverage,
    required this.ratingCount,
    required this.wonBidCount,
    required this.isBusy,
  });

  final String artisanId;
  final String listingId;
  final String name;
  final String? avatarUrl;
  final String location;
  final double minPrice;
  final Set<String> categories;
  final bool isVerified;
  final int listingCount;
  final double ratingAverage;
  final int ratingCount;
  final int wonBidCount;
  final bool isBusy;

  _ProfessionalPreview copyWith({
    String? location,
    double? minPrice,
    Set<String>? categories,
    bool? isVerified,
    int? listingCount,
    double? ratingAverage,
    int? ratingCount,
    int? wonBidCount,
    bool? isBusy,
  }) {
    return _ProfessionalPreview(
      artisanId: artisanId,
      listingId: listingId,
      name: name,
      avatarUrl: avatarUrl,
      location: location ?? this.location,
      minPrice: minPrice ?? this.minPrice,
      categories: categories ?? this.categories,
      isVerified: isVerified ?? this.isVerified,
      listingCount: listingCount ?? this.listingCount,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      ratingCount: ratingCount ?? this.ratingCount,
      wonBidCount: wonBidCount ?? this.wonBidCount,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}
