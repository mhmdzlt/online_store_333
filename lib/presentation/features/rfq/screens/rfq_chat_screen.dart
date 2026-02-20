import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/datasources/remote/supabase_rfq_datasource.dart';

class RfqChatScreen extends StatefulWidget {
  const RfqChatScreen({
    super.key,
    required this.requestNumber,
    required this.sellerId,
    required this.accessToken,
    required this.sellerName,
  });

  final String requestNumber;
  final String sellerId;
  final String accessToken;
  final String sellerName;

  @override
  State<RfqChatScreen> createState() => _RfqChatScreenState();
}

class _RfqChatScreenState extends State<RfqChatScreen> {
  final _ds = SupabaseRfqDataSource();
  final _controller = TextEditingController();

  Timer? _poller;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _load();
    _poller = Timer.periodic(const Duration(seconds: 3), (_) {
      _load(silent: true);
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final list = await _ds.listMessagesPublic(
        requestNumber: widget.requestNumber,
        accessToken: widget.accessToken,
        sellerId: widget.sellerId,
      );
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      await _ds.sendMessagePublic(
        requestNumber: widget.requestNumber,
        accessToken: widget.accessToken,
        sellerId: widget.sellerId,
        message: text,
      );
      _controller.clear();
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr(watch: false, ar: 'فشل الإرسال', en: 'Send failed', ckb: 'ناردن سەرکەوتوو نەبوو', ku: 'Şandin bi ser neket')}: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.tr(ar: 'شات مع', en: 'Chat with', ckb: 'چات لەگەڵ', ku: 'Chat bi')} ${widget.sellerName}',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: context.tr(
              ar: 'تحديث',
              en: 'Refresh',
              ckb: 'نوێکردنەوە',
              ku: 'Nûkirin',
            ),
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          final role = m['sender_role']?.toString() ?? '';
                          final msg = m['message']?.toString() ?? '';
                          final isMe = role == 'customer';

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 320),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.blue.withValues(alpha: 0.12)
                                    : Colors.grey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(msg),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: context.tr(
                          ar: 'اكتب رسالة...',
                          en: 'Type a message...',
                          ckb: 'نامەیەک بنووسە...',
                          ku: 'Peyamek binivîse...',
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
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
