import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/device_token_service.dart';
import '../../../../data/repositories/freebies_repository.dart';
import '../../../../utils/content_moderation.dart';
import '../../../../utils/local_storage.dart';
import '../../../routing/navigation_helpers.dart';

class DonateItemScreen extends StatefulWidget {
  const DonateItemScreen({super.key});

  @override
  State<DonateItemScreen> createState() => _DonateItemScreenState();
}

class _DonateItemScreenState extends State<DonateItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _donorNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];

  bool _loading = false;
  bool _loadingLocation = false;
  double? _latitude;
  double? _longitude;
  late final FreebiesRepository _freebiesRepository;

  @override
  void initState() {
    super.initState();
    _freebiesRepository = context.read<FreebiesRepository>();
  }

  @override
  void dispose() {
    _donorNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked.isEmpty) return;

      setState(() {
        _images
          ..clear()
          ..addAll(picked.take(3));
      });
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
            ar: 'حدث خطأ أثناء اختيار الصور',
            en: 'An error occurred while selecting images',
            ckb: 'هەڵەیەک ڕوویدا لە هەڵبژاردنی وێنەکاندا',
            ku: 'Di dema hilbijartina wêneyan de çewtiyek çêbû',
          )),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final donorName = _donorNameController.text.trim();

    final blocked = ContentModeration.hasBlockedWord(title) ||
        ContentModeration.hasBlockedWord(description);
    if (blocked ||
        ContentModeration.isLikelyNonsense(title) ||
        ContentModeration.isLikelyNonsense(donorName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
            ar: 'يرجى إدخال عنوان ووصف واضحين للهبة، وتجنب المحتوى غير المناسب.',
            en: 'Please enter a clear title/description and avoid inappropriate content.',
            ckb:
                'تکایە ناونیشان/وەسفێکی ڕوون بنووسە و ناوەڕۆکی گونجاونەهاتوو مەبەست مەکە.',
            ku: 'Ji kerema xwe sernav/danasînek zelal binivîse û ji naveroka neguncaw dûr bikeve.',
          )),
        ),
      );
      return;
    }

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr(
          ar: 'الرجاء اختيار صورة واحدة على الأقل للهبة',
          en: 'Please choose at least one image for the donation',
          ckb: 'تکایە لانیکەم یەک وێنە بۆ بەخشین هەڵبژێرە',
          ku: 'Ji kerema xwe ji bo bexşînê herî kêm wêneyek hilbijêre',
        ))),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final donorPhone = _phoneController.text.trim();
      if (donorPhone.isNotEmpty) {
        await LocalStorage.saveUserPhone(donorPhone);
        await DeviceTokenService.instance
            .registerDeviceToken(phone: donorPhone);
      }

      await _freebiesRepository.submitDonation(
        donorName: _donorNameController.text.trim(),
        donorPhone: donorPhone,
        city: _cityController.text.trim(),
        area: _areaController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        images: _images,
        latitude: _latitude,
        longitude: _longitude,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(context.tr(
            ar: 'تم استلام طلب التبرع',
            en: 'Donation request received',
            ckb: 'داواکاریی بەخشین وەرگیرا',
            ku: 'Daxwaza bexşînê hat wergirtin',
          )),
          content: Text(context.tr(
            ar: 'سيتم مراجعة الهبة قبل النشر. شكراً لك.',
            en: 'The donation will be reviewed before publishing. Thank you.',
            ckb: 'بەخشینەکە پێش بڵاوکردنەوە پشکنین دەکرێت. سوپاس.',
            ku: 'Bexşîn berî belavkirinê dê were pêşdîtin. Spas.',
          )),
          actions: [
            TextButton(
              onPressed: () {
                NavigationHelpers.pop(context);
                NavigationHelpers.pop(context);
              },
              child: Text(context.tr(
                ar: 'حسناً',
                en: 'OK',
                ckb: 'باشە',
                ku: 'Başe',
              )),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingLocation = true);
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
        _latitude = result.latitude;
        _longitude = result.longitude;
      });

      if (result.city != null && result.city!.isNotEmpty) {
        _cityController.text = result.city!;
      }
      if (result.area != null && result.area!.isNotEmpty) {
        _areaController.text = result.area!;
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(
          ar: 'التبرع بهبة جديدة',
          en: 'Donate a new item',
          ckb: 'بەخشینی شتێکی نوێ',
          ku: 'Bexşîna tiştekî nû',
        )),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _donorNameController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'اسم المتبرع',
                  en: 'Donor name',
                  ckb: 'ناوی بەخشەر',
                  ku: 'Navê bexşdar',
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? context.tr(
                      ar: 'الرجاء إدخال الاسم',
                      en: 'Please enter name',
                      ckb: 'تکایە ناو بنووسە',
                      ku: 'Ji kerema xwe nav binivîse',
                    )
                  : null,
            ),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'رقم الهاتف',
                  en: 'Phone number',
                  ckb: 'ژمارەی تەلەفۆن',
                  ku: 'Hejmara têlefonê',
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? context.tr(
                      ar: 'الرجاء إدخال رقم الهاتف',
                      en: 'Please enter phone number',
                      ckb: 'تکایە ژمارەی تەلەفۆن بنووسە',
                      ku: 'Ji kerema xwe hejmarê têlefonê binivîse',
                    )
                  : (!ContentModeration.isLikelyValidPhone(v)
                      ? context.tr(
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
                labelText: context.tr(
                  ar: 'المدينة',
                  en: 'City',
                  ckb: 'شار',
                  ku: 'Bajar',
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? context.tr(
                      ar: 'الرجاء إدخال المدينة',
                      en: 'Please enter city',
                      ckb: 'تکایە شار بنووسە',
                      ku: 'Ji kerema xwe bajar binivîse',
                    )
                  : null,
            ),
            TextFormField(
              controller: _areaController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'المنطقة / الحي',
                  en: 'Area / neighborhood',
                  ckb: 'ناوچە / گەڕەک',
                  ku: 'Herêm / tax',
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadingLocation ? null : _useCurrentLocation,
              icon: _loadingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_outlined),
              label: Text(context.tr(
                ar: 'استخدم موقعي',
                en: 'Use my location',
                ckb: 'شوێنەکەم بەکاربهێنە',
                ku: 'Cihê min bi kar bîne',
              )),
            ),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'عنوان الهبة',
                  en: 'Donation title',
                  ckb: 'ناونیشانی بەخشین',
                  ku: 'Sernavê bexşînê',
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? context.tr(
                      ar: 'الرجاء إدخال العنوان',
                      en: 'Please enter title',
                      ckb: 'تکایە ناونیشان بنووسە',
                      ku: 'Ji kerema xwe sernav binivîse',
                    )
                  : null,
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'وصف الهبة',
                  en: 'Donation description',
                  ckb: 'وەسفی بەخشین',
                  ku: 'Danasîna bexşînê',
                ),
              ),
              maxLines: 3,
              validator: (v) => v == null || v.isEmpty
                  ? context.tr(
                      ar: 'الرجاء إدخال الوصف',
                      en: 'Please enter description',
                      ckb: 'تکایە وەسف بنووسە',
                      ku: 'Ji kerema xwe danasîn binivîse',
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(context.tr(
                      ar: 'اختيار صور',
                      en: 'Choose images',
                      ckb: 'هەڵبژاردنی وێنە',
                      ku: 'Hilbijartina wêneyan',
                    )),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${_images.length}/3'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const AppLoading(
                        size: 18,
                        padding: EdgeInsets.zero,
                      )
                    : Text(context.tr(
                        ar: 'إرسال التبرع',
                        en: 'Submit donation',
                        ckb: 'ناردنی بەخشین',
                        ku: 'Bexşînê bişîne',
                      )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
