import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

import '../../../../core/localization/language_text.dart';
import '../../../../data/datasources/remote/supabase_rfq_datasource.dart';
import '../../../../data/datasources/remote/supabase_vin_datasource.dart';
import '../../../../utils/local_storage.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';

class RfqCreateScreen extends StatefulWidget {
  const RfqCreateScreen({super.key});

  @override
  State<RfqCreateScreen> createState() => _RfqCreateScreenState();
}

class _RfqCreateScreenState extends State<RfqCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vinController = TextEditingController();
  final _descController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  XFile? _image;
  Uint8List? _imageBytes;

  bool _submitting = false;
  bool _vinDecoding = false;
  String? _vinDecodeError;
  Map<String, dynamic>? _vinDecodeResult;
  final _ds = SupabaseRfqDataSource();
  final _vinDs = SupabaseVinDataSource();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vinController.dispose();
    _descController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  String? _extractVin(String raw) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final vinRegex = RegExp(r'[A-HJ-NPR-Z0-9]{17}');
    final match = vinRegex.firstMatch(cleaned);
    return match?.group(0);
  }

  Future<void> _decodeVin(String vin) async {
    setState(() {
      _vinDecoding = true;
      _vinDecodeError = null;
      _vinDecodeResult = null;
    });

    try {
      final res = await _vinDs.decodeVinLocal(vin);
      if (!mounted) return;
      setState(() {
        _vinDecodeResult = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vinDecodeError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _vinDecoding = false);
      }
    }
  }

  Future<void> _scanVinWithCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;

    final inputImage = InputImage.fromFilePath(picked.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final vin = _extractVin(recognizedText.text);
    if (vin == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'لم يتم العثور على VIN صالح في الصورة',
              en: 'No valid VIN found in the image',
              ckb: 'هیچ VIN ـێکی دروست لە وێنەکەدا نەدۆزرایەوە',
              ku: 'Di wêneyê de VIN-eke derbasdar nehat dîtin',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _vinController.text = vin;
    });
    await _decodeVin(vin);
  }

  Future<void> _pickSingleImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _image = picked;
      _imageBytes = bytes;
    });
  }

  Future<String?> _uploadSingleImageIfAny() async {
    final file = _image;
    if (file == null) return null;

    final bytes = _imageBytes ?? await file.readAsBytes();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final path = 'rfq/$fileName';

    final storage = Supabase.instance.client.storage.from('product-images');
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        cacheControl: '3600',
        upsert: false,
      ),
    );

    return storage.getPublicUrl(path);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final invalidServerResponseMessage = context.tr(
      watch: false,
      ar: 'استجابة غير صالحة من الخادم',
      en: 'Invalid response from server',
      ckb: 'وەڵامی نەگونجاو لە ڕاژەکارهەوە',
      ku: 'Bersiva nederbasdar ji serverê',
    );
    final failedCreateRequestMessage = context.tr(
      watch: false,
      ar: 'فشل إنشاء الطلب',
      en: 'Failed to create request',
      ckb: 'دروستکردنی داواکاری سەرکەوتوو نەبوو',
      ku: 'Afirandina daxwazê bi ser neket',
    );

    setState(() => _submitting = true);

    try {
      final imageUrl = await _uploadSingleImageIfAny();

      final result = await _ds.createPartRequestPublic(
        customerName: _nameController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        vin: _vinController.text.trim().isEmpty
            ? null
            : _vinController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        imageUrls:
            (imageUrl != null && imageUrl.isNotEmpty) ? [imageUrl] : null,
      );

      final requestNumber = result['request_number']?.toString() ?? '';
      final accessToken = result['access_token']?.toString() ?? '';

      if (requestNumber.isEmpty || accessToken.isEmpty) {
        throw Exception(invalidServerResponseMessage);
      }

      await LocalStorage.saveRfqRequest(
        requestNumber: requestNumber,
        accessToken: accessToken,
        customerPhone: _phoneController.text.trim(),
      );

      if (!mounted) return;
      NavigationHelpers.replace(
        context,
        RouteNames.rfqOffersPath(requestNumber),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$failedCreateRequestMessage: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            ar: 'طلب تسعير جديد',
            en: 'New quotation request',
            ckb: 'داواکاری نرخی نوێ',
            ku: 'Daxwaza bihayê ya nû',
          ),
        ),
        centerTitle: true,
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
                  ar: 'الاسم',
                  en: 'Name',
                  ckb: 'ناو',
                  ku: 'Nav',
                ),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.tr(
                      ar: 'أدخل الاسم',
                      en: 'Enter name',
                      ckb: 'ناو بنووسە',
                      ku: 'Nav binivîse',
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'رقم الهاتف',
                  en: 'Phone number',
                  ckb: 'ژمارەی تەلەفۆن',
                  ku: 'Hejmara telefonê',
                ),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.tr(
                      ar: 'أدخل رقم الهاتف',
                      en: 'Enter phone number',
                      ckb: 'ژمارەی تەلەفۆن بنووسە',
                      ku: 'Hejmara telefonê binivîse',
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vinController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'VIN (اختياري)',
                  en: 'VIN (optional)',
                  ckb: 'VIN (ئیختیاری)',
                  ku: 'VIN (vebijarkî)',
                ),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final trimmed = value.trim();
                if (trimmed.length == 17) {
                  _decodeVin(trimmed);
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _scanVinWithCamera,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(
                    context.tr(
                      ar: 'مسح VIN بالكاميرا',
                      en: 'Scan VIN with camera',
                      ckb: 'VIN بە کامێرا سکان بکە',
                      ku: 'VIN bi kamerayê scan bike',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_vinDecoding)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (_vinDecodeError != null) ...[
              const SizedBox(height: 6),
              Text(
                context.tr(
                  ar: 'تعذر التحقق من VIN محليًا',
                  en: 'Could not validate VIN locally',
                  ckb: 'نەکرا VIN بە شێوەی ناوخۆیی پشتڕاست بکرێتەوە',
                  ku: 'VIN bi awayê navxweyî nehat piştrastkirin',
                ),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            if (_vinDecodeResult != null) ...[
              const SizedBox(height: 6),
              _VinDecodeSummary(result: _vinDecodeResult!),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'وصف القطعة المطلوبة',
                  en: 'Part description',
                  ckb: 'وەسفی پارچەی پێویست',
                  ku: 'Danasîna parçeya hewce',
                ),
                hintText: context.tr(
                  ar: 'مثال: رديتر كامري 2012، أو كشاف يمين...',
                  en: 'Example: Camry 2012 radiator, or right headlight...',
                  ckb: 'نمونە: رادیەتەری کامری 2012، یان چرای ڕاست...',
                  ku: 'Mînak: radyatora Camry 2012, an çiraya rast...',
                ),
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (v) => (v == null || v.trim().length < 6)
                  ? context.tr(
                      ar: 'اكتب وصفاً أوضح',
                      en: 'Write a clearer description',
                      ckb: 'وەسفێکی ڕوونتر بنووسە',
                      ku: 'Danasînek zelaltir binivîse',
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _pickSingleImage,
              icon: const Icon(Icons.image),
              label: Text(
                _image == null
                    ? context.tr(
                        ar: 'إرفاق صورة (اختياري)',
                        en: 'Attach image (optional)',
                        ckb: 'زیادکردنی وێنە (ئیختیاری)',
                        ku: 'Wêne lê zêde bike (vebijarkî)',
                      )
                    : context.tr(
                        ar: 'تغيير الصورة',
                        en: 'Change image',
                        ckb: 'گۆڕینی وێنە',
                        ku: 'Wêneyê biguherîne',
                      ),
              ),
            ),
            if (_image != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _imageBytes!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _submitting
                      ? null
                      : () {
                          setState(() => _image = null);
                          setState(() => _imageBytes = null);
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    context.tr(
                      ar: 'إزالة الصورة',
                      en: 'Remove image',
                      ckb: 'لابردنی وێنە',
                      ku: 'Wêneyê rake',
                    ),
                  ),
                ),
              ),
            ],
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(
                context.tr(
                  ar: 'إرسال الطلب',
                  en: 'Submit request',
                  ckb: 'ناردنی داواکاری',
                  ku: 'Daxwazê bişîne',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                ar: 'ملاحظة: يمكنك التواصل مع التاجر عبر واتساب أو الشات داخل التطبيق قبل الدفع، ثم تدفع عبر السلة.',
                en: 'Note: You can contact the seller via WhatsApp or in-app chat before payment, then pay through cart.',
                ckb:
                    'تێبینی: دەتوانیت پێش پارەدان لە ڕێی واتساپ یان چاتی ناو بەرنامە پەیوەندی بە فرۆشیار بکەیت، پاشان لە ڕێی سەبەت پارە بدەیت.',
                ku: 'Têbînî: Berî dayîna pereyê dikarî bi WhatsApp an chatê nav appê bi firoşkar re têkilî daynî, paşê bi sepetê pere bide.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _VinDecodeSummary extends StatelessWidget {
  const _VinDecodeSummary({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = result[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    final make = pick(['make', 'manufacturer', 'brand']);
    final model = pick(['model']);
    final year = pick(['model_year', 'year']);

    if (make == null && model == null && year == null) {
      return const SizedBox.shrink();
    }

    final parts = <String>[];
    if (make != null) parts.add(make);
    if (model != null) parts.add(model);
    if (year != null) parts.add(year);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_outlined, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${context.tr(ar: 'نتيجة VIN', en: 'VIN result', ckb: 'ئەنجامی VIN', ku: 'Encama VIN')}: ${parts.join(' • ')}',
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
