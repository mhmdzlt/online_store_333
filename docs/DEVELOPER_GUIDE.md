# دليل المطور - متجر 333

## 🏗️ البنية المعمارية

### نظرة عامة
تم بناء التطبيق باستخدام **Clean Architecture** مع فصل كامل للطبقات:

```
┌─────────────────────────────────────┐
│ Presentation Layer                  │
│ • Screens                           │
│ • Widgets                           │
│ • Providers (State Management)      │
│ • Routing                           │
├─────────────────────────────────────┤
│ Domain Layer                        │
│ • Use Cases (قيد التطوير)           │
│ • Entities                          │
├─────────────────────────────────────┤
│ Data Layer                          │
│ • Repositories                      │
│ • Data Sources                       │
│ • Models                            │
└─────────────────────────────────────┘
```

### 1. طبقة العرض (Presentation)
```dart
// الهيكل:
presentation/
├── screens/           # الشاشات الرئيسية
├── widgets/           # مكونات قابلة لإعادة الاستخدام
├── providers/         # إدارة حالة التطبيق
└── routing/           # التوجيه والتنقل

// مثال على Provider:
class CartProvider extends ChangeNotifier {
  final CartRepository _repository;
  // ...
}
```

### 2. طبقة البيانات (Data)
```dart
// الهيكل:
data/
├── models/            # نماذج البيانات
├── repositories/      # واجهات الوصول للبيانات
└── datasources/       # مصادر البيانات (محلية/سحابية)

// مثال على Repository:
class ProductRepository {
  final ProductDataSource _dataSource;

  Future<List<ProductModel>> getFeaturedProducts() async {
    return await _dataSource.getFeaturedProducts();
  }
}
```

### 3. الطبقة الأساسية (Core)
```dart
// الهيكل:
core/
├── constants/         # الثوابت (ألوان، نصوص، مقاسات)
├── themes/            # الثيمات والتخصيصات
├── services/          # الخدمات التنفيذية
└── extensions/        # إضافات على أنواع البيانات

// مثال على استخدام الثوابت:
Container(
  margin: EdgeInsets.all(AppSizes.spaceM),
  color: AppColors.primary,
)
```

## 🚀 كيفية إضافة ميزة جديدة

### الخطوة 1: إنشاء نموذج البيانات
```dart
// في data/models/new_feature/new_model.dart
class NewModel {
  final String id;
  final String name;

  factory NewModel.fromMap(Map<String, dynamic> map) {
    return NewModel(
      id: map['id'],
      name: map['name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}
```

### الخطوة 2: إنشاء DataSource
```dart
// في data/datasources/remote/new_datasource.dart
class NewDataSource {
  final SupabaseClient _client;

  Future<List<NewModel>> getAll() async {
    final response = await _client.from('new_table').select();
    return (response as List).map((e) => NewModel.fromMap(e)).toList();
  }
}
```

### الخطوة 3: إنشاء Repository
```dart
// في data/repositories/new_repository.dart
class NewRepository {
  final NewDataSource _dataSource;

  Future<List<NewModel>> getAllItems() async {
    return await _dataSource.getAll();
  }
}
```

### الخطوة 4: إنشاء Provider
```dart
// في presentation/providers/new_provider.dart
class NewProvider extends ChangeNotifier {
  final NewRepository _repository;
  List<NewModel> _items = [];

  List<NewModel> get items => _items;

  Future<void> loadItems() async {
    _items = await _repository.getAllItems();
    notifyListeners();
  }
}
```

### الخطوة 5: إنشاء الشاشة
```dart
// في presentation/screens/new_feature/new_screen.dart
class NewScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NewProvider>(
      builder: (context, provider, child) {
        if (provider.items.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: provider.items.length,
          itemBuilder: (context, index) {
            final item = provider.items[index];
            return ListTile(title: Text(item.name));
          },
        );
      },
    );
  }
}
```

### الخطوة 6: إضافة المسار
```dart
// في presentation/routing/app_router.dart
GoRoute(
  path: '/new-feature',
  builder: (context, state) => NewScreen(),
),
```

## 🔧 إرشادات التطوير

### 1. تسمية الملفات
- استخدم snake_case للملفات: product_details_screen.dart
- استخدم PascalCase للأصناف: ProductDetailsScreen
- استخدم camelCase للدوال والمتحولات: getProductDetails

### 2. تنظيم الـ Imports
```dart
// 1. حزجات Flutter/Dart
import 'package:flutter/material.dart';

// 2. حزجات خارجية
import 'package:go_router/go_router.dart';

// 3. ملفات المشروع (بدءاً من جذر lib)
import 'core/constants/app_colors.dart';
import 'data/models/product/product_model.dart';
import 'presentation/providers/cart_provider.dart';
```

### 3. معالجة الأخطاء
```dart
Future<void> loadData() async {
  try {
    _items = await _repository.getItems();
  } catch (e) {
    debugPrint('Error loading data: $e');
    _showErrorSnackbar('حدث خطأ في جلب البيانات');
    _items = [];
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

### 4. تحسين الأداء
```dart
// استخدم const حيثما أمكن
const SizedBox(height: 16);

