import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/localization/language_text.dart';
import '../../../../data/models/notification/notification_model.dart';
import '../../../../data/repositories/notification_repository.dart';
import '../../../../core/services/tracking_service.dart';
import 'package:design_system/design_system.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  late final NotificationRepository _notificationRepository;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _keyboardVisible = false;

  List<NotificationModel> _generalNotifications = [];
  bool _loadingGeneral = false;
  StreamSubscription<List<NotificationModel>>? _notificationsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationRepository = context.read<NotificationRepository>();
    TrackingService.instance.trackScreen('notifications');
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
        _searchController.clear();
        setState(() => _searchQuery = '');
      }
    });
    _loadGeneralNotifications();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationsSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _subscribeToNotifications() {
    _notificationsSub?.cancel();
    _notificationsSub =
        _notificationRepository.streamGeneralNotifications().listen((data) {
      if (!mounted) return;
      setState(() => _generalNotifications = data);
    });
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final isVisible = bottomInset > 0.0;
    if (_keyboardVisible && !isVisible && _searchQuery.isNotEmpty) {
      _searchController.clear();
      setState(() => _searchQuery = '');
    }
    _keyboardVisible = isVisible;
  }

  Widget _buildSearchField() {
    return AppSearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: context.tr(
        ar: 'ابحث في الإشعارات...',
        en: 'Search notifications...',
        ckb: 'لە ئاگادارکردنەوەکان بگەڕێ...',
        ku: 'Di agahdariyan de bigere...',
      ),
      onChanged: (value) {
        setState(() => _searchQuery = value);
        TrackingService.instance.trackSearch(
          screen: 'notifications',
          query: value,
        );
      },
      onClear: () {
        _searchController.clear();
        setState(() => _searchQuery = '');
      },
    );
  }

  Future<void> _loadGeneralNotifications() async {
    setState(() => _loadingGeneral = true);
    try {
      final result = await _notificationRepository.fetchGeneralNotifications();
      if (mounted) {
        setState(() => _generalNotifications = result);
      }
    } catch (e, st) {
      debugPrint('Error loading general notifications: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _loadingGeneral = false);
      }
    }
  }

  Future<void> _refresh() async {
    await _loadGeneralNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            ar: 'الإشعارات',
            en: 'Notifications',
            ckb: 'ئاگادارکردنەوەکان',
            ku: 'Agahdarî',
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildSearchField(),
            const SizedBox(height: 12),
            _buildNotificationSection(
              context,
              title: context.tr(
                ar: 'العروض العامة',
                en: 'General offers',
                ckb: 'پێشکەشکردنی گشتی',
                ku: 'Pêşkêşiyên giştî',
              ),
              notifications: _generalNotifications,
              isLoading: _loadingGeneral,
              emptyMessage: context.tr(
                ar: 'لا توجد عروض حالياً.',
                en: 'No offers right now.',
                ckb: 'ئێستا هیچ پێشکەشێک نییە.',
                ku: 'Niha tu pêşkêş tune ye.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection(
    BuildContext context, {
    required String title,
    required List<NotificationModel> notifications,
    required bool isLoading,
    required String emptyMessage,
    bool showTypeChip = false,
  }) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = notifications.where((n) {
      if (query.isEmpty) return true;
      final title = n.title.toLowerCase();
      final body = n.body.toLowerCase();
      return title.contains(query) || body.contains(query);
    }).toList();

    if (isLoading) {
      return const AppLoading(padding: EdgeInsets.symmetric(vertical: 16));
    }

    if (notifications.isEmpty) {
      return AppEmptyState(message: emptyMessage);
    }

    if (filtered.isEmpty) {
      return AppEmptyState(
        message: context.tr(
          ar: 'لا توجد نتائج مطابقة للبحث.',
          en: 'No results match your search.',
          ckb: 'هیچ ئەنجامێک لەگەڵ گەڕانەکەت ناگونجێت.',
          ku: 'Tu encam bi lêgerîna te re li hev nayê.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...filtered.map((n) => _buildNotificationCard(n, showTypeChip)),
      ],
    );
  }

  Widget _buildNotificationCard(
    NotificationModel notification,
    bool showTypeChip,
  ) {
    final title = notification.title.isNotEmpty
        ? notification.title
        : context.tr(
            ar: 'بدون عنوان',
            en: 'Untitled',
            ckb: 'بێ سەردێڕ',
            ku: 'Bê sernav',
          );
    final body = notification.body;
    final createdAt = notification.createdAt;
    final createdLabel = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : '';
    final targetType = notification.targetType ?? 'all';
    final chipLabel = targetType == 'phone'
        ? context.tr(ar: 'خاص', en: 'Private', ckb: 'تایبەت', ku: 'Taybet')
        : context.tr(ar: 'عام', en: 'Public', ckb: 'گشتی', ku: 'Giştî');
    final record = notification.toMap();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: () {
          TrackingService.instance.trackEvent(
            eventName: 'notification_opened',
            eventCategory: 'notification',
            screen: 'notifications_list',
            metadata: record,
          );
          NotificationService.instance.handleNotificationRecord(record);
        },
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            if (showTypeChip)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Chip(
                  label: Text(chipLabel),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: targetType == 'phone'
                      ? Colors.purple.shade50
                      : Colors.blueGrey.shade50,
                ),
              ),
          ],
        ),
        trailing: createdLabel.isNotEmpty ? Text(createdLabel) : null,
      ),
    );
  }
}
