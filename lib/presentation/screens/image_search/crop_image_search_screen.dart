import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/language_text.dart';

class CropImageSearchScreen extends StatefulWidget {
  const CropImageSearchScreen({
    super.key,
    required this.source,
  });

  final XFile source;

  static Future<XFile?> open(BuildContext context, XFile source) {
    return Navigator.of(context).push<XFile?>(
      MaterialPageRoute(
        builder: (_) => CropImageSearchScreen(source: source),
      ),
    );
  }

  @override
  State<CropImageSearchScreen> createState() => _CropImageSearchScreenState();
}

class _CropImageSearchScreenState extends State<CropImageSearchScreen> {
  CropController _controller = CropController();
  Key _cropKey = UniqueKey();

  Uint8List? _bytes;
  bool _loading = true;
  bool _cropping = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBytes());
  }

  Future<void> _loadBytes() async {
    try {
      final bytes = await widget.source.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _loading = false;
      });
    }
  }

  Future<void> _crop() async {
    if (_cropping) return;
    setState(() => _cropping = true);
    _controller.crop();
  }

  void _reset() {
    setState(() {
      _controller = CropController();
      _cropKey = UniqueKey();
      _cropping = false;
    });
  }

  Future<XFile> _writeCroppedBytes(Uint8List data) async {
    final dir = Directory.systemTemp;
    final file = File(
      '${dir.path}${Platform.pathSeparator}img_search_crop_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(data, flush: true);
    return XFile(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(
          ar: 'تحديد جزء من الصورة',
          en: 'Select image area',
          ckb: 'دیاریکردنی بەشێک لە وێنە',
          ku: 'Hilbijartina beşek ji wêneyê',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(widget.source),
            child: Text(context.tr(
              ar: 'تخطي',
              en: 'Skip',
              ckb: 'بازدان',
              ku: 'Derbas bike',
            )),
          ),
          TextButton(
            onPressed: (_loading || _bytes == null) ? null : _reset,
            child: Text(context.tr(
              ar: 'إعادة ضبط',
              en: 'Reset',
              ckb: 'ڕیسێت',
              ku: 'Reset',
            )),
          ),
          TextButton(
            onPressed: (_loading || _bytes == null) ? null : _crop,
            child: _cropping
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr(
                    ar: 'تم',
                    en: 'Done',
                    ckb: 'تەواو',
                    ku: 'Temam',
                  )),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_bytes == null)
              ? Center(
                  child: Text(context.tr(
                  ar: 'تعذر تحميل الصورة',
                  en: 'Failed to load image',
                  ckb: 'بارکردنی وێنە سەرکەوتوو نەبوو',
                  ku: 'Barkirina wêneyê bi ser neket',
                )))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Crop(
                      key: _cropKey,
                      image: _bytes!,
                      controller: _controller,
                      interactive: false,
                      onCropped: (result) async {
                        switch (result) {
                          case CropSuccess(:final croppedImage):
                            try {
                              final out = await _writeCroppedBytes(
                                croppedImage,
                              );
                              if (!context.mounted) return;
                              Navigator.of(context).pop(out);
                            } catch (_) {
                              if (!context.mounted) return;
                              setState(() => _cropping = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr(
                                    ar: 'تعذر حفظ الصورة المقصوصة',
                                    en: 'Failed to save cropped image',
                                    ckb:
                                        'پاشەکەوتکردنی وێنەی بڕاو سەرکەوتوو نەبوو',
                                    ku: 'Tomarkirina wêneya qutkirî bi ser neket',
                                  )),
                                ),
                              );
                            }
                          case CropFailure():
                            if (!context.mounted) return;
                            setState(() => _cropping = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.tr(
                                  ar: 'تعذر قص الصورة',
                                  en: 'Failed to crop image',
                                  ckb: 'بڕینی وێنە سەرکەوتوو نەبوو',
                                  ku: 'Qutkirina wêneyê bi ser neket',
                                )),
                              ),
                            );
                        }
                      },
                      baseColor: colorScheme.surface,
                      maskColor: colorScheme.scrim.withValues(alpha: 0.55),
                      radius: 16,
                      withCircleUi: false,
                      cornerDotBuilder: (size, edgeAlignment) => _CornerDot(
                        size: size,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _CornerDot extends StatelessWidget {
  const _CornerDot({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