// استخدم ListView.builder للقوائم الكبيرة
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(item: items[index]),
);

// استخدم Consumer و Selector لتقليل إعادة البناء
Consumer<CartProvider>(
  builder: (context, cart, child) {
    return Text('العناصر: ${cart.itemCount}');
  },
);

// ألغِ الـ listeners في dispose
@override
void dispose() {
  _timer?.cancel();
  _scrollController.dispose();
  super.dispose();
}
```

## 📱 نظام التنقل

### 1. التنقل الأساسي
```dart
// استخدم NavigationHelpers دائماً
NavigationHelpers.goToProductDetail(context, 'product-id');
NavigationHelpers.goToCart(context);
NavigationHelpers.push(context, '/new-route');
```

### 2. Deep Linking
```dart
// الإشعارات تدعم الروابط العميقة:
// • product/:id → تفاصيل المنتج
// • order/:id → تتبع الطلب
// • category/:id → منتجات التصنيف

// مثال من NotificationService:
void _handleNotification(Map<String, dynamic> data) {
  final route = data['route'];
  switch (route) {
    case 'product':
      NavigationHelpers.goToProductDetail(context, data['product_id']);
      break;
    // ...
  }
}
```

### 3. إضافة مسار جديد
```dart
// 1. أضف في RouteNames.dart
static const String newRoute = '/new-route';

// 2. أضف في AppRouter.dart
GoRoute(
  path: RouteNames.newRoute,
  builder: (context, state) => NewScreen(),
),

// 3. أضف في NavigationHelpers.dart
static void goToNewRoute(BuildContext context) {
  NavigationHelpers.push(context, RouteNames.newRoute);
}
```

## 🎨 النظام البصري

### 1. الألوان
```dart
// استخدم AppColors دائماً
Container(
  color: AppColors.primary,
  child: Text(
    'نص',
    style: TextStyle(color: AppColors.textPrimary),
  ),
);
```

### 2. النصوص
```dart
// استخدم AppTextStyles
Text('عنوان كبير', style: AppTextStyles.headlineLarge),
Text('نص عادي', style: AppTextStyles.bodyMedium),
Text('سعر', style: AppTextStyles.priceLarge),
```

### 3. المسافات
```dart
// استخدم AppSizes
Container(
  margin: EdgeInsets.all(AppSizes.spaceM),
  padding: EdgeInsets.symmetric(
    horizontal: AppSizes.spaceL,
    vertical: AppSizes.spaceS,
  ),
);
```

## 🧪 الاختبار

### 1. اختبار Providers
```dart
test('CartProvider adds item correctly', () {
  final provider = CartProvider(MockCartRepository());
  provider.addToCart(mockProduct);
  expect(provider.items.length, 1);
});
```

### 2. اختبار Models
```dart
test('ProductModel fromMap works correctly', () {
  final map = {'id': '1', 'name': 'منتج', 'price': 100};
  final product = ProductModel.fromMap(map);
  expect(product.id, '1');
  expect(product.name, 'منتج');
});
```

### 3. اختبار Widgets
```dart
testWidgets('ProductCard displays correctly', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProductCard(product: mockProduct),
    ),
  );

  expect(find.text('منتج'), findsOneWidget);
  expect(find.text('100 ر.س'), findsOneWidget);
});
```

## 📊 المراقبة والتحليل

### 1. تتبع الأحداث
```dart
TrackingService.instance.trackEvent(
  eventName: 'product_viewed',
  metadata: {'product_id': product.id},
);
```

### 2. تسجيل الأخطاء
```dart
try {
  // كود
} catch (e, stack) {
  debugPrint('Error: $e\n$stack');
  await TrackingService.instance.trackError(e, stack);
}
```

### 3. مقاييس الأداء
```dart
final stopwatch = Stopwatch()..start();
await _loadData();
stopwatch.stop();
debugPrint('Data loaded in ${stopwatch.elapsedMilliseconds}ms');
```

## 🚨 استكشاف الأخطاء وإصلاحها

**مشكلة: البيانات لا تظهر**
- تحقق من اتصال الإنترنت
- تحقق من صحة الـ API calls
- تحقق من معالجة الأخطاء في Repository
- تحقق من حالة الـ Provider

**مشكلة: التطبيق بطيء**
- استخدم ListView.builder بدل Column
- استخدم const widgets
- قلل إعادة بناء الـ widgets غير الضرورية
- استخدم Selector بدل Consumer كاملاً

**مشكلة: التنقل لا يعمل**
- تحقق من RouteNames
- تحقق من AppRouter
- تحقق من NavigationHelpers
- تحقق من context الصحيح

## 🎉 الخلاصة
لقد تم تحويل المشروع بنجاح إلى:
- ✅ بنية نظيفة ومنظمة
- ✅ كود سهل الصيانة والتوسعة
- ✅ أداء محسن
- ✅ نظام تنقل موحد
- ✅ توثيق كامل

**مبروك! المشروع الآن جاهز للإنتاج والتوسعة! 🚀**
