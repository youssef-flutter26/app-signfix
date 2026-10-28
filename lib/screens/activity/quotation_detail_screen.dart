import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_theme.dart';
import '../../core/app_utils.dart';
import '../../services/api_client.dart';

Set<String> quotationActionsFor(Map<String, dynamic> quotation) {
  final actions = quotation['availableActions'];
  if (actions is! List) return const {};
  return actions.map((action) => action.toString()).toSet();
}

class QuotationDetailScreen extends StatefulWidget {
  const QuotationDetailScreen({
    super.key,
    required this.api,
    required this.quotationNo,
  });

  final ApiClient api;
  final String quotationNo;

  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  late Future<Map<String, dynamic>> _quotationFuture;
  bool _actionPending = false;
  bool _downloadingPdf = false;

  @override
  void initState() {
    super.initState();
    _quotationFuture = _loadQuotation();
  }

  Future<Map<String, dynamic>> _loadQuotation() async {
    final response = await widget.api.getQuotation(widget.quotationNo);
    final data = response['data'];
    return Map<String, dynamic>.from(data is Map ? data : response);
  }

  Future<void> _refresh() async {
    final future = _loadQuotation();
    setState(() => _quotationFuture = future);
    await future.then<void>((_) {}, onError: (Object _) {});
  }

  Future<String?> _confirmAction(String action) async {
    final notes = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final requiresNotes = action != 'approve';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(switch (action) {
            'approve' => 'Approve quotation?',
            'reject' => 'Reject quotation?',
            _ => 'Request changes?',
          }),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (action) {
                  'approve' =>
                    'Confirm that you want to proceed with this quotation.',
                  'reject' => 'Tell us why you are rejecting this quotation.',
                  _ => 'Describe the changes you need.',
                }),
                if (requiresNotes) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: notes,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => updateDialog(() {}),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please add notes.'
                        : null,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: requiresNotes && notes.text.trim().isEmpty
                  ? null
                  : () {
                      if (requiresNotes && !formKey.currentState!.validate()) {
                        return;
                      }
                      Navigator.pop(dialogContext, notes.text.trim());
                    },
              child: Text(action == 'approve' ? 'Approve' : 'Confirm'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
    return result;
  }

  Future<void> _performAction(String action) async {
    final notes = await _confirmAction(action);
    if (notes == null || !mounted) return;
    setState(() => _actionPending = true);
    try {
      await widget.api.quotationAction(
        widget.quotationNo,
        action: action,
        notes: notes,
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloadingPdf = true);
    try {
      final bytes = await widget.api.quotationPdf(widget.quotationNo);
      final directory = await getApplicationDocumentsDirectory();
      final safeName =
          widget.quotationNo.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file =
          File('${directory.path}${Platform.pathSeparator}$safeName.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download quotation: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  Color _statusColor(String status) => switch (status) {
        'approved' => AppColors.success,
        'rejected' || 'expired' => AppColors.danger,
        'sent' || 'viewed' => AppColors.warning,
        _ => AppColors.textMuted,
      };

  Widget _amountRow(String label, Object? amount, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  )),
            ),
            Text(money(amount),
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                )),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          title: const Text('Quotation Details'),
          backgroundColor: AppColors.appBar,
          foregroundColor: AppColors.navy,
          surfaceTintColor: Colors.transparent,
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _quotationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Could not load this quotation.'),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ]),
              );
            }

            final quotation = snapshot.data ?? const <String, dynamic>{};
            final actions = quotationActionsFor(quotation);
            final items = quotation['items'] is List
                ? quotation['items'] as List
                : const [];
            final status = quotation['status']?.toString() ?? 'unknown';
            return RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              quotation['quotationNo']?.toString() ??
                                  widget.quotationNo,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(humanize(status)),
                            backgroundColor:
                                _statusColor(status).withValues(alpha: .12),
                            labelStyle: TextStyle(
                              color: _statusColor(status),
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide.none,
                          ),
                        ]),
                        Text('Order ${quotation['orderNo'] ?? ''}',
                            style: const TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        Text(
                            'Valid until ${quotation['validUntil'] ?? 'Not specified'}',
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 12)),
                        if (quotation['issueDate'] != null)
                          Text('Issued ${quotation['issueDate']}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Items',
                            style: TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        for (final item in items.whereType<Map>()) ...[
                          Text(item['description']?.toString() ?? 'Item',
                              style: const TextStyle(
                                  color: AppColors.textBody,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          _amountRow(
                            '${item['quantity'] ?? 1} × ${money(item['unitPrice'])}',
                            item['lineTotal'],
                          ),
                          const Divider(height: 16),
                        ],
                        _amountRow('Subtotal', quotation['subtotal']),
                        _amountRow('Discount', quotation['discountAmount']),
                        _amountRow(
                            'Taxable amount', quotation['taxableAmount']),
                        _amountRow('GST (${quotation['gstPercentage'] ?? 0}%)',
                            quotation['gstAmount']),
                        const Divider(),
                        _amountRow('Final amount', quotation['finalAmount'],
                            bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (actions.contains('download'))
                    OutlinedButton.icon(
                      onPressed: _downloadingPdf ? null : _downloadPdf,
                      icon: _downloadingPdf
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Download quotation PDF'),
                    ),
                  for (final (action, label, icon) in const [
                    (
                      'approve',
                      'Approve quotation',
                      Icons.check_circle_outline
                    ),
                    ('request_changes', 'Request changes', Icons.edit_note),
                    ('reject', 'Reject quotation', Icons.cancel_outlined),
                  ])
                    if (actions.contains(action))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton.icon(
                          onPressed: _actionPending
                              ? null
                              : () => _performAction(action),
                          icon: Icon(icon),
                          label: Text(label),
                        ),
                      ),
                  if (_actionPending)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(color: AppColors.gold),
                    ),
                ],
              ),
            );
          },
        ),
      );
}
