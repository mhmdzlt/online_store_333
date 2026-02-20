import 'package:flutter/material.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../utils/local_storage.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';

class RfqMyRequestsScreen extends StatefulWidget {
  const RfqMyRequestsScreen({super.key});

  @override
  State<RfqMyRequestsScreen> createState() => _RfqMyRequestsScreenState();
}

class _RfqMyRequestsScreenState extends State<RfqMyRequestsScreen> {
  late Future<List<Map<String, String>>> _future;

  @override
  void initState() {
    super.initState();
    _future = LocalStorage.getRfqRequests();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = LocalStorage.getRfqRequests();
    });
  }

  void _openCreate() async {
    await NavigationHelpers.push(context, RouteNames.rfqCreate);
    await _refresh();
  }

  void _openOffers(String requestNumber) {
    NavigationHelpers.push(context, RouteNames.rfqOffersPath(requestNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            ar: 'طلبات التسعير',
            en: 'Quotation requests',
            ckb: 'داواکارییەکانی نرخ',
            ku: 'Daxwazên bihayê',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: context.tr(
              ar: 'طلب جديد',
              en: 'New request',
              ckb: 'داواکاری نوێ',
              ku: 'Daxwaza nû',
            ),
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.request_quote_outlined),
        label: Text(
          context.tr(
            ar: 'طلب جديد',
            en: 'New request',
            ckb: 'داواکاری نوێ',
            ku: 'Daxwaza nû',
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr(
                    ar: 'لا توجد طلبات بعد. اضغط "طلب جديد" لبدء طلب تسعير.',
                    en: 'No requests yet. Tap "New request" to start.',
                    ckb:
                        'هێشتا هیچ داواکارییەک نییە. کرتە لە "داواکاری نوێ" بکە بۆ دەستپێکردن.',
                    ku: 'Hêj daxwaz tune ye. Ji bo destpêkirinê li "Daxwaza nû" bitikîne.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final item = list[index];
                final requestNumber = item['requestNumber'] ?? '';
                final createdAt = item['createdAt'] ?? '';

                return ListTile(
                  onTap: () => _openOffers(requestNumber),
                  leading: const Icon(Icons.receipt_long),
                  title: Text(requestNumber),
                  subtitle: createdAt.isEmpty
                      ? null
                      : Text(
                          '${context.tr(ar: 'تاريخ الإنشاء', en: 'Created at', ckb: 'بەرواری دروستبوون', ku: 'Dîroka çêbûnê')}: $createdAt',
                        ),
                  trailing: const Icon(Icons.chevron_left),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
