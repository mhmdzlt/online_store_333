import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '../../../providers/cart_provider.dart';
import '../../../../data/repositories/order_repository.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/device_token_service.dart';
import '../../../../utils/content_moderation.dart';
import '../../../../utils/local_storage.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';
import '../../../providers/language_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _t(
    String code, {
    required String ar,
    required String en,
    required String ckb,
    required String ku,
  }) {
    switch (code) {
      case 'en':
        return en;
      case 'ckb':
        return ckb;
      case 'ku':
        return ku;
      case 'ar':
      default:
        return ar;
    }
  }

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  String _shippingMethod = 'courier';
  String _paymentMethod = 'cod';

  bool _isSubmitting = false;
  bool _isFetchingLocation = false;
  bool _isLoadingPricing = true;
  bool _phoneLockedFromAccount = false;
  bool _isApplyingPrefill = false;
  bool _isAutoSavingProfile = false;
  String? _activeInfluencerRefCode;
  DateTime? _lastAutoSyncAt;
  int _autoSaveVersion = 0;
  Map<String, dynamic>? _savedCheckoutProfile;
  List<Map<String, dynamic>> _savedAddresses = [];

  late final OrderRepository _orderRepository;
  late final SupabaseClient _supabaseClient;

  double _shippingCostCourier = 3000;
  double _shippingCostLocal = 0;
  double _serviceFee = 0;
  String _shippingMode = 'fixed';
  double _shippingPercentage = 0;

  double _shippingCost(double subtotal) {
    if (_shippingMode == 'percentage') {
      return subtotal * (_shippingPercentage / 100);
    }
    return _shippingMethod == 'local'
        ? _shippingCostLocal
        : _shippingCostCourier;
  }

  String _shippingLabelHint() {
    final code = context.read<LanguageProvider>().locale.languageCode;
    if (_shippingMode == 'percentage') {
      final value = _shippingPercentage % 1 == 0
          ? _shippingPercentage.toStringAsFixed(0)
          : _shippingPercentage.toStringAsFixed(1);
      return _t(
        code,
        ar: '$value% من المجموع',
        en: '$value% of subtotal',
        ckb: '$value% لە کۆی لاوەکی',
        ku: '$value% ji tevahîya jêr',
      );
    }
    return _shippingMethod == 'local'
        ? _t(
            code,
            ar: 'توصيل محلي ثابت',
            en: 'Fixed local delivery',
            ckb: 'گەیاندنی ناوخۆیی جێگیر',
            ku: 'Şandina herêmî ya sabît',
          )
        : _t(
            code,
            ar: 'شركة شحن ثابت',
            en: 'Fixed courier shipping',
            ckb: 'گەیاندنی کۆمپانیای شحنی جێگیر',
            ku: 'Şandina courier ya sabît',
          );
  }

  double _serviceFeeCost() => _serviceFee;
  double _discount(double subtotal) => 0;

  @override
  void initState() {
    super.initState();
    _orderRepository = context.read<OrderRepository>();
    _supabaseClient = Supabase.instance.client;
    _prefillCustomerInfoIfAvailable();
    _loadInfluencerReferralCode();
    _prefillLocationIfAvailable();
    _loadCheckoutPricingSettings();
    _attachAutoSaveListeners();
    TrackingService.instance.trackEvent(
      eventName: 'checkout_start',
      eventCategory: 'checkout',
      screen: 'checkout',
    );
  }

  void _attachAutoSaveListeners() {
    _nameController.addListener(_scheduleAutoSaveProfile);
    _phoneController.addListener(_scheduleAutoSaveProfile);
    _cityController.addListener(_scheduleAutoSaveProfile);
    _areaController.addListener(_scheduleAutoSaveProfile);
    _addressController.addListener(_scheduleAutoSaveProfile);
    _notesController.addListener(_scheduleAutoSaveProfile);
  }

  void _scheduleAutoSaveProfile() {
    if (_isApplyingPrefill) return;

    _autoSaveVersion += 1;
    final capturedVersion = _autoSaveVersion;

    Future<void> run() async {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted || capturedVersion != _autoSaveVersion) return;
      await _autoSaveCheckoutProfile();
    }

    run();
  }

  Future<void> _autoSaveCheckoutProfile() async {
    if (_isAutoSavingProfile) return;

    final fullName = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();
    final area = _areaController.text.trim();
    final address = _addressController.text.trim();
    final notes = _notesController.text.trim();

    final hasBasicInfo = fullName.isNotEmpty &&
        phone.isNotEmpty &&
        city.isNotEmpty &&
        address.isNotEmpty;
    if (!hasBasicInfo) return;

    _isAutoSavingProfile = true;
    try {
      await LocalStorage.saveCheckoutProfile(
        fullName: fullName,
        phone: phone,
        city: city,
        area: area.isEmpty ? null : area,
        address: address,
        notes: notes.isEmpty ? null : notes,
      );

      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        await LocalStorage.saveCheckoutProfileForUser(
          userId: userId,
          fullName: fullName,
          phone: phone,
          city: city,
          area: area.isEmpty ? null : area,
          address: address,
          notes: notes.isEmpty ? null : notes,
        );
      }

      await LocalStorage.saveUserPhone(phone);

      final now = DateTime.now();
      final shouldSyncToAccount = _lastAutoSyncAt == null ||
          now.difference(_lastAutoSyncAt!).inSeconds >= 3;
      if (shouldSyncToAccount) {
        await _syncCheckoutProfileToAccount({
          'full_name': fullName,
          'phone': phone,
          'city': city,
          'area': area,
          'address': address,
          'notes': notes,
        });
        _lastAutoSyncAt = DateTime.now();
      }
    } finally {
      _isAutoSavingProfile = false;
    }
  }

  Future<void> _loadCheckoutPricingSettings() async {
    setState(() => _isLoadingPricing = true);
    try {
      final row = await _supabaseClient
          .from('checkout_pricing_settings')
          .select('*')
          .eq('id', true)
          .maybeSingle();

      if (!mounted) return;
      if (row == null) {
        setState(() => _isLoadingPricing = false);
        return;
      }

      setState(() {
        _shippingCostCourier =
            (row['shipping_cost_courier'] as num?)?.toDouble() ?? 3000;
        _shippingCostLocal =
            (row['shipping_cost_local'] as num?)?.toDouble() ?? 0;
        _serviceFee = (row['service_fee'] as num?)?.toDouble() ?? 0;
        _shippingMode =
            (row['shipping_mode']?.toString() ?? 'fixed').toLowerCase() ==
                    'percentage'
                ? 'percentage'
                : 'fixed';
        _shippingPercentage =
            (row['shipping_percentage'] as num?)?.toDouble() ?? 0;
        _isLoadingPricing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPricing = false);
    }
  }

  Future<void> _prefillLocationIfAvailable() async {
    final stored = await LocalStorage.getUserLocation();
    if (stored == null || !mounted) return;
    setState(() {});
  }

  Future<void> _prefillCustomerInfoIfAvailable() async {
    _isApplyingPrefill = true;
    final user = _supabaseClient.auth.currentUser;
    final userId = user?.id;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final accountProfile = _extractAccountCheckoutProfile(metadata);
    final accountAddresses = _extractAccountCheckoutAddresses(metadata);
    final profile = (userId != null && userId.isNotEmpty)
        ? await LocalStorage.getCheckoutProfileForUser(userId)
        : await LocalStorage.getCheckoutProfile();
    final localAddresses = (userId != null && userId.isNotEmpty)
        ? await LocalStorage.getCheckoutAddressesForUser(userId)
        : await LocalStorage.getCheckoutAddresses();
    final savedPhone = await LocalStorage.getUserPhone();
    if (!mounted) return;

    _savedAddresses = _normalizeAddresses(localAddresses);

    if (profile != null) {
      _applyProfileToControllers(profile);
      _savedCheckoutProfile = Map<String, dynamic>.from(profile);
    }

    if (_savedAddresses.isNotEmpty && _savedCheckoutProfile == null) {
      _savedCheckoutProfile = Map<String, dynamic>.from(_savedAddresses.first);
      _applyProfileToControllers(_savedCheckoutProfile!);
    }

    if (accountProfile != null) {
      _applyProfileToControllers(accountProfile);
      _savedCheckoutProfile = Map<String, dynamic>.from(accountProfile);
    }

    if (accountAddresses.isNotEmpty) {
      _savedAddresses = _normalizeAddresses(accountAddresses);
      if (_savedCheckoutProfile == null && _savedAddresses.isNotEmpty) {
        _savedCheckoutProfile =
            Map<String, dynamic>.from(_savedAddresses.first);
        _applyProfileToControllers(_savedCheckoutProfile!);
      }
    }

    if (_phoneController.text.trim().isEmpty &&
        savedPhone != null &&
        savedPhone.trim().isNotEmpty) {
      _phoneController.text = savedPhone.trim();
    }

    final accountPhone = (metadata['phone']?.toString() ??
            metadata['phone_number']?.toString() ??
            metadata['mobile']?.toString() ??
            '')
        .trim();
    if (accountPhone.isNotEmpty) {
      _phoneController.text = accountPhone;
      _phoneLockedFromAccount = true;
      await LocalStorage.saveUserPhone(accountPhone);
    }

    final fullName = (metadata['full_name']?.toString() ??
            metadata['name']?.toString() ??
            '')
        .trim();
    if (_nameController.text.trim().isEmpty && fullName.isNotEmpty) {
      _nameController.text = fullName;
    }

    if (mounted) {
      setState(() {});
    }
    _isApplyingPrefill = false;
  }

  Future<void> _loadInfluencerReferralCode() async {
    final code = await LocalStorage.getInfluencerReferralCode();
    if (!mounted) return;
    setState(() => _activeInfluencerRefCode = code);
  }

  Future<void> _clearInfluencerReferralCode() async {
    await LocalStorage.clearInfluencerReferralCode();
    if (!mounted) return;
    setState(() => _activeInfluencerRefCode = null);
  }

  Map<String, dynamic>? _extractAccountCheckoutProfile(
    Map<String, dynamic> metadata,
  ) {
    final raw = metadata['checkout_profile'];
    if (raw is Map) {
      final profile = Map<String, dynamic>.from(raw);
      final hasAddress =
          (profile['city']?.toString().trim().isNotEmpty ?? false) &&
              (profile['address']?.toString().trim().isNotEmpty ?? false);
      if (hasAddress) return profile;
    }
    return null;
  }

  List<Map<String, dynamic>> _extractAccountCheckoutAddresses(
    Map<String, dynamic> metadata,
  ) {
    final raw = metadata['checkout_addresses'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _normalizeAddresses(
    List<Map<String, dynamic>> addresses,
  ) {
    final normalized = <Map<String, dynamic>>[];
    for (final address in addresses) {
      final city = (address['city']?.toString() ?? '').trim();
      final details = (address['address']?.toString() ?? '').trim();
      if (city.isEmpty || details.isEmpty) continue;

      final id = (address['id']?.toString() ?? '').trim().isNotEmpty
          ? address['id'].toString().trim()
          : DateTime.now().microsecondsSinceEpoch.toString();

      normalized.add({
        'id': id,
        'label': (address['label']?.toString() ?? '').trim(),
        'city': city,
        'area': (address['area']?.toString() ?? '').trim(),
        'address': details,
        'notes': (address['notes']?.toString() ?? '').trim(),
      });
    }
    return normalized;
  }

  void _applyProfileToControllers(Map<String, dynamic> profile) {
    _nameController.text = (profile['full_name']?.toString() ?? '').trim();
    _phoneController.text = (profile['phone']?.toString() ?? '').trim();
    _cityController.text = (profile['city']?.toString() ?? '').trim();
    _areaController.text = (profile['area']?.toString() ?? '').trim();
    _addressController.text = (profile['address']?.toString() ?? '').trim();
    _notesController.text = (profile['notes']?.toString() ?? '').trim();
  }

  Map<String, dynamic> _currentCheckoutProfile() {
    return {
      'full_name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'city': _cityController.text.trim(),
      'area': _areaController.text.trim(),
      'address': _addressController.text.trim(),
      'notes': _notesController.text.trim(),
    };
  }

  Map<String, dynamic> _currentAddressProfile() {
    return {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'label': '',
      'city': _cityController.text.trim(),
      'area': _areaController.text.trim(),
      'address': _addressController.text.trim(),
      'notes': _notesController.text.trim(),
    };
  }

  String _addressPreview(Map<String, dynamic> address) {
    final city = (address['city']?.toString() ?? '').trim();
    final area = (address['area']?.toString() ?? '').trim();
    final details = (address['address']?.toString() ?? '').trim();
    final location = [city, area].where((e) => e.isNotEmpty).join(' - ');
    if (location.isEmpty) return details;
    if (details.isEmpty) return location;
    return '$location\n$details';
  }

  void _applyAddressToControllers(Map<String, dynamic> address) {
    _cityController.text = (address['city']?.toString() ?? '').trim();
    _areaController.text = (address['area']?.toString() ?? '').trim();
    _addressController.text = (address['address']?.toString() ?? '').trim();
    final notes = (address['notes']?.toString() ?? '').trim();
    if (notes.isNotEmpty) {
      _notesController.text = notes;
    }
  }

  void _upsertCurrentAddressInSavedList() {
    final current = _currentAddressProfile();
    final city = (current['city']?.toString() ?? '').trim();
    final details = (current['address']?.toString() ?? '').trim();
    if (city.isEmpty || details.isEmpty) return;

    final existingIndex = _savedAddresses.indexWhere((address) {
      return (address['city']?.toString() ?? '').trim() == city &&
          (address['area']?.toString() ?? '').trim() ==
              (current['area']?.toString() ?? '').trim() &&
          (address['address']?.toString() ?? '').trim() == details;
    });

    if (existingIndex >= 0) {
      final merged = Map<String, dynamic>.from(_savedAddresses[existingIndex]);
      merged['notes'] = (current['notes']?.toString() ?? '').trim();
      _savedAddresses.removeAt(existingIndex);
      _savedAddresses.insert(0, merged);
      _savedCheckoutProfile = Map<String, dynamic>.from(merged);
      return;
    }

    _savedAddresses.insert(0, current);
    if (_savedAddresses.length > 10) {
      _savedAddresses = _savedAddresses.take(10).toList();
    }
    _savedCheckoutProfile = Map<String, dynamic>.from(current);
  }

  bool get _hasSavedAddress {
    if (_savedAddresses.isNotEmpty) return true;
    final profile = _savedCheckoutProfile;
    if (profile == null) return false;
    final city = (profile['city']?.toString() ?? '').trim();
    final address = (profile['address']?.toString() ?? '').trim();
    return city.isNotEmpty && address.isNotEmpty;
  }

  Future<bool> _chooseAddressBeforeCheckout() async {
    final code = context.read<LanguageProvider>().locale.languageCode;
    if (!_hasSavedAddress) return true;

    final list = _savedAddresses.isNotEmpty
        ? _savedAddresses
        : (_savedCheckoutProfile == null
            ? <Map<String, dynamic>>[]
            : <Map<String, dynamic>>[_savedCheckoutProfile!]);

    final selection = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _t(
                    code,
                    ar: 'اختيار عنوان التوصيل',
                    en: 'Choose delivery address',
                    ckb: 'ناونیشانی گەیاندن هەڵبژێرە',
                    ku: 'Navnîşana şandinê hilbijêre',
                  ),
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    code,
                    ar: 'قبل إتمام الطلب، هل تريد نفس الموقع المحفوظ أم موقع آخر؟',
                    en: 'Before placing the order, use the saved location or a different one?',
                    ckb:
                        'پێش تەواوکردنی داواکاری، هەمان شوێنی پاشەکەوتکراو یان شوێنێکی تر؟',
                    ku: 'Berî temamkirina fermanê, cihê tomarkirî an cihê din?',
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 12),
                if (list.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final address = list[index];
                        final id = (address['id']?.toString() ?? '').trim();
                        return ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            (address['label']?.toString() ?? '').trim().isEmpty
                                ? _t(
                                    code,
                                    ar: 'عنوان محفوظ',
                                    en: 'Saved address',
                                    ckb: 'ناونیشانی پاشەکەوتکراو',
                                    ku: 'Navnîşana tomarkirî',
                                  )
                                : address['label'].toString(),
                          ),
                          subtitle: Text(
                            _addressPreview(address),
                            textAlign: TextAlign.right,
                          ),
                          onTap: () => Navigator.of(sheetContext).pop(
                            id.isEmpty ? 'saved:$index' : 'saved:$id',
                          ),
                        );
                      },
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.my_location_outlined),
                  title: Text(_t(
                    code,
                    ar: 'التوصيل إلى موقعي الحالي',
                    en: 'Deliver to current location',
                    ckb: 'گەیاندن بۆ شوێنی ئێستام',
                    ku: 'Şandin bo cihê min ê niha',
                  )),
                  subtitle: Text(_t(
                    code,
                    ar: 'تشغيل خدمات الموقع',
                    en: 'Use device location services',
                    ckb: 'خزمەتگوزارییەکانی شوێن چالاک بکە',
                    ku: 'Xizmetên cihê amûrê bi kar bîne',
                  )),
                  onTap: () => Navigator.of(sheetContext).pop('current'),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_location_alt_outlined),
                  title: Text(_t(
                    code,
                    ar: 'التوصيل إلى عنوان آخر',
                    en: 'Deliver to another address',
                    ckb: 'گەیاندن بۆ ناونیشانێکی تر',
                    ku: 'Şandin bo navnîşana din',
                  )),
                  subtitle: Text(_t(
                    code,
                    ar: 'عدّل الحقول يدويًا ثم أكد الطلب',
                    en: 'Edit fields manually then confirm order',
                    ckb:
                        'خانەکان بە دەستی دەستکاری بکە پاشان داوا پشتڕاست بکەوە',
                    ku: 'Qadan bi destan biguherîne paşê fermanê piştrast bike',
                  )),
                  onTap: () => Navigator.of(sheetContext).pop('edit'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selection != null && selection.startsWith('saved:')) {
      final key = selection.substring('saved:'.length).trim();
      var selected = list.firstWhere(
        (address) => (address['id']?.toString() ?? '').trim() == key,
        orElse: () => <String, dynamic>{},
      );
      if (selected.isEmpty) {
        final index = int.tryParse(key);
        if (index != null && index >= 0 && index < list.length) {
          selected = list[index];
        }
      }
      if (selected.isNotEmpty) {
        _savedCheckoutProfile = Map<String, dynamic>.from(selected);
        _applyAddressToControllers(selected);
      } else if (_savedCheckoutProfile != null) {
        _applyAddressToControllers(_savedCheckoutProfile!);
      }
      if (mounted) setState(() {});
      return true;
    }

    if (selection == 'current') {
      await _useCurrentLocation();
      return true;
    }

    if (selection == 'edit') {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            code,
            ar: 'عدّل العنوان ثم اضغط تأكيد الطلب مرة أخرى.',
            en: 'Edit the address and press confirm again.',
            ckb: 'ناونیشانەکە دەستکاری بکە، پاشان دووبارە پشتڕاست بکەوە.',
            ku: 'Navnîşanê biguherîne, paşê dîsa piştrast bike.',
          )),
        ),
      );
      return false;
    }

    return false;
  }

  Future<void> _useCurrentLocation() async {
    final code = context.read<LanguageProvider>().locale.languageCode;
    setState(() => _isFetchingLocation = true);
    try {
      final outcome = await LocationService.getCurrentLocationOutcome();
      if (!mounted) return;
      if (!outcome.isSuccess) {
        final reason = outcome.failure ?? LocationFailureReason.unavailable;
        final message = switch (reason) {
          LocationFailureReason.serviceDisabled => _t(
              code,
              ar: 'خدمة الموقع متوقفة. فعّل GPS ثم حاول مرة أخرى.',
              en: 'Location service is off. Turn on GPS and try again.',
              ckb:
                  'خزمەتگوزاری شوێن ناچالاکە. GPS چالاک بکە و دووبارە هەوڵبدەوە.',
              ku: 'Xizmeta cihê neçalak e. GPS çalak bike û dîsa biceribîne.',
            ),
          LocationFailureReason.permissionDenied ||
          LocationFailureReason.permissionDeniedForever =>
            _t(
              code,
              ar: 'صلاحية الموقع مرفوضة. اسمح للتطبيق بالوصول للموقع من الإعدادات.',
              en: 'Location permission is denied. Allow location access from settings.',
              ckb:
                  'دەسەڵاتی شوێن ڕەتکرایەوە. لە ڕێکخستنەکان ڕێگە بدە بە ئەپ بگات بە شوێن.',
              ku: 'Destûra cihê red bûye. Di mîhengan de destûr bide appê.',
            ),
          LocationFailureReason.unavailable => _t(
              code,
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
                    label: _t(
                      code,
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

      _cityController.text = result.city ?? _cityController.text;
      _areaController.text = result.area ?? _areaController.text;
      if (_addressController.text.trim().isEmpty &&
          result.addressLine != null &&
          result.addressLine!.trim().isNotEmpty) {
        _addressController.text = result.addressLine!;
      }

      await LocalStorage.saveUserLocation(
        latitude: result.latitude,
        longitude: result.longitude,
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_scheduleAutoSaveProfile);
    _phoneController.removeListener(_scheduleAutoSaveProfile);
    _cityController.removeListener(_scheduleAutoSaveProfile);
    _areaController.removeListener(_scheduleAutoSaveProfile);
    _addressController.removeListener(_scheduleAutoSaveProfile);
    _notesController.removeListener(_scheduleAutoSaveProfile);
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cart = context.read<CartProvider>();

    final proceedWithAddress = await _chooseAddressBeforeCheckout();
    if (!proceedWithAddress) return;

    if (!_formKey.currentState!.validate()) return;
    if (cart.items.isEmpty) return;

    final subtotal = cart.subtotal;
    final shippingCost = _shippingCost(subtotal);
    final serviceFee = _serviceFeeCost();
    final discount = _discount(subtotal);
    final influencerRefCode = _activeInfluencerRefCode ??
        await LocalStorage.getInfluencerReferralCode();

    TrackingService.instance.trackEvent(
      eventName: 'checkout_submit',
      eventCategory: 'checkout',
      screen: 'checkout',
      metadata: {
        'items_count': cart.items.length,
        'subtotal': subtotal,
        'shipping_cost': shippingCost,
        'service_fee': serviceFee,
        'discount': discount,
        if (influencerRefCode != null && influencerRefCode.trim().isNotEmpty)
          'influencer_ref_code': influencerRefCode.trim().toUpperCase(),
      },
    );

    setState(() => _isSubmitting = true);

    try {
      final items = cart.items
          .map((c) => {
                'product_id': c.productId,
                'quantity': c.quantity,
                'size': c.size,
                'color': c.color,
              })
          .toList();

      final result = await _orderRepository.createOrderPublic(
        customerName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        area: _areaController.text.trim().isEmpty
            ? null
            : _areaController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        shippingMethod: _shippingMethod,
        paymentMethod: _paymentMethod,
        items: items,
        shippingCost: shippingCost + serviceFee,
        discountAmount: discount,
        influencerRefCode: influencerRefCode,
      );

      final orderNumber = result['order_number'] as String;

      final userId = _supabaseClient.auth.currentUser?.id;
      _upsertCurrentAddressInSavedList();
      if (userId != null && userId.isNotEmpty) {
        await LocalStorage.saveUserOrderNumber(
          userId: userId,
          orderNumber: orderNumber,
        );
        await LocalStorage.saveCheckoutProfileForUser(
          userId: userId,
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          city: _cityController.text.trim(),
          area: _areaController.text.trim().isEmpty
              ? null
              : _areaController.text.trim(),
          address: _addressController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
        await LocalStorage.saveCheckoutAddressesForUser(
          userId: userId,
          addresses: _savedAddresses,
        );
      }

      await LocalStorage.saveCheckoutProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        area: _areaController.text.trim().isEmpty
            ? null
            : _areaController.text.trim(),
        address: _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      await LocalStorage.saveCheckoutAddresses(_savedAddresses);
      await LocalStorage.saveUserPhone(_phoneController.text.trim());
      await _syncCheckoutProfileToAccount(_currentCheckoutProfile());
      await DeviceTokenService.instance
          .registerDeviceToken(phone: _phoneController.text.trim());

      if (influencerRefCode != null && influencerRefCode.trim().isNotEmpty) {
        await LocalStorage.clearInfluencerReferralCode();
        if (mounted) {
          setState(() => _activeInfluencerRefCode = null);
        }
      }

      await cart.clearAndSync();

      TrackingService.instance.trackEvent(
        eventName: 'checkout_complete',
        eventCategory: 'checkout',
        screen: 'checkout',
        metadata: {
          'order_number': orderNumber,
          'total': subtotal + shippingCost + serviceFee - discount,
          'items_count': items.length,
          if (influencerRefCode != null && influencerRefCode.trim().isNotEmpty)
            'influencer_ref_code': influencerRefCode.trim().toUpperCase(),
        },
      );

      if (!mounted) return;
      NavigationHelpers.replace(
        context,
        RouteNames.orderSuccess,
        extra: {
          'orderNumber': orderNumber,
          'phone': _phoneController.text.trim(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      final code = context.read<LanguageProvider>().locale.languageCode;

      String message = _t(
        code,
        ar: 'حدث خطأ أثناء إرسال الطلب.',
        en: 'An error occurred while submitting the order.',
        ckb: 'هەڵەیەک ڕوویدا لە ناردنی داواکاری.',
        ku: 'Di dema şandina fermanê de çewtiyek çêbû.',
      );
      bool insufficientStock = false;

      if (e is PostgrestException) {
        final raw = (e.message).toLowerCase();
        if (raw.contains('insufficient stock') || e.code == 'P0001') {
          message = _t(
            code,
            ar: 'الكمية المطلوبة غير متوفرة لبعض المنتجات. عدّل الكمية وحاول مرة أخرى.',
            en: 'Requested quantity is unavailable for some products. Adjust the cart and try again.',
            ckb:
                'بڕی داواکراو بۆ هەندێک کاڵا بەردەست نییە. سەبەتەکە دەستکاری بکە و دووبارە هەوڵبدەوە.',
            ku: 'Ji bo hin berheman hejmarê daxwazkirî berdest nîne. Sepetê rast bike û dîsa biceribîne.',
          );
          insufficientStock = true;
        } else if (e.message.isNotEmpty) {
          message = e.message;
        }
      } else {
        message =
            '${_t(code, ar: 'حدث خطأ أثناء إرسال الطلب', en: 'Error submitting order', ckb: 'هەڵە لە ناردنی داوا', ku: 'Di şandina fermanê de çewtî')} : $e';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: insufficientStock
              ? SnackBarAction(
                  label: _t(
                    code,
                    ar: 'تعديل السلة',
                    en: 'Edit cart',
                    ckb: 'دەستکاری سەبەت',
                    ku: 'Sepetê biguherîne',
                  ),
                  onPressed: () {
                    if (mounted) {
                      NavigationHelpers.go(context, RouteNames.cart);
                    }
                  },
                )
              : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _syncCheckoutProfileToAccount(
    Map<String, dynamic> checkoutProfile,
  ) async {
    final phone = (checkoutProfile['phone']?.toString() ?? '').trim();
    if (phone.isEmpty) return;

    final user = _supabaseClient.auth.currentUser;
    if (user == null) return;

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final mergedMetadata = <String, dynamic>{
      ...metadata,
      'phone': phone,
      'checkout_profile': {
        'full_name': (checkoutProfile['full_name']?.toString() ?? '').trim(),
        'phone': phone,
        'city': (checkoutProfile['city']?.toString() ?? '').trim(),
        'area': (checkoutProfile['area']?.toString() ?? '').trim(),
        'address': (checkoutProfile['address']?.toString() ?? '').trim(),
        'notes': (checkoutProfile['notes']?.toString() ?? '').trim(),
      },
      'checkout_addresses': _savedAddresses,
    };

    try {
      await _supabaseClient.auth.updateUser(
        UserAttributes(data: mergedMetadata),
      );
      _phoneLockedFromAccount = true;
      _savedCheckoutProfile =
          Map<String, dynamic>.from(mergedMetadata['checkout_profile'] as Map);
      _savedAddresses = _normalizeAddresses(
        (mergedMetadata['checkout_addresses'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
    } catch (_) {
      // Ignore metadata sync failures; checkout should still succeed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = context.watch<LanguageProvider>().locale.languageCode;
    final cart = context.watch<CartProvider>();
    final subtotal = cart.subtotal;
    final shippingCost = _shippingCost(subtotal);
    final serviceFee = _serviceFeeCost();
    final discount = _discount(subtotal);
    final total = subtotal + shippingCost + serviceFee - discount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t(
            code,
            ar: 'إتمام الشراء',
            en: 'Checkout',
            ckb: 'تەواوکردنی کڕین',
            ku: 'Checkout',
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _t(
                code,
                ar: 'بيانات العميل',
                en: 'Customer info',
                ckb: 'زانیاری کڕیار',
                ku: 'Agahiyên bikarhêner',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _t(
                  code,
                  ar: 'الاسم الكامل',
                  en: 'Full name',
                  ckb: 'ناوی تەواو',
                  ku: 'Navê temam',
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? _t(
                      code,
                      ar: 'الرجاء إدخال الاسم',
                      en: 'Please enter your name',
                      ckb: 'تکایە ناو بنووسە',
                      ku: 'Ji kerema xwe navê xwe binivîse',
                    )
                  : null,
            ),
            TextFormField(
              controller: _phoneController,
              readOnly: _phoneLockedFromAccount,
              decoration: InputDecoration(
                labelText: _t(
                  code,
                  ar: 'رقم الجوال',
                  en: 'Mobile number',
                  ckb: 'ژمارەی مۆبایل',
                  ku: 'Hejmara mobîl',
                ),
                helperText: _phoneLockedFromAccount
                    ? _t(
                        code,
                        ar: 'تم مزامنة الرقم مع حسابك، ويمكن تغييره من الحساب.',
                        en: 'Phone is synced with your account and can be changed from account settings.',
                        ckb:
                            'ژمارەکە لەگەڵ هەژمارەکەت هاوکاتکراوە و دەتوانیت لە ڕێکخستنەکان بگۆڕیت.',
                        ku: 'Hejmare bi hesabê te re hatî hevdemkirin û dikare ji mîhengan were guhertin.',
                      )
                    : null,
              ),
              validator: (v) => v == null || v.isEmpty
                  ? _t(
                      code,
                      ar: 'الرجاء إدخال رقم الجوال',
                      en: 'Please enter your mobile number',
                      ckb: 'تکایە ژمارەی مۆبایل بنووسە',
                      ku: 'Ji kerema xwe hejmarê mobîl binivîse',
                    )
                  : (!ContentModeration.isLikelyValidPhone(v)
                      ? _t(
                          code,
                          ar: 'رقم الهاتف غير صالح',
                          en: 'Invalid phone number',
                          ckb: 'ژمارەی تەلەفۆن دروست نییە',
                          ku: 'Hejmara têlefonê ne rast e',
                        )
                      : null),
            ),
            TextFormField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: _t(
                  code,
                  ar: 'المدينة',
                  en: 'City',
                  ckb: 'شار',
                  ku: 'Bajar',
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? _t(
                      code,
                      ar: 'الرجاء إدخال المدينة',
                      en: 'Please enter city',
                      ckb: 'تکایە شار بنووسە',
                      ku: 'Ji kerema xwe bajar binivîse',
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isFetchingLocation ? null : _useCurrentLocation,
              icon: _isFetchingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _t(
                  code,
                  ar: 'استخدم موقعي لملء العنوان',
                  en: 'Use my location to fill address',
                  ckb: 'شوێنەکەم بەکاربهێنە بۆ پڕکردنەوەی ناونیشان',
                  ku: 'Cihê min bi kar bîne da ku navnîşan were tije kirin',
                ),
              ),
            ),
            TextFormField(
              controller: _areaController,
              decoration: InputDecoration(
                labelText: _t(
                  code,
                  ar: 'المنطقة / الحي',
                  en: 'Area / neighborhood',
                  ckb: 'ناوچە / گەڕەک',
                  ku: 'Herêm / tax',
                ),
              ),
            ),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: _t(
                  code,
                  ar: 'تفاصيل العنوان',
                  en: 'Address details',
                  ckb: 'وردەکاری ناونیشان',
                  ku: 'Hûrguliyên navnîşanê',
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? _t(
                      code,
                      ar: 'الرجاء إدخال العنوان',
                      en: 'Please enter address',
                      ckb: 'تکایە ناونیشان بنووسە',
                      ku: 'Ji kerema xwe navnîşan binivîse',
                    )
                  : null,
            ),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: _t(
                  code,
                  ar: 'ملاحظات إضافية (اختياري)',
                  en: 'Additional notes (optional)',
                  ckb: 'تێبینی زیاتر (ئیختیاری)',
                  ku: 'Têbînîyên zêde (bijarte)',
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            if (_isLoadingPricing)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(),
              ),
            Text(
              _t(
                code,
                ar: 'طريقة الشحن',
                en: 'Shipping method',
                ckb: 'شێوازی گەیاندن',
                ku: 'Rêbaza şandinê',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'courier',
                    label: Text(_t(
                      code,
                      ar: 'شركة شحن',
                      en: 'Courier',
                      ckb: 'کۆمپانیای گەیاندن',
                      ku: 'Courier',
                    ))),
                ButtonSegment(
                    value: 'local',
                    label: Text(_t(
                      code,
                      ar: 'توصيل محلي',
                      en: 'Local delivery',
                      ckb: 'گەیاندنی ناوخۆیی',
                      ku: 'Şandina herêmî',
                    ))),
              ],
              selected: <String>{_shippingMethod},
              onSelectionChanged: (selection) {
                setState(() => _shippingMethod = selection.first);
              },
            ),
            const SizedBox(height: 16),
            if (_activeInfluencerRefCode != null &&
                _activeInfluencerRefCode!.trim().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondaryContainer
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _t(
                          code,
                          ar: 'تم تطبيق إحالة المروج: ${_activeInfluencerRefCode!}',
                          en: 'Influencer referral applied: ${_activeInfluencerRefCode!}',
                          ckb:
                              'ڕیفێڕاڵی مروژەر جێبەجێکرا: ${_activeInfluencerRefCode!}',
                          ku: 'Referral a influencer hat sepandin: ${_activeInfluencerRefCode!}',
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: _t(
                        code,
                        ar: 'إزالة',
                        en: 'Remove',
                        ckb: 'لابردن',
                        ku: 'Rake',
                      ),
                      onPressed: _clearInfluencerReferralCode,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            Text(
              _t(
                code,
                ar: 'طريقة الدفع',
                en: 'Payment method',
                ckb: 'شێوازی پارەدان',
                ku: 'Rêbaza dayînê',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                    value: 'cod',
                    label: Text(_t(
                      code,
                      ar: 'الدفع عند الاستلام',
                      en: 'Cash on delivery',
                      ckb: 'پارەدان کاتی وەرگرتن',
                      ku: 'Peredayîna dema wergirtinê',
                    ))),
                ButtonSegment(
                    value: 'online',
                    label: Text(_t(
                      code,
                      ar: 'الدفع الإلكتروني (لاحقاً)',
                      en: 'Online payment (later)',
                      ckb: 'پارەدانی ئۆنلاین (دواتر)',
                      ku: 'Peredayîna online (paşê)',
                    ))),
              ],
              selected: <String>{_paymentMethod},
              onSelectionChanged: (selection) {
                setState(() => _paymentMethod = selection.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              _t(
                code,
                ar: 'ملخص الطلب',
                en: 'Order summary',
                ckb: 'پوختەی داوا',
                ku: 'Kurteya fermanê',
              ),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _t(
                    code,
                    ar: 'المجموع الفرعي',
                    en: 'Subtotal',
                    ckb: 'کۆی لاوەکی',
                    ku: 'Tevahîya jêr',
                  ),
                ),
                const Spacer(),
                Text(subtotal.toStringAsFixed(0)),
              ],
            ),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        code,
                        ar: 'الشحن',
                        en: 'Shipping',
                        ckb: 'گەیاندن',
                        ku: 'Şandin',
                      ),
                    ),
                    Text(
                      _shippingLabelHint(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const Spacer(),
                Text(shippingCost.toStringAsFixed(0)),
              ],
            ),
            Row(
              children: [
                Text(
                  _t(
                    code,
                    ar: 'رسوم الخدمة',
                    en: 'Service fee',
                    ckb: 'کرێی خزمەتگوزاری',
                    ku: 'Lêçûna xizmetê',
                  ),
                ),
                const Spacer(),
                Text(serviceFee.toStringAsFixed(0)),
              ],
            ),
            Row(
              children: [
                Text(
                  _t(
                    code,
                    ar: 'الخصم',
                    en: 'Discount',
                    ckb: 'داشکاندن',
                    ku: 'Kêmkirin',
                  ),
                ),
                const Spacer(),
                Text(discount.toStringAsFixed(0)),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Text(
                  _t(
                    code,
                    ar: 'المجموع الكلي',
                    en: 'Total',
                    ckb: 'کۆی گشتی',
                    ku: 'Tevahî',
                  ),
                ),
                const Spacer(),
                Text(total.toStringAsFixed(0)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const AppLoading(
                        size: 18,
                        padding: EdgeInsets.zero,
                      )
                    : Text(
                        _t(
                          code,
                          ar: 'تأكيد الطلب',
                          en: 'Confirm order',
                          ckb: 'پشتڕاستکردنەوەی داوا',
                          ku: 'Piştrastkirina fermanê',
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
