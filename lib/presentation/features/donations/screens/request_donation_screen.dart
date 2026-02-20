import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../core/services/device_token_service.dart';
import '../../../../data/repositories/freebies_repository.dart';
import '../../../../utils/content_moderation.dart';
import '../../../../utils/local_storage.dart';
import '../../../routing/navigation_helpers.dart';

class RequestDonationScreen extends StatefulWidget {
  final String donationId;

  const RequestDonationScreen({super.key, required this.donationId});

  @override
  State<RequestDonationScreen> createState() => _RequestDonationScreenState();
}

class _RequestDonationScreenState extends State<RequestDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  final _reasonController = TextEditingController();
  String _contactMethod = 'whatsapp';

  bool _loading = false;
  late final FreebiesRepository _freebiesRepository;

  @override
  void initState() {
    super.initState();
    _freebiesRepository = context.read<FreebiesRepository>();
    _prefillPhone();
  }

  Future<void> _prefillPhone() async {
    final savedPhone = await LocalStorage.getUserPhone();
    if (!mounted || savedPhone == null || savedPhone.trim().isEmpty) return;
    _phoneController.text = savedPhone.trim();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final reason = _reasonController.text.trim();
    if (reason.isNotEmpty &&
        (ContentModeration.hasBlockedWord(reason) ||
            ContentModeration.isLikelyNonsense(reason))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
            ar: 'يرجى كتابة سبب واضح ومناسب.',
            en: 'Please provide a clear and appropriate reason.',
            ckb: 'تکایە هۆکارێکی ڕوون و گونجاو بنووسە.',
            ku: 'Ji kerema xwe sedemek zelal û guncaw binivîse.',
          )),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final phone = _phoneController.text.trim();

      await LocalStorage.saveUserPhone(phone);
      await DeviceTokenService.instance.registerDeviceToken(phone: phone);
      await _freebiesRepository.submitDonationRequest(
        donationId: widget.donationId,
        name: _nameController.text.trim(),
        phone: phone,
        city: _cityController.text.trim(),
        area: _areaController.text.trim(),
        reason: _reasonController.text.trim(),
        contactMethod: _contactMethod,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(context.tr(
            ar: 'تم إرسال الطلب',
            en: 'Request sent',
            ckb: 'داواکاری نێردرا',
            ku: 'Daxwaz hat şandin',
          )),
          content: Text(context.tr(
            ar: 'تم إرسال طلبك، سيتم التواصل معك في حال الموافقة على طلب الهبة.',
            en: 'Your request was sent. We will contact you if it is approved.',
            ckb:
                'داواکارییەکەت نێردرا. ئەگەر پەسەند بکرێت پەیوەندیت پێوە دەکرێت.',
            ku: 'Daxwaza te hate şandin. Heke were pejirandin em ê bi te re têkilî daynin.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(
          ar: 'طلب هبة',
          en: 'Request donation',
          ckb: 'داوای بەخشین',
          ku: 'Daxwaza bexşînê',
        )),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'اسمك',
                  en: 'Your name',
                  ckb: 'ناوت',
                  ku: 'Navê te',
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? context.tr(
                      ar: 'الرجاء إدخال الاسم',
                      en: 'Please enter your name',
                      ckb: 'تکایە ناو بنووسە',
                      ku: 'Ji kerema xwe navê xwe binivîse',
                    )
                  : null,
            ),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'رقم جوالك',
                  en: 'Phone number',
                  ckb: 'ژمارەی مۆبایل',
                  ku: 'Hejmara mobîl',
                ),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? context.tr(
                      ar: 'الرجاء إدخال رقم الجوال',
                      en: 'Please enter your phone number',
                      ckb: 'تکایە ژمارەی مۆبایل بنووسە',
                      ku: 'Ji kerema xwe hejmarê mobîl binivîse',
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
            TextFormField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'سبب طلب الهبة',
                  en: 'Reason for request',
                  ckb: 'هۆکاری داواکردن',
                  ku: 'Sedema daxwazê',
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _contactMethod,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'طريقة التواصل المفضلة',
                  en: 'Preferred contact method',
                  ckb: 'شێوازی پەیوەندی پێویست',
                  ku: 'Awayê têkiliya bijartî',
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: 'whatsapp',
                  child: Text(context.tr(
                    ar: 'واتساب',
                    en: 'WhatsApp',
                    ckb: 'واتسئاپ',
                    ku: 'WhatsApp',
                  )),
                ),
                DropdownMenuItem(
                  value: 'call',
                  child: Text(context.tr(
                    ar: 'اتصال',
                    en: 'Phone call',
                    ckb: 'پەیوەندی تەلەفۆنی',
                    ku: 'Telefon',
                  )),
                ),
                DropdownMenuItem(
                  value: 'chat',
                  child: Text(context.tr(
                    ar: 'شات داخل التطبيق',
                    en: 'In-app chat',
                    ckb: 'چات لە ناو ئەپ',
                    ku: 'Chat di nav app de',
                  )),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _contactMethod = value);
              },
            ),
            const SizedBox(height: 16),
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
                        ar: 'إرسال الطلب',
                        en: 'Send request',
                        ckb: 'ناردنی داواکاری',
                        ku: 'Daxwazê bişîne',
                      )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
