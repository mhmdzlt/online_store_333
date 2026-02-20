import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/models/freebies/freebie_model.dart';
import '../../../../data/repositories/freebies_repository.dart';
import '../../../../utils/image_resolvers.dart';
import '../../../../utils/local_storage.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';
import 'package:design_system/design_system.dart';

class DonationDetailsScreen extends StatelessWidget {
  final String donationId;

  const DonationDetailsScreen({super.key, required this.donationId});

  String _statusLabel(BuildContext context, String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    switch (status) {
      case 'reserved':
        return context.tr(
          ar: 'محجوز',
          en: 'Reserved',
          ckb: 'پارێزراو',
          ku: 'Rezerv kirî',
        );
      case 'in_progress':
      case 'completed':
        return context.tr(
          ar: 'تم التسليم',
          en: 'Completed',
          ckb: 'تەواوبوو',
          ku: 'Temam bû',
        );
      case 'available':
      default:
        return context.tr(
          ar: 'متاح',
          en: 'Available',
          ckb: 'بەردەست',
          ku: 'Berdest',
        );
    }
  }

  String _locationLabel(FreebieModel donation) {
    final city = donation.city.trim();
    final area = (donation.area ?? '').trim();
    if (city.isEmpty && area.isEmpty) return '-';
    if (city.isEmpty) return area;
    if (area.isEmpty) return city;
    return '$city - $area';
  }

