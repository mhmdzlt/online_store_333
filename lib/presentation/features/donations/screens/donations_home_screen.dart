import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/models/freebies/freebie_model.dart';
import '../../../../data/repositories/freebies_repository.dart';
import '../../../../core/services/location_service.dart';
import '../../../../utils/image_resolvers.dart';
import '../../../../utils/local_storage.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';
import 'package:design_system/design_system.dart';

class DonationsHomeScreen extends StatefulWidget {
  const DonationsHomeScreen({super.key});

  @override
  State<DonationsHomeScreen> createState() => _DonationsHomeScreenState();
}

class _DonationsHomeScreenState extends State<DonationsHomeScreen>
    with WidgetsBindingObserver {
  String? _city;
  late final FreebiesRepository _freebiesRepository;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _categoryFilter = 'all';
  String _sortOrder = 'latest';
  bool _nearbyOnly = false;
  double _nearbyRadiusKm = 10;
  bool _loadingNearby = false;
  double? _userLat;
  double? _userLng;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _freebiesRepository = context.read<FreebiesRepository>();
    _loadStoredLocation();
    _loadStoredRadius();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
        _clearSearch();
      }
    });
  }

  Future<void> _loadStoredLocation() async {
    final stored = await LocalStorage.getUserLocation();
    if (!mounted || stored == null) return;
    setState(() {
      _userLat = stored['lat'];
      _userLng = stored['lng'];
    });
  }

  Future<void> _loadStoredRadius() async {
    final stored = await LocalStorage.getNearbyRadius();
    if (!mounted || stored == null) return;
    final value = stored.clamp(5, 50).toDouble();
    setState(() {
      _nearbyRadiusKm = value;
    });
  }

  Future<void> _enableNearby() async {
    setState(() => _loadingNearby = true);
    try {
      final outcome = await LocationService.getCurrentLocationOutcome();
      if (!mounted) return;
      if (!outcome.isSuccess) {
        final reason = outcome.failure ?? LocationFailureReason.unavailable;
        final message = switch (reason) {
          LocationFailureReason.serviceDisabled => context.tr(
              ar: 'خدمة الموقع متوقفة. فعّل GPS ثم حاول مرة أخرى.',
              en: 'Location service is off. Turn on GPS and try again.',
              ckb:
                  'خزمەتگوزاری شوێن ناچالاکە. GPS چالاک بکە و دووبارە هەوڵبدەوە.',
              ku: 'Xizmeta cihê neçalak e. GPS çalak bike û dîsa biceribîne.',
            ),
          LocationFailureReason.permissionDenied ||
          LocationFailureReason.permissionDeniedForever =>
            context.tr(
              ar: 'صلاحية الموقع مرفوضة. اسمح للتطبيق بالوصول للموقع من الإعدادات.',
              en: 'Location permission is denied. Allow location access from settings.',
              ckb:
                  'دەسەڵاتی شوێن ڕەتکرایەوە. لە ڕێکخستنەکان ڕێگە بدە بە ئەپ بگات بە شوێن.',
              ku: 'Destûra cihê red bûye. Di mîhengan de destûr bide appê.',
            ),
          LocationFailureReason.unavailable => context.tr(
              ar: 'تعذر تحديد الموقع حالياً. حاول مرة أخرى.',
              en: 'Unable to determine location right now. Please try again.',
              ckb: 'ئێستا شوێن دیاری ناکرێت. تکایە دووبارە هەوڵبدەوە.',
              ku: 'Niha cih nayê diyarkirin. Ji kerema xwe dîsa biceribîne.',
            ),
        };

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: reason == LocationFailureReason.unavailable
                ? null
                : SnackBarAction(
                    label: context.tr(
                      ar: 'الإعدادات',
                      en: 'Settings',
                      ckb: 'ڕێکخستنەکان',
                      ku: 'Mîheng',
                    ),
                    onPressed: () {
                      LocationService.openRelevantSettings(reason);
                    },
                  ),
          ),
        );
        return;
      }

      final result = outcome.result!;
      await LocalStorage.saveUserLocation(
        latitude: result.latitude,
        longitude: result.longitude,
      );
      setState(() {
        _nearbyOnly = true;
        _sortOrder = 'nearest';
        _userLat = result.latitude;
        _userLng = result.longitude;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingNearby = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final isVisible = bottomInset > 0.0;
    if (_keyboardVisible && !isVisible && _searchQuery.isNotEmpty) {
      _clearSearch();
    }
    _keyboardVisible = isVisible;
  }

  Widget _buildSearchField() {
    return AppSearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: context.tr(
        ar: 'ابحث عن هبة...',
        en: 'Search donations...',
        ckb: 'بەخشین بگەڕێ...',
        ku: 'Li bexşînan bigere...',
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
      onClear: _clearSearch,
      onFilterTap: _openFilterBottomSheet,
      showFilter: true,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _resetFilters() {
    setState(() {
      _statusFilter = 'all';
      _categoryFilter = 'all';
      _sortOrder = 'latest';
      _nearbyOnly = false;
    });
  }

  bool get _hasActiveFilters {
    final hasQuery = _searchQuery.trim().isNotEmpty;
    final hasStatus = _statusFilter != 'all';
    final hasCategory = _categoryFilter != 'all';
    return hasQuery || hasStatus || hasCategory || _nearbyOnly;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(
          ar: 'الهبات المجانية',
          en: 'Free donations',
          ckb: 'بەخشینە بەخۆڕایییەکان',
          ku: 'Bexşînên belaş',
        )),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          NavigationHelpers.push(context, RouteNames.donateItem);
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr(
          ar: 'تبرع بهبة',
          en: 'Donate item',
          ckb: 'بەخشینی شتێک',
          ku: 'Tiştek bexşîne',
        )),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          _buildCityFilter(context),
          const SizedBox(height: 12),
          _buildNearbyFilter(),
          const SizedBox(height: 12),
          _buildCategoryChips(),
          const SizedBox(height: 12),
          _buildStatusChips(),
          const SizedBox(height: 12),
          _buildSortRow(),
          const SizedBox(height: 12),
          _buildDonationsList(),
        ],
      ),
    );
  }

  Widget _buildCityFilter(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await _showCityPicker();
        if (selected == null) return;
        setState(() => _city = selected);
      },
      icon: const Icon(Icons.location_city_outlined),
      label: Text(_city == null
          ? context.tr(
              ar: 'اختر المدينة',
              en: 'Choose city',
              ckb: 'شار هەڵبژێرە',
              ku: 'Bajar hilbijêre',
            )
          : '${context.tr(ar: 'المدينة', en: 'City', ckb: 'شار', ku: 'Bajar')}: $_city'),
    );
  }

  Future<String?> _showCityPicker() async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        return ListView(
          children: [
            ListTile(
              title: Text(context.tr(
                ar: 'كل المدن',
                en: 'All cities',
                ckb: 'هەموو شارەکان',
                ku: 'Hemû bajar',
              )),
              onTap: () => NavigationHelpers.pop(context, null),
            ),
            const Divider(),
            ...['بغداد', 'البصرة', 'أربيل', 'النجف', 'كربلاء'].map(
              (city) => ListTile(
                title: Text(city),
                onTap: () => NavigationHelpers.pop(context, city),
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildStatusChips() {
    final options = [
      {
        'label': context.tr(ar: 'الكل', en: 'All', ckb: 'هەموو', ku: 'Hemû'),
        'value': 'all'
      },
      {
        'label': context.tr(
            ar: 'متاح', en: 'Available', ckb: 'بەردەست', ku: 'Berdest'),
        'value': 'available'
      },
      {
        'label': context.tr(
            ar: 'محجوز', en: 'Reserved', ckb: 'پارێزراو', ku: 'Rezerv kirî'),
        'value': 'reserved'
      },
      {
        'label': context.tr(
            ar: 'تم التسليم', en: 'Completed', ckb: 'تەواوبوو', ku: 'Temam bû'),
        'value': 'completed'
      },
    ];

    return Wrap(
      spacing: 8,
      children: options.map((option) {
        final value = option['value'];
        return ChoiceChip(
          label: Text(option['label']!),
          selected: _statusFilter == value,
          onSelected: (_) {
            setState(() => _statusFilter = value!);
          },
        );
      }).toList(),
    );
  }

  Widget _buildCategoryChips() {
    final options = [
      {
        'value': 'all',
        'label': context.tr(ar: 'الكل', en: 'All', ckb: 'هەموو', ku: 'Hemû'),
      },
      {
        'value': 'furniture',
        'label': context.tr(
          ar: 'أثاث',
          en: 'Furniture',
          ckb: 'کەلوپەلی ماڵ',
          ku: 'Mobîlya',
        ),
      },
      {
        'value': 'electronics',
        'label': context.tr(
          ar: 'إلكترونيات',
          en: 'Electronics',
          ckb: 'ئەلیکترۆنیات',
          ku: 'Elektronîk',
        ),
      },
      {
        'value': 'books',
        'label': context.tr(ar: 'كتب', en: 'Books', ckb: 'کتێب', ku: 'Pirtûk'),
      },
      {
        'value': 'food',
        'label':
            context.tr(ar: 'طعام', en: 'Food', ckb: 'خواردن', ku: 'Xwarin'),
      },
      {
        'value': 'clothes',
        'label': context.tr(
          ar: 'ملابس',
          en: 'Clothes',
          ckb: 'جلوبەرگ',
          ku: 'Kinc',
        ),
      },
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options.map((option) {
        final value = option['value']!;
        return ChoiceChip(
          label: Text(option['label']!),
          selected: _categoryFilter == value,
          onSelected: (_) {
            setState(() => _categoryFilter = value);
          },
        );
      }).toList(),
    );
  }

  Widget _buildSortRow() {
    return Row(
      children: [
        Text(context.tr(
          ar: 'الترتيب:',
          en: 'Sort:',
          ckb: 'ڕیزبەندی:',
          ku: 'Rêzkirin:',
        )),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _sortOrder,
          items: [
            if (_nearbyOnly)
              DropdownMenuItem(
                  value: 'nearest',
                  child: Text(context.tr(
                    ar: 'الأقرب',
                    en: 'Nearest',
                    ckb: 'نزیکترین',
                    ku: 'Nêziktirîn',
                  ))),
            DropdownMenuItem(
                value: 'latest',
                child: Text(context.tr(
                  ar: 'الأحدث',
                  en: 'Newest',
                  ckb: 'نوێترین',
                  ku: 'Nûtirîn',
                ))),
            DropdownMenuItem(
                value: 'oldest',
                child: Text(context.tr(
                  ar: 'الأقدم',
                  en: 'Oldest',
                  ckb: 'کۆنترین',
                  ku: 'Kevintirîn',
                ))),
            DropdownMenuItem(
                value: 'title',
                child: Text(context.tr(
                  ar: 'العنوان',
                  en: 'Title',
                  ckb: 'ناونیشان',
                  ku: 'Sernav',
                ))),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _sortOrder = value);
          },
        ),
        const Spacer(),
        if (_hasActiveFilters)
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh),
            label: Text(context.tr(
              ar: 'إعادة تعيين',
              en: 'Reset',
              ckb: 'ڕیسێت',
              ku: 'Reset',
            )),
          ),
      ],
    );
  }

  Widget _buildNearbyFilter() {
    final hasLocation = _userLat != null && _userLng != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loadingNearby
                    ? null
                    : (_nearbyOnly
                        ? () => setState(() => _nearbyOnly = false)
                        : _enableNearby),
                icon: _loadingNearby
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.near_me_outlined),
                label: Text(
                  _nearbyOnly
                      ? context.tr(
                          ar: 'إيقاف القريب مني',
                          en: 'Disable nearby',
                          ckb: 'نزیک لە من ناچالاک بکە',
                          ku: 'Nêzî min neçalak bike',
                        )
                      : context.tr(
                          ar: 'عرض الهبات القريبة',
                          en: 'Show nearby donations',
                          ckb: 'بەخشینە نزیکەکان پیشان بدە',
                          ku: 'Bexşînên nêzîk nîşan bide',
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<double>(
              value: _nearbyRadiusKm,
              items: [
                DropdownMenuItem(
                    value: 5,
                    child: Text(context.tr(
                        ar: '5 كم', en: '5 km', ckb: '5 کم', ku: '5 km'))),
                DropdownMenuItem(
                    value: 10,
                    child: Text(context.tr(
                        ar: '10 كم', en: '10 km', ckb: '10 کم', ku: '10 km'))),
                DropdownMenuItem(
                    value: 25,
                    child: Text(context.tr(
                        ar: '25 كم', en: '25 km', ckb: '25 کم', ku: '25 km'))),
                DropdownMenuItem(
                    value: 50,
                    child: Text(context.tr(
                        ar: '50 كم', en: '50 km', ckb: '50 کم', ku: '50 km'))),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _nearbyRadiusKm = value);
                LocalStorage.saveNearbyRadius(value);
              },
            ),
          ],
        ),
        if (_nearbyOnly)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Text(context.tr(
                  ar: 'النطاق:',
                  en: 'Range:',
                  ckb: 'مەودا:',
                  ku: 'Menzîl:',
                )),
                Expanded(
                  child: Slider(
                    min: 5,
                    max: 50,
                    divisions: 9,
                    value: _nearbyRadiusKm.clamp(5, 50),
                    label:
                        '${_nearbyRadiusKm.toInt()} ${context.tr(ar: 'كم', en: 'km', ckb: 'کم', ku: 'km')}',
                    onChanged: (value) {
                      setState(() => _nearbyRadiusKm = value);
                      LocalStorage.saveNearbyRadius(value);
                    },
                  ),
                ),
                Text(
                    '${_nearbyRadiusKm.toInt()} ${context.tr(ar: 'كم', en: 'km', ckb: 'کم', ku: 'km')}'),
              ],
            ),
          ),
        if (_nearbyOnly && !hasLocation)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              context.tr(
                ar: 'فعّل الموقع لعرض الهبات القريبة.',
                en: 'Enable location to show nearby donations.',
                ckb: 'شوێن چالاک بکە بۆ پیشاندانی بەخشینە نزیکەکان.',
                ku: 'Ji bo nîşandana bexşînên nêzîk cihê xwe çalak bike.',
              ),
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildDonationsList() {
    final statusFilter = _statusFilter == 'all' ? '' : _statusFilter;
    final useNearby = _nearbyOnly && _userLat != null && _userLng != null;
    return FutureBuilder<List<FreebieModel>>(
      future: (useNearby
              ? _freebiesRepository.fetchNearbyDonations(
                  latitude: _userLat!,
                  longitude: _userLng!,
                  radiusKm: _nearbyRadiusKm,
                  city: _city,
                  status: statusFilter,
                )
              : _freebiesRepository.fetchDonations(
                  city: _city,
                  status: statusFilter,
                ))
          .then(
        (rows) => rows.map(FreebieModel.fromMap).toList(growable: false),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading();
        }

        if (snapshot.hasError) {
          return AppEmptyState(
            message: context.tr(
              ar: 'تعذر الاتصال بالإنترنت أو بالخادم حالياً. حاول مرة أخرى لاحقاً.',
              en: 'Unable to connect to the internet or server right now. Please try again later.',
              ckb:
                  'ناتوانرێت پەیوەندی بە ئینتەرنێت یان سێرڤەر بکرێت لە ئێستادا. تکایە دواتر هەوڵبدەوە.',
              ku: 'Niha girêdana internetê an serverê nehat kirin. Ji kerema xwe paşê dîsa biceribîne.',
            ),
          );
        }

        final data = snapshot.data ?? [];
        final nearbyFiltered = _applyNearbyFilter(data);
        final query = _searchQuery.trim().toLowerCase();
        final filtered = nearbyFiltered.where((d) {
          final title = d.title.toLowerCase();
          final description = d.description.toLowerCase();
          final matchesQuery = query.isEmpty || title.contains(query);
          final status = d.status.isNotEmpty ? d.status : 'available';
          final matchesStatus =
              _statusFilter == 'all' || status == _statusFilter;
          final categoryKey =
              _resolveDonationCategoryKey(d, title, description);
          final matchesCategory =
              _categoryFilter == 'all' || categoryKey == _categoryFilter;
          return matchesQuery && matchesStatus && matchesCategory;
        }).toList();

        if (_sortOrder == 'nearest') {
          filtered.sort((a, b) {
            final aDistance = _distanceMetersFor(a) ?? double.infinity;
            final bDistance = _distanceMetersFor(b) ?? double.infinity;
            return aDistance.compareTo(bDistance);
          });
        } else if (_sortOrder == 'oldest') {
          filtered.sort((a, b) {
            final aDate = a.createdAt ?? DateTime(1970);
            final bDate = b.createdAt ?? DateTime(1970);
            return aDate.compareTo(bDate);
          });
        } else if (_sortOrder == 'title') {
          filtered.sort((a, b) {
            final aTitle = a.title;
            final bTitle = b.title;
            return aTitle.compareTo(bTitle);
          });
        } else {
          filtered.sort((a, b) {
            final aDate = a.createdAt ?? DateTime(1970);
            final bDate = b.createdAt ?? DateTime(1970);
            return bDate.compareTo(aDate);
          });
        }

        if (filtered.isEmpty) {
          if (_nearbyOnly) {
            final hasCoords =
                data.any((d) => d.latitude != null && d.longitude != null);
            if (_userLat == null || _userLng == null) {
              return AppEmptyState(
                message: context.tr(
                  ar: 'يرجى تفعيل الموقع لعرض الهبات القريبة',
                  en: 'Please enable location to show nearby donations',
                  ckb: 'تکایە شوێن چالاک بکە بۆ پیشاندانی بەخشینە نزیکەکان',
                  ku: 'Ji kerema xwe cihê xwe çalak bike da ku bexşînên nêzîk nîşan bide',
                ),
              );
            }
            if (!hasCoords) {
              return AppEmptyState(
                message: context.tr(
                  ar: 'الهبات الحالية لا تحتوي على مواقع بعد',
                  en: 'Current donations do not have locations yet',
                  ckb: 'بەخشینەکانی ئێستا هێشتا شوێنیان نییە',
                  ku: 'Bexşînên niha hêj cih nînin',
                ),
              );
            }
            if (nearbyFiltered.isEmpty) {
              return AppEmptyState(
                message: context.tr(
                  ar: 'لا توجد هبات ضمن ${_nearbyRadiusKm.toInt()} كم حالياً',
                  en: 'No donations within ${_nearbyRadiusKm.toInt()} km right now',
                  ckb:
                      'لە ئێستادا هیچ بەخشینێک لە ناو ${_nearbyRadiusKm.toInt()} کم نییە',
                  ku: 'Niha tu bexşîn di nav ${_nearbyRadiusKm.toInt()} km de tune ye',
                ),
              );
            }
          }
          return AppEmptyState(
              message: context.tr(
            ar: 'لا توجد هبات متاحة',
            en: 'No donations available',
            ckb: 'هیچ بەخشینێک بەردەست نییە',
            ku: 'Tu bexşînê berdest tune ye',
          ));
        }

        return Column(
          children: filtered.map((donation) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  NavigationHelpers.goToFreebieDetail(
                    context,
                    donation.id,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _DonationListCard(
                    donation: donation,
                    statusLabel: _statusLabel(donation.status),
                    conditionLabel: _conditionLabel(donation),
                    categoryLabel:
                        _categoryLabel(_resolveDonationCategoryKey(donation)),
                    distanceLabel: _distanceLabelFor(donation),
                    timeAgoLabel: _timeAgoLabel(donation.createdAt),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _resolveDonationCategoryKey(
    FreebieModel donation, [
    String? title,
    String? description,
  ]) {
    final rawCategory = (donation.raw['category'] ??
            donation.raw['item_category'] ??
            donation.raw['donation_category'] ??
            donation.raw['type'])
        ?.toString()
        .toLowerCase()
        .trim();

    if (rawCategory != null && rawCategory.isNotEmpty) {
      if (rawCategory.contains('furniture') ||
          rawCategory.contains('اثاث') ||
          rawCategory.contains('أثاث')) {
        return 'furniture';
      }
      if (rawCategory.contains('elect') ||
          rawCategory.contains('الكتر') ||
          rawCategory.contains('إلكتر')) {
        return 'electronics';
      }
      if (rawCategory.contains('book') || rawCategory.contains('كتاب')) {
        return 'books';
      }
      if (rawCategory.contains('food') || rawCategory.contains('طعام')) {
        return 'food';
      }
      if (rawCategory.contains('cloth') ||
          rawCategory.contains('ملابس') ||
          rawCategory.contains('لبس')) {
        return 'clothes';
      }
    }

    final text =
        '${title ?? donation.title} ${description ?? donation.description}'
            .toLowerCase();

    if (text.contains('كرسي') ||
        text.contains('طاولة') ||
        text.contains('خزانة') ||
        text.contains('سرير') ||
        text.contains('sofa') ||
        text.contains('chair') ||
        text.contains('table') ||
        text.contains('furniture')) {
      return 'furniture';
    }
    if (text.contains('موبايل') ||
        text.contains('هاتف') ||
        text.contains('لابتوب') ||
        text.contains('حاسوب') ||
        text.contains('تلفاز') ||
        text.contains('phone') ||
        text.contains('laptop') ||
        text.contains('tv')) {
      return 'electronics';
    }
    if (text.contains('كتاب') || text.contains('book')) return 'books';
    if (text.contains('طعام') ||
        text.contains('اكل') ||
        text.contains('food')) {
      return 'food';
    }
    if (text.contains('ملابس') ||
        text.contains('قميص') ||
        text.contains('بنطال') ||
        text.contains('jacket') ||
        text.contains('clothes')) {
      return 'clothes';
    }
    return 'all';
  }

  String _categoryLabel(String key) {
    switch (key) {
      case 'furniture':
        return context.tr(
            ar: 'أثاث', en: 'Furniture', ckb: 'کەلوپەلی ماڵ', ku: 'Mobîlya');
      case 'electronics':
        return context.tr(
            ar: 'إلكترونيات',
            en: 'Electronics',
            ckb: 'ئەلیکترۆنیات',
            ku: 'Elektronîk');
      case 'books':
        return context.tr(ar: 'كتب', en: 'Books', ckb: 'کتێب', ku: 'Pirtûk');
      case 'food':
        return context.tr(ar: 'طعام', en: 'Food', ckb: 'خواردن', ku: 'Xwarin');
      case 'clothes':
        return context.tr(
            ar: 'ملابس', en: 'Clothes', ckb: 'جلوبەرگ', ku: 'Kinc');
      default:
        return context.tr(ar: 'أخرى', en: 'Other', ckb: 'هی تر', ku: 'Yên din');
    }
  }

  String _statusLabel(String status) {
    final value = status.trim().toLowerCase();
    switch (value) {
      case 'reserved':
        return context.tr(
            ar: 'محجوز', en: 'Reserved', ckb: 'پارێزراو', ku: 'Rezerv kirî');
      case 'completed':
      case 'in_progress':
        return context.tr(
            ar: 'تم التسليم', en: 'Completed', ckb: 'تەواوبوو', ku: 'Temam bû');
      case 'available':
      default:
        return context.tr(
            ar: 'متاح', en: 'Available', ckb: 'بەردەست', ku: 'Berdest');
    }
  }

  String _conditionLabel(FreebieModel donation) {
    final value = (donation.raw['condition'] ??
            donation.raw['item_condition'] ??
            donation.raw['quality'])
        ?.toString()
        .toLowerCase()
        .trim();

    if (value == null || value.isEmpty) {
      return context.tr(
        ar: 'مستعمل بحالة جيدة',
        en: 'Used in good condition',
        ckb: 'بەکارهاتوو بە دۆخی باش',
        ku: 'Bikaranîna baş',
      );
    }

    if (value.contains('new') || value.contains('جديد')) {
      return context.tr(ar: 'جديد', en: 'New', ckb: 'نوێ', ku: 'Nû');
    }
    if (value.contains('repair') ||
        value.contains('needs') ||
        value.contains('صيانة') ||
        value.contains('تصليح')) {
      return context.tr(
        ar: 'يحتاج صيانة',
        en: 'Needs repair',
        ckb: 'پێویستی بە چاککردنەوە هەیە',
        ku: 'Pêdivî bi tamîrê heye',
      );
    }

    return context.tr(
      ar: 'مستعمل بحالة جيدة',
      en: 'Used in good condition',
      ckb: 'بەکارهاتوو بە دۆخی باش',
      ku: 'Bikaranîna baş',
    );
  }

  String _timeAgoLabel(DateTime? createdAt) {
    if (createdAt == null) {
      return context.tr(
        ar: 'منذ قليل',
        en: 'Just now',
        ckb: 'ئێستا',
        ku: 'Niha',
      );
    }

    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) {
      return context.tr(ar: 'الآن', en: 'Now', ckb: 'ئێستا', ku: 'Niha');
    }
    if (diff.inMinutes < 60) {
      return context.tr(
        ar: 'منذ ${diff.inMinutes} دقيقة',
        en: '${diff.inMinutes} min ago',
        ckb: 'لە پێش ${diff.inMinutes} خولەک',
        ku: '${diff.inMinutes} deqîqe berê',
      );
    }
    if (diff.inHours < 24) {
      return context.tr(
        ar: 'منذ ${diff.inHours} ساعة',
        en: '${diff.inHours} h ago',
        ckb: 'لە پێش ${diff.inHours} کاتژمێر',
        ku: '${diff.inHours} saet berê',
      );
    }
    return context.tr(
      ar: 'منذ ${diff.inDays} يوم',
      en: '${diff.inDays} d ago',
      ckb: 'لە پێش ${diff.inDays} ڕۆژ',
      ku: '${diff.inDays} roj berê',
    );
  }

  String? _distanceLabelFor(FreebieModel donation) {
    if (_userLat == null || _userLng == null) return null;
    final lat = donation.latitude;
    final lng = donation.longitude;
    if (lat == null || lng == null) return null;
    final meters = Geolocator.distanceBetween(
      _userLat!,
      _userLng!,
      lat,
      lng,
    );
    final km = meters / 1000;
    final value = km >= 1
        ? double.parse(km.toStringAsFixed(1))
        : double.parse((meters).toStringAsFixed(0));
    final unit = km >= 1
        ? context.tr(ar: 'كم', en: 'km', ckb: 'کم', ku: 'km')
        : context.tr(ar: 'م', en: 'm', ckb: 'م', ku: 'm');
    return '$value $unit';
  }

  double? _distanceMetersFor(FreebieModel donation) {
    if (_userLat == null || _userLng == null) return null;
    final lat = donation.latitude;
    final lng = donation.longitude;
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
      _userLat!,
      _userLng!,
      lat,
      lng,
    );
  }

  List<FreebieModel> _applyNearbyFilter(List<FreebieModel> data) {
    if (!_nearbyOnly) return data;
    if (_userLat == null || _userLng == null) return const [];

    final maxDistanceMeters = _nearbyRadiusKm * 1000;
    return data.where((donation) {
      final lat = donation.latitude;
      final lng = donation.longitude;
      if (lat == null || lng == null) return false;
      final distance = Geolocator.distanceBetween(
        _userLat!,
        _userLng!,
        lat,
        lng,
      );
      return distance <= maxDistanceMeters;
    }).toList();
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(
                  ar: 'خيارات التصفية',
                  en: 'Filter options',
                  ckb: 'هەڵبژاردەکانی فلتەر',
                  ku: 'Vebijarkên fîlterê',
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildStatusChips(),
              const SizedBox(height: 12),
              _buildCategoryChips(),
              const SizedBox(height: 12),
              _buildSortRow(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => NavigationHelpers.pop(context),
                  child: Text(context.tr(
                    ar: 'تم',
                    en: 'Done',
                    ckb: 'تەواو',
                    ku: 'Temam',
                  )),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class _DonationListCard extends StatelessWidget {
  const _DonationListCard({
    required this.donation,
    required this.statusLabel,
    required this.conditionLabel,
    required this.categoryLabel,
    required this.timeAgoLabel,
    this.distanceLabel,
  });

  final FreebieModel donation;
  final String statusLabel;
  final String conditionLabel;
  final String categoryLabel;
  final String? distanceLabel;
  final String timeAgoLabel;

  Color _statusBackgroundColor(BuildContext context) {
    final value = donation.status.trim().toLowerCase();
    if (value == 'completed' || value == 'in_progress') {
      return Colors.grey.shade200;
    }
    if (value == 'reserved') {
      return Colors.orange.shade100;
    }
    return Theme.of(context).colorScheme.primaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveDonationImage(donation.imageUrls);
    final locationText = [donation.city.trim(), (donation.area ?? '').trim()]
        .where((value) => value.isNotEmpty)
        .join(' - ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 90,
            height: 90,
            child: imageUrl == null
                ? Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported_outlined),
                  )
                : AppImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    radius: 0,
                    placeholderIcon: Icons.image_not_supported_outlined,
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                donation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              if (locationText.isNotEmpty)
                Text(
                  locationText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Badge(
                    label: statusLabel,
                    backgroundColor: _statusBackgroundColor(context),
                  ),
                  _Badge(label: conditionLabel),
                  _Badge(label: categoryLabel),
                  if (distanceLabel != null && distanceLabel!.trim().isNotEmpty)
                    _Badge(label: distanceLabel!),
                  _Badge(label: timeAgoLabel),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.backgroundColor});

  final String label;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
