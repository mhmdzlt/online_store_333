import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/car/car_brand.dart';
import '../../../../data/models/order/order_model.dart';
import '../../../../data/models/order/order_item_model.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../data/repositories/order_repository.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../utils/local_storage.dart';
import '../../../../core/localization/language_text.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen>
    with WidgetsBindingObserver {
  late final CatalogRepository _catalog;
  late final OrderRepository _orderRepository;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final FocusNode _brandFocusNode = FocusNode();

  bool _loading = false;
  OrderModel? _order;
  bool _loadingBrands = false;
  List<CarBrand> _brands = [];
  List<CarBrand> _filteredBrands = [];
  String _brandQuery = '';
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _catalog = context.read<CatalogRepository>();
    _orderRepository = context.read<OrderRepository>();
    TrackingService.instance.trackScreen('user_search');
    _brandFocusNode.addListener(() {
      if (!_brandFocusNode.hasFocus && _brandQuery.isNotEmpty) {
        _clearBrandSearch();
      }
    });
    Future.microtask(_loadSavedPhone);
    _loadBrands();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneController.dispose();
    _orderController.dispose();
    _brandController.dispose();
    _brandFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final isVisible = bottomInset > 0.0;
    if (_keyboardVisible && !isVisible && _brandQuery.isNotEmpty) {
      _clearBrandSearch();
    }
    _keyboardVisible = isVisible;
  }

  Future<void> _loadBrands() async {
    setState(() => _loadingBrands = true);
    try {
      final result = await _catalog.fetchCarBrands();
      _brands = result.map(CarBrand.fromMap).toList();
      _applyBrandFilter();
    } catch (e) {
      debugPrint('Error loading brands: $e');
    } finally {
      if (mounted) setState(() => _loadingBrands = false);
    }
  }

  void _applyBrandFilter() {
    final query = _brandQuery.trim().toLowerCase();
    final filtered = _brands.where((b) {
      final name = b.name.toLowerCase();
      return query.isEmpty || name.contains(query);
    }).toList();

    if (mounted) {
      setState(() => _filteredBrands = filtered);
    } else {
      _filteredBrands = filtered;
    }
  }

  Future<void> _loadSavedPhone() async {
    final savedPhone = await LocalStorage.getUserPhone();
    if (savedPhone != null && savedPhone.isNotEmpty && mounted) {
      _phoneController.text = savedPhone;
    }
  }

  Future<void> _search() async {
    final phone = _phoneController.text.trim();
    final orderNumber = _orderController.text.trim();

    if (phone.isEmpty && orderNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'أدخل رقم الجوال أو رقم الطلب للبحث.',
              en: 'Enter phone number or order number to search.',
              ckb: 'ژمارەی مۆبایل یان ژمارەی داوا بنووسە بۆ گەڕان.',
              ku: 'Ji bo lêgerînê hejmareya telefonê an fermanê binivîse.',
            ),
          ),
        ),
      );
      return;
    }

    if (orderNumber.isNotEmpty && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'أدخل رقم الجوال لتتبع رقم الطلب.',
              en: 'Enter phone number to track this order number.',
              ckb: 'ژمارەی مۆبایل بنووسە بۆ شوێنکەوتنی ژمارەی داوا.',
              ku: 'Ji bo şopandina vê hejmareya fermanê, hejmareya telefonê binivîse.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _order = null;
    });

    try {
      if (phone.isNotEmpty) {
        await LocalStorage.saveUserPhone(phone);
      }

      if (phone.isNotEmpty && orderNumber.isNotEmpty) {
        await _loadOrder(orderNumber, phone);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOrder(String orderNumber, String phone) async {
    try {
      final result = await _orderRepository.trackOrder(
        orderNumber: orderNumber,
        phone: phone,
      );
      if (mounted) {
        setState(
            () => _order = result == null ? null : OrderModel.fromMap(result));
      }
    } catch (e) {
      debugPrint('Error loading order: $e');
    }
  }

  Widget _buildOrderSection() {
    if (_order == null) {
      if (_orderController.text.trim().isEmpty) return const SizedBox.shrink();
      return Text(
        context.tr(
          ar: 'لم يتم العثور على طلب بهذا الرقم.',
          en: 'No order found with this number.',
          ckb: 'هیچ داواکارییەک بەو ژمارەیە نەدۆزرایەوە.',
          ku: 'Ti fermanek bi vê hejmarê nehat dîtin.',
        ),
      );
    }

    final status = _order?.status;
    final items = _order?.items ?? const <OrderItemModel>[];
    final total = _order?.totalAmount;
    final shipping = _order?.shippingCost;
    final discount = _order?.discountAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            ar: 'نتيجة الطلب',
            en: 'Order result',
            ckb: 'ئەنجامی داوا',
            ku: 'Encama fermanê',
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _buildOrderStatus(status, _order?.rejectionReason),
        if (_order?.orderNumber.isNotEmpty == true)
          Text(
              '${context.tr(ar: 'رقم الطلب', en: 'Order number', ckb: 'ژمارەی داوا', ku: 'Hejmara fermanê')}: ${_order!.orderNumber}'),
        if (total != null)
          Text(
              '${context.tr(ar: 'الإجمالي', en: 'Total', ckb: 'کۆی گشتی', ku: 'Tevahî')}: $total'),
        if (shipping != null)
          Text(
              '${context.tr(ar: 'الشحن', en: 'Shipping', ckb: 'گەیاندن', ku: 'Şandin')}: $shipping'),
        if (discount != null)
          Text(
              '${context.tr(ar: 'الخصم', en: 'Discount', ckb: 'داشکاندن', ku: 'Kêmkirin')}: $discount'),
        const SizedBox(height: 12),
        if (items.isNotEmpty) ...[
          const Text(
            'عناصر الطلب:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...items.map(_buildOrderItemCard),
        ],
      ],
    );
  }

  Widget _buildOrderStatus(String? status, String? reason) {
    if (status == null) return const SizedBox.shrink();
    if (status == 'rejected') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تم رفض طلبك',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          if (reason != null && reason.isNotEmpty)
            Text(
              '${context.tr(ar: 'السبب', en: 'Reason', ckb: 'هۆکار', ku: 'Sedem')}: $reason',
              style: const TextStyle(color: Colors.red),
            ),
        ],
      );
    }

    if (status == 'accepted') {
      return Text(
        context.tr(
          ar: 'تم قبول طلبك وجاري تجهيز الطلب',
          en: 'Your order is accepted and being prepared.',
          ckb: 'داواکارییەکەت پەسەندکرا و ئامادەدەکرێت.',
          ku: 'Fermana te hate pejirandin û tê amadekirin.',
        ),
      );
    }

    if (status == 'pending_review') {
      return Text(
        context.tr(
          ar: 'طلبك قيد المراجعة',
          en: 'Your order is under review.',
          ckb: 'داواکارییەکەت لە ژێر پێداچوونەوەدایە.',
          ku: 'Fermana te di bin nirxandinê de ye.',
        ),
      );
    }

    return Text(
      '${context.tr(ar: 'حالة الطلب', en: 'Order status', ckb: 'دۆخی داوا', ku: 'Rewşa fermanê')}: $status',
    );
  }

  Widget _buildOrderItemCard(OrderItemModel item) {
    final name = item.productName;
    final qty = item.quantity;
    final total = item.lineTotal;

    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(
          '${context.tr(ar: 'الكمية', en: 'Quantity', ckb: 'بڕ', ku: 'Hejmar')}: $qty',
        ),
        trailing: total == null ? null : Text('$total'),
      ),
    );
  }

  Widget _buildBrandSearchField() {
    return TextField(
      controller: _brandController,
      focusNode: _brandFocusNode,
      scrollPadding: EdgeInsets.zero,
      onChanged: (value) {
        _brandQuery = value;
        _applyBrandFilter();
      },
      decoration: InputDecoration(
        hintText: context.tr(
          ar: 'ابحث عن ماركة سيارة...',
          en: 'Search car brand...',
          ckb: 'بەدوای مارکەی ئۆتۆمبێلدا بگەڕێ...',
          ku: 'Li markeya erebeyê bigere...',
        ),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _brandQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearBrandSearch,
              ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _clearBrandSearch() {
    _brandController.clear();
    _brandQuery = '';
    _applyBrandFilter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            ar: 'بحث المستخدم',
            en: 'User search',
            ckb: 'گەڕانی بەکارهێنەر',
            ku: 'Lêgerîna bikarhêner',
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr(
              ar: 'البحث عن طلب',
              en: 'Search order',
              ckb: 'گەڕان بۆ داوا',
              ku: 'Li fermanê bigere',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: context.tr(
                ar: 'رقم الجوال',
                en: 'Phone number',
                ckb: 'ژمارەی مۆبایل',
                ku: 'Hejmara telefonê',
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _orderController,
            decoration: InputDecoration(
              labelText: context.tr(
                ar: 'رقم الطلب',
                en: 'Order number',
                ckb: 'ژمارەی داوا',
                ku: 'Hejmara fermanê',
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _search,
              child: _loading
                  ? const AppLoading(
                      size: 18,
                      padding: EdgeInsets.zero,
                    )
                  : Text(
                      context.tr(
                        ar: 'بحث',
                        en: 'Search',
                        ckb: 'گەڕان',
                        ku: 'Lêgerîn',
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _buildOrderSection(),
          const Divider(height: 32),
          Text(
            context.tr(
              ar: 'تصفية حسب الماركة',
              en: 'Filter by brand',
              ckb: 'پاڵاوتن بەپێی براند',
              ku: 'Parzûnkirin li gor brandê',
            ),
          ),
          const SizedBox(height: 8),
          _buildBrandSearchField(),
          const SizedBox(height: 12),
          if (_loadingBrands)
            const AppLoading()
          else
            ..._filteredBrands.map((brand) => ListTile(
                  title: Text(brand.name),
                  onTap: () {
                    NavigationHelpers.push(
                      context,
                      RouteNames.carModels,
                      extra: {
                        'brandId': brand.id,
                        'brandName': brand.name,
                      },
                    );
                  },
                )),
        ],
      ),
    );
  }
}