  Future<void> _showReportDialog(
    BuildContext context,
    FreebiesRepository repository,
  ) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final detailsController = TextEditingController();
    String selectedReason = 'spam';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final reasons = <Map<String, String>>[
          {
            'value': 'spam',
            'label': context.tr(
              ar: 'محتوى مزعج/غير حقيقي',
              en: 'Spam/Fake content',
              ckb: 'ناوەڕۆکی درۆ/ئازاردهەر',
              ku: 'Naveroka derew/spam',
            ),
          },
          {
            'value': 'prohibited',
            'label': context.tr(
              ar: 'غرض ممنوع',
              en: 'Prohibited item',
              ckb: 'شتی قەدەغە',
              ku: 'Tişta qedexe',
            ),
          },
          {
            'value': 'abuse',
            'label': context.tr(
              ar: 'إساءة/سلوك غير لائق',
              en: 'Abuse/Inappropriate behavior',
              ckb: 'سوکایەتی/ڕەفتاری ناگونجاو',
              ku: 'Destdirêjî/helwesta neguncaw',
            ),
          },
        ];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.tr(
                ar: 'إبلاغ عن هذه الهبة',
                en: 'Report this donation',
                ckb: 'بلاغ لەسەر ئەم بەخشینە',
                ku: 'Vê bexşînê report bike',
              )),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      items: reasons
                          .map(
                            (reason) => DropdownMenuItem<String>(
                              value: reason['value'],
                              child: Text(reason['label']!),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedReason = value);
                      },
                      decoration: InputDecoration(
                        labelText: context.tr(
                          ar: 'سبب البلاغ',
                          en: 'Report reason',
                          ckb: 'هۆکاری بلاغ',
                          ku: 'Sedema reportê',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: detailsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          ar: 'تفاصيل إضافية (اختياري)',
                          en: 'Additional details (optional)',
                          ckb: 'وردەکاری زیاتر (ئیختیاری)',
                          ku: 'Hûrguliyên zêde (bijarte)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          ar: 'اسمك (اختياري)',
                          en: 'Your name (optional)',
                          ckb: 'ناوت (ئیختیاری)',
                          ku: 'Navê te (bijarte)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          ar: 'رقمك (اختياري)',
                          en: 'Your phone (optional)',
                          ckb: 'ژمارەت (ئیختیاری)',
                          ku: 'Hejmara te (bijarte)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(context.tr(
                    ar: 'إلغاء',
                    en: 'Cancel',
                    ckb: 'هەڵوەشاندنەوە',
                    ku: 'Betal',
                  )),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await repository.submitDonationReport(
                        donationId: donationId,
                        reason: selectedReason,
                        details: detailsController.text.trim(),
                        reporterName: nameController.text.trim(),
                        reporterPhone: phoneController.text.trim(),
                      );
                      if (!context.mounted) return;
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.tr(
                            ar: 'تم إرسال البلاغ وسيتم مراجعته.',
                            en: 'Report submitted and will be reviewed.',
                            ckb: 'بلاغ نێردرا و پشکنین دەکرێت.',
                            ku: 'Report hat şandin û dê were pêşdîtin.',
                          )),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  },
                  child: Text(context.tr(
                    ar: 'إرسال البلاغ',
                    en: 'Submit report',
                    ckb: 'ناردنی بلاغ',
                    ku: 'Report bişîne',
                  )),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelivery(
    BuildContext context,
    FreebiesRepository repository,
  ) async {
    final phone = (await LocalStorage.getUserPhone())?.trim() ?? '';
    if (phone.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
            ar: 'لا يمكن تأكيد التسليم بدون رقم هاتف محفوظ على هذا الجهاز.',
            en: 'Delivery cannot be confirmed without a saved phone number on this device.',
            ckb:
                'ناتوانرێت تەسلیمکردن پشتڕاست بکرێتەوە بەبێ ژمارەی تەلەفۆنی پاشەکەوتکراو.',
            ku: 'Teslîmkirin bêjimareya têlefonê ya tomarkirî nayê piştrastkirin.',
          )),
        ),
      );
      return;
    }

    final canConfirm = await repository.canConfirmDonationDelivery(
      donationId: donationId,
      actorPhone: phone,
    );
    if (!canConfirm) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
            ar: 'يمكن فقط للأطراف المقبولة في هذه الهبة تأكيد التسليم.',
            en: 'Only accepted parties in this donation can confirm delivery.',
            ckb:
                'تەنها لایەنە پەسەندکراوەکان لەم بەخشینە دەتوانن تەسلیمکردن پشتڕاست بکەنەوە.',
            ku: 'Tenê aliyên pejirandî yên vê bexşînê dikarin teslîmkirinê piştrast bikin.',
          )),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(
          ar: 'تأكيد التسليم',
          en: 'Confirm delivery',
          ckb: 'پشتڕاستکردنەوەی تەسلیمکردن',
          ku: 'Teslîmkirinê piştrast bike',
        )),
        content: Text(context.tr(
          ar: 'هل تم تسليم هذه الهبة بالفعل؟ سيتم إغلاق الطلب عند التأكيد.',
          en: 'Was this donation already handed over? The request will be closed once confirmed.',
          ckb:
              'ئایا ئەم بەخشینە بەڕاستی تەسلیم کراوە؟ دوای پشتڕاستکردنەوە داواکاری دادەخرێت.',
          ku: 'Ma ev bexşîn bi rastî hat teslîmkirin? Piştî piştrastkirin daxwaz dê were girtin.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr(
              ar: 'إلغاء',
              en: 'Cancel',
              ckb: 'هەڵوەشاندنەوە',
              ku: 'Betal',
            )),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr(
              ar: 'نعم، تم التسليم',
              en: 'Yes, delivered',
              ckb: 'بەڵێ، تەسلیم کرا',
              ku: 'Erê, hat teslîmkirin',
            )),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await repository.confirmDonationDelivered(
        donationId: donationId,
        actorPhone: phone,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr(
            ar: 'تم تأكيد التسليم بنجاح.',
            en: 'Delivery confirmed successfully.',
            ckb: 'تەسلیمکردن بە سەرکەوتوویی پشتڕاستکرایەوە.',
            ku: 'Teslîmkirin bi serkeftî hate piştrastkirin.',
          )),
        ),
      );
      NavigationHelpers.replace(
        context,
        RouteNames.freebieDetailPath(donationId),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<FreebiesRepository>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(
          ar: 'تفاصيل الهبة',
          en: 'Donation details',
          ckb: 'وردەکاری بەخشین',
          ku: 'Hûrguliyên bexşînê',
        )),
      ),
      body: FutureBuilder<FreebieModel?>(
        future: repository
            .fetchDonationById(donationId)
            .then((row) => row == null ? null : FreebieModel.fromMap(row)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }
          final donation = snapshot.data;
          if (donation == null) {
            return AppEmptyState(
                message: context.tr(
              ar: 'الهبة غير موجودة',
              en: 'Donation not found',
              ckb: 'بەخشین نەدۆزرایەوە',
              ku: 'Bexşîn nehat dîtin',
            ));
          }

          final images = donation.imageUrls;
          final rawStatus =
              donation.status.isNotEmpty ? donation.status : 'available';
          final status = _statusLabel(context, rawStatus);
          final isRequestable = rawStatus.trim().toLowerCase() == 'available';
          final isCompleted = rawStatus.trim().toLowerCase() == 'completed';
          final canShowConfirmButton = !isRequestable && !isCompleted;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Builder(
                      builder: (context) {
                        final img = resolveDonationImage(images);
                        if (img == null) {
                          return AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 40,
                              ),
                            ),
                          );
                        }
                        return AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Container(
                            color: Colors.grey.shade100,
                            child: AppImage(
                              imageUrl: img,
                              fit: BoxFit.contain,
                              radius: 0,
                              placeholderIcon: Icons.image_not_supported,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      donation.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_locationLabel(donation)),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr(ar: 'الحالة', en: 'Status', ckb: 'دۆخ', ku: 'Rewş')}: $status',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr(
                        ar: 'الوصف',
                        en: 'Description',
                        ckb: 'وەسف',
                        ku: 'Danasîn',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(donation.description),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          context.tr(
                            ar: 'سيتم تزويدك ببيانات التواصل مع المتبرع بعد أن يتم قبول طلبك لهذه الهبة.',
                            en: 'You will receive donor contact details after your request is accepted for this donation.',
                            ckb:
                                'دوای پەسەندکردنی داواکارییەکەت بۆ ئەم بەخشینە، زانیاری پەیوەندی بەخشەر پێت دەدرێت.',
                            ku: 'Piştî ku daxwaza te ji bo vê bexşînê were pejirandin, agahiyên têkiliyê yên bexşdarê dê pêşkêşî te bibin.',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showReportDialog(context, repository),
                        icon: const Icon(Icons.flag_outlined),
                        label: Text(
                          context.tr(
                            ar: 'إبلاغ عن هذه الهبة',
                            en: 'Report this donation',
                            ckb: 'بلاغ لەسەر ئەم بەخشینە',
                            ku: 'Vê bexşînê report bike',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isRequestable
                            ? () {
                                NavigationHelpers.push(
                                  context,
                                  RouteNames.requestDonation,
                                  extra: {
                                    'donationId': donationId,
                                  },
                                );
                              }
                            : null,
                        child: Text(context.tr(
                          ar: isRequestable
                              ? 'طلب هذه الهبة'
                              : 'هذه الهبة غير متاحة الآن',
                          en: isRequestable
                              ? 'Request this donation'
                              : 'This donation is not available now',
                          ckb: isRequestable
                              ? 'داوای ئەم بەخشینە بکە'
                              : 'ئەم بەخشینە ئێستا بەردەست نییە',
                          ku: isRequestable
                              ? 'Daxwaza vê bexşînê bike'
                              : 'Ev bexşîn niha berdest nîne',
                        )),
                      ),
                    ),
                    if (canShowConfirmButton)
                      FutureBuilder<bool>(
                        future: LocalStorage.getUserPhone().then((value) async {
                          final actorPhone = (value ?? '').trim();
                          if (actorPhone.isEmpty) return false;
                          return repository.canConfirmDonationDelivery(
                            donationId: donationId,
                            actorPhone: actorPhone,
                          );
                        }),
                        builder: (context, eligibilitySnapshot) {
                          if (eligibilitySnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }

                          if (eligibilitySnapshot.data != true) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            children: [
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _confirmDelivery(context, repository),
                                  icon: const Icon(Icons.verified),
                                  label: Text(context.tr(
                                    ar: 'تأكيد تم التسليم',
                                    en: 'Confirm delivered',
                                    ckb: 'پشتڕاستکردنەوەی تەسلیمکردن',
                                    ku: 'Teslîmkirinê piştrast bike',
                                  )),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
