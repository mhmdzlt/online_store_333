import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../../../../core/localization/language_text.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../data/datasources/remote/supabase_influencer_datasource.dart';

class InfluencerPartnershipScreen extends StatefulWidget {
  const InfluencerPartnershipScreen({super.key});

  @override
  State<InfluencerPartnershipScreen> createState() =>
      _InfluencerPartnershipScreenState();
}

class _InfluencerPartnershipScreenState
    extends State<InfluencerPartnershipScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _audienceSizeController = TextEditingController();
  final _dataSource = SupabaseInfluencerDataSource();

  String _platform = 'instagram';
  bool _loadingProfile = true;
  bool _submitting = false;
  bool _authRedirecting = false;
  Map<String, dynamic>? _existingProfile;
  Map<String, dynamic>? _referralSummary;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthService.instance.onAuthStateChange.listen((event) {
      if (!mounted) return;
      if (event.session?.user.id == null) return;
      Future.microtask(_loadProfile);
    });
    Future.microtask(_loadProfile);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _fullNameController.dispose();
    _handleController.dispose();
    _phoneController.dispose();
    _audienceSizeController.dispose();
    super.dispose();
  }

  Future<bool> _ensureSignedIn() async {
    final user = AuthService.instance.currentUser;
    if (user != null) return true;

    if (_authRedirecting) return false;

    setState(() => _authRedirecting = true);
    try {
      return await AuthService.instance.ensureSignedInWithGoogle();
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'تعذر بدء تسجيل الدخول الآن. حاول مرة أخرى.',
              en: 'Unable to start sign-in right now. Please try again.',
              ckb:
                  'ئێستا ناتوانرێت چوونەژوورەوە دەستپێبکات. تکایە دووبارە هەوڵ بدە.',
              ku: 'Nikare niha dest bi têketinê bike. Ji kerema xwe dîsa biceribîne.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _authRedirecting = false);
      }
    }

    return false;
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);

    try {
      final signedIn = await _ensureSignedIn();
      if (!signedIn) {
        if (!mounted) return;
        setState(() {
          _existingProfile = null;
          _loadingProfile = false;
        });
        return;
      }

      final currentUser = AuthService.instance.currentUser;
      final profile = await _dataSource.fetchMyProfile();

      if (!mounted) return;

      if (profile != null) {
        _existingProfile = profile;
        _fullNameController.text = profile['full_name']?.toString() ?? '';
        _handleController.text = profile['handle']?.toString() ?? '';
        _phoneController.text = profile['contact_phone']?.toString() ?? '';
        _audienceSizeController.text =
            profile['audience_size']?.toString() ?? '';
        _platform = profile['platform']?.toString() ?? 'instagram';

        if (profile['status']?.toString() == 'approved') {
          _referralSummary = await _dataSource.fetchMyReferralSummary();
        } else {
          _referralSummary = null;
        }
      } else {
        _existingProfile = null;
        _referralSummary = null;
        _fullNameController.text =
            currentUser?.userMetadata?['full_name']?.toString() ??
                currentUser?.userMetadata?['name']?.toString() ??
                '';
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'تعذر تحميل بيانات الشراكة حاليًا.',
              en: 'Unable to load partnership data right now.',
              ckb: 'ناتوانرێت داتای هاوبەشی ئێستا بهێنرێت.',
              ku: 'Nikare daneyên hevkariyê niha were barkirin.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  Future<void> _copyToClipboard(String value, String typeLabel) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            watch: false,
            ar: 'تم نسخ $typeLabel',
            en: '$typeLabel copied',
            ckb: '$typeLabel کۆپی کرا',
            ku: '$typeLabel hate kopîkirin',
          ),
        ),
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case 'approved':
        return context.tr(
          ar: 'مقبول',
          en: 'Approved',
          ckb: 'پەسەندکراو',
          ku: 'Pejirandî',
        );
      case 'rejected':
        return context.tr(
          ar: 'مرفوض',
          en: 'Rejected',
          ckb: 'ڕەتکراوە',
          ku: 'Redkirî',
        );
      case 'pending':
      default:
        return context.tr(
          ar: 'قيد المراجعة',
          en: 'Under review',
          ckb: 'لە پێداچوونەوەدایە',
          ku: 'Di nirxandinê de ye',
        );
    }
  }

  Future<void> _submitApplication() async {
    final signedIn = await _ensureSignedIn();
    if (!signedIn) {
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final audienceSize = int.tryParse(_audienceSizeController.text.trim());

    setState(() => _submitting = true);
    try {
      await _dataSource.submitMyApplication(
        fullName: _fullNameController.text.trim(),
        platform: _platform,
        handle: _handleController.text.trim(),
        audienceSize: audienceSize,
        contactPhone: _phoneController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'تم إرسال طلب الشراكة بنجاح.',
              en: 'Partnership application submitted successfully.',
              ckb: 'داواکاری هاوبەشی بە سەرکەوتوویی نێردرا.',
              ku: 'Daxwaza hevkariyê bi serkeftî hate şandin.',
            ),
          ),
        ),
      );

      await _loadProfile();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'تعذر إرسال الطلب، حاول مرة أخرى.',
              en: 'Unable to submit the application, please try again.',
              ckb: 'ناتوانرێت داواکاریەکە بنێردرێت، تکایە دووبارە هەوڵ بدە.',
              ku: 'Daxwaz nayê şandin, ji kerema xwe dîsa biceribîne.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _existingProfile?['status']?.toString() ?? 'pending';
    final showStatus = _existingProfile != null;
    final referralCode = _referralSummary?['code']?.toString() ?? '';
    final referralLink = _referralSummary?['link']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            ar: 'شراكة المروجين',
            en: 'Influencer partnership',
            ckb: 'هاوبەشی مروژەران',
            ku: 'Hevkariya influenceran',
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loadingProfile)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      ar: 'حوّل تأثيرك إلى دخل متكرر',
                      en: 'Turn your influence into recurring income',
                      ckb: 'کاریگەرییەکەت بگۆڕە بۆ داهاتی دووبارەبوو',
                      ku: 'Bandora xwe veguherîne berdêla dubare',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      ar: 'برنامج واضح بعمولات، كود خاص، وروابط تتبع دقيقة لكل مروج.',
                      en: 'A clear program with commissions, personal code, and accurate tracking links for each promoter.',
                      ckb:
                          'بەرنامەیەکی ڕوون بە کۆمسیۆن، کۆدی تایبەت، و بەستەری شوێنکەوتنی ورد بۆ هەر مروژەرێک.',
                      ku: 'Bernameyek zelal bi komîsyon, koda taybet û girêdanên şopandinê yên rast ji bo her belavker.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      ar: 'مستويات البرنامج',
                      en: 'Program tiers',
                      ckb: 'ئاستەکانی بەرنامە',
                      ku: 'Asta bernameyê',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _TierRow(
                    title: 'Starter',
                    subtitle: context.tr(
                      ar: 'عمولة 5% + خصم 10% لمتابعينك',
                      en: '5% commission + 10% discount for your audience',
                      ckb: '5% کۆمسیۆن + 10% داشکاندن بۆ شوێنکەوتووانت',
                      ku: '5% komîsyon + 10% daxistin ji bo temaşevanên te',
                    ),
                  ),
                  const Divider(),
                  _TierRow(
                    title: 'Pro',
                    subtitle: context.tr(
                      ar: 'عمولة 8% + أولوية بالحملات الشهرية',
                      en: '8% commission + priority in monthly campaigns',
                      ckb: '8% کۆمسیۆن + پێشەنگی لە کمپەینی مانگانە',
                      ku: '8% komîsyon + pêşengî di kampanyayên mehane de',
                    ),
                  ),
                  const Divider(),
                  _TierRow(
                    title: 'Elite',
                    subtitle: context.tr(
                      ar: 'عمولة 12% + مكافآت أداء إضافية',
                      en: '12% commission + extra performance bonuses',
                      ckb: '12% کۆمسیۆن + خەڵاتی زیاتر بەپێی ئەنجام',
                      ku: '12% komîsyon + xelatên performansê yên zêde',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      ar: 'ما الذي تحصل عليه؟',
                      en: 'What you get',
                      ckb: 'چی وەردەگریت؟',
                      ku: 'Tu çi distînî?',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      ar: '• كود خصم خاص باسمك\n• رابط تتبع مخصص\n• تقرير أداء أسبوعي\n• سحب أرباح دوري',
                      en: '• Personal discount code\n• Dedicated tracking link\n• Weekly performance report\n• Recurring payout',
                      ckb:
                          '• کۆدی داشکاندنی تایبەت\n• بەستەری شوێنکەوتنی تایبەت\n• ڕاپۆرتی ئەنجامی هەفتانە\n• وەرگرتنی قازانج بەردەوام',
                      ku: '• Koda daxistina taybet\n• Girêdana şopandinê ya taybet\n• Rapora performansê ya heftane\n• Dayîna pere ya domdar',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      ar: 'طريقة الانضمام',
                      en: 'How to join',
                      ckb: 'شێوازی بەشداریکردن',
                      ku: 'Awayê beşdarbûnê',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      ar: '1) أرسل حساباتك ومنصاتك\n2) نراجع الطلب خلال 48 ساعة\n3) تستلم كودك وروابطك وتبدأ الربح',
                      en: '1) Send your accounts and platforms\n2) We review your application within 48 hours\n3) Receive your code and links, then start earning',
                      ckb:
                          '1) هەژمار و پلاتفۆرمەکانت بنێرە\n2) لە ماوەی 48 کاتژمێر داواکاریەکەت دەبینین\n3) کۆد و بەستەرەکانت وەردەگریت و دەست بە قازانج دەکەیت',
                      ku: '1) Hesab û platformên xwe bişîne\n2) Em di 48 saetan de daxwaza te dinirxînin\n3) Koda xwe û girêdanan bistîne û dest bi berdêlê bike',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (showStatus) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${context.tr(ar: 'حالة طلبك', en: 'Your application status', ckb: 'دۆخی داواکارییەکەت', ku: 'Rewşa daxwaza te')}: ${_statusText(status)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (status == 'approved' && referralCode.trim().isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr(
                                ar: 'كودك الترويجي',
                                en: 'Your promo code',
                                ckb: 'کۆدی پڕۆمۆی تۆ',
                                ku: 'Koda promo ya te',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(referralCode),
                            if (referralLink.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SelectableText(
                                referralLink,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _copyToClipboard(
                                      referralCode,
                                      context.tr(
                                        watch: false,
                                        ar: 'الكود',
                                        en: 'Code',
                                        ckb: 'کۆد',
                                        ku: 'Kod',
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_all_outlined,
                                      size: 18),
                                  label: Text(
                                    context.tr(
                                      ar: 'نسخ الكود',
                                      en: 'Copy code',
                                      ckb: 'کۆپی کردنی کۆد',
                                      ku: 'Kopîkirina kodê',
                                    ),
                                  ),
                                ),
                                if (referralLink.trim().isNotEmpty)
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      _copyToClipboard(
                                        referralLink,
                                        context.tr(
                                          watch: false,
                                          ar: 'الرابط',
                                          en: 'Link',
                                          ckb: 'بەستەر',
                                          ku: 'Girêdan',
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.link, size: 18),
                                    label: Text(
                                      context.tr(
                                        ar: 'نسخ الرابط',
                                        en: 'Copy link',
                                        ckb: 'کۆپی کردنی بەستەر',
                                        ku: 'Kopîkirina girêdanê',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              ar: 'الاسم الكامل',
                              en: 'Full name',
                              ckb: 'ناوی تەواو',
                              ku: 'Navê tevahî',
                            ),
                          ),
                          validator: (value) {
                            final input = value?.trim() ?? '';
                            if (input.isEmpty) {
                              return context.tr(
                                watch: false,
                                ar: 'الاسم مطلوب',
                                en: 'Name is required',
                                ckb: 'ناو پێویستە',
                                ku: 'Nav pêwîste',
                              );
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _platform,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              ar: 'المنصة الأساسية',
                              en: 'Primary platform',
                              ckb: 'پلاتفۆرمی سەرەکی',
                              ku: 'Platforma bingehîn',
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'instagram',
                              child: Text('Instagram'),
                            ),
                            DropdownMenuItem(
                              value: 'tiktok',
                              child: Text('TikTok'),
                            ),
                            DropdownMenuItem(
                              value: 'youtube',
                              child: Text('YouTube'),
                            ),
                            DropdownMenuItem(
                              value: 'facebook',
                              child: Text('Facebook'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _platform = value);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _handleController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              ar: 'اسم الحساب (اختياري)',
                              en: 'Account handle (optional)',
                              ckb: 'ناوی هەژمار (ئیختیاری)',
                              ku: 'Navê hesabê (bijarte)',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _audienceSizeController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            labelText: context.tr(
                              ar: 'عدد المتابعين (اختياري)',
                              en: 'Audience size (optional)',
                              ckb: 'ژمارەی شوێنکەوتووان (ئیختیاری)',
                              ku: 'Hejmara temaşevanan (bijarte)',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: context.tr(
                              ar: 'رقم الهاتف للتواصل (اختياري)',
                              en: 'Contact phone (optional)',
                              ckb: 'ژمارەی تەلەفۆنی پەیوەندی (ئیختیاری)',
                              ku: 'Hejmara telefonê ya têkilî (bijarte)',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: (_submitting ||
                                    _loadingProfile ||
                                    _authRedirecting)
                                ? null
                                : _submitApplication,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.campaign_outlined),
                            label: Text(
                              context.tr(
                                ar: showStatus
                                    ? 'تحديث طلب الشراكة'
                                    : 'قدّم كشريك مروج',
                                en: showStatus
                                    ? 'Update application'
                                    : 'Apply as influencer partner',
                                ckb: showStatus
                                    ? 'نوێکردنەوەی داواکاری هاوبەشی'
                                    : 'داواکاری بکە وەک هاوبەشی مروژەر',
                                ku: showStatus
                                    ? 'Daxwaza hevkariyê nû bike'
                                    : 'Wek hevalbendê influencer daxwaz bike',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.verified_outlined, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(subtitle),
            ],
          ),
        ),
      ],
    );
  }
}
