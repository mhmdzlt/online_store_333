# UI Guidelines

## الهدف
توحيد أسلوب الواجهات في التطبيق وتقليل التكرار أثناء بناء الشاشات الجديدة.

## 1) استخدام Design System
- استخدم مكونات `design_system` أولاً قبل بناء Widget جديد.
- استخدم `AppTheme` و`AppColors` و`AppSizes` و`AppTextStyles` بدل القيم العشوائية.
- للمسافات والحواف استخدم `AppSizes` و`AppRadii`.
- للبطاقات استخدم `AppShadows.card` بدل تعريف ظلال مختلفة لكل شاشة.

## 2) قواعد تسمية المكونات
- `*Screen`: الشاشة الرئيسية للميزة.
- `*Section`: جزء مستقل داخل الشاشة.
- `*Card`: عنصر بطاقة قابل لإعادة الاستخدام.
- `*Tile` أو `*Item`: عنصر ضمن قائمة.
- أمثلة:
  - `HomeScreen`
  - `HomeCategoriesSection`
  - `ProductCard`

## 3) تنظيم الملفات
- الشاشات الجديدة داخل:
  - `lib/presentation/features/<feature>/screens/`
- المكونات الفرعية داخل:
  - `lib/presentation/features/<feature>/widgets/`
- مزودات الحالة داخل:
  - `lib/presentation/providers/`

## 4) أنماط واجهة موصى بها
- شاشة طويلة/مختلطة المحتوى: استخدم `CustomScrollView` + Slivers.
- القوائم/الشبكات: استخدم `ListView.builder` و`SliverGridDelegateWithMaxCrossAxisExtent`.
- حالات الفراغ/التحميل: استخدم `AppEmptyState` و`AppLoading`.
- حقول البحث: استخدم `AppSearchField`.

## 5) الثوابت والأداء
- استخدم `const` كلما كان ممكنًا.
- تجنب القيم السحرية (Magic Numbers).
- قسّم الشاشات الكبيرة إلى `Section Widgets`.
- حافظ على `IndexedStack` أو `keepAlive` عند الحاجة لحفظ حالة التبويبات.

## 6) أمثلة استخدام سريعة

### عنوان قسم
```dart
const AppSectionHeader(title: 'منتجات مميزة')
```

### زر موحّد
```dart
AppButton(
  label: 'متابعة',
  onPressed: onContinue,
)
```

### حقل إدخال موحّد
```dart
AppTextField(
  hintText: 'ابحث...',
  prefixIcon: Icons.search,
  onChanged: onQueryChanged,
)
```
