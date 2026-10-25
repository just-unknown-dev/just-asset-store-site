import 'package:flutter/material.dart';
import 'package:just_asset_store_pages/content.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import '../../core/auth/store_auth.dart';
import '../../core/di/app_config.dart';
import '../../core/reports/reports.dart';
import '../publish/submission_tile.dart';
import '../shared/notice.dart';

/// The report form, for the package the item page named (`?item=<id>`).
class ReportPage extends StatelessWidget {
  const ReportPage({super.key, this.itemId});

  /// The package being reported, from the address.
  final String? itemId;

  @override
  Widget build(BuildContext context) {
    final auth = getIt<StoreAuth>();
    final id = itemId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHero(
          eyebrow: ReportCopy.eyebrow,
          title: ReportCopy.title,
          lede: ReportCopy.lede,
          compact: true,
          actions: [
            if (ReportsController.isItemId(id))
              SiteLink('Back to the package', StoreRoutes.item(id!)),
            const SiteLink('Content policy', StoreRoutes.policyPath),
          ],
        ),
        ContentColumn(
          child: Padding(
            padding: const EdgeInsets.only(bottom: JuSpacing.x16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: !ReportsController.isItemId(id)
                  ? const Notice(ReportCopy.noItem, tone: NoticeTone.warning)
                  : SignalBuilder<StoreUser?>(
                      signal: auth.user,
                      builder: (context, user, _) => user == null
                          ? SignInCard(auth: auth, body: ReportCopy.signInBody)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SignedInAs(auth: auth, user: user),
                                const SizedBox(height: JuSpacing.x4),
                                ReportForm(
                                  itemId: id!,
                                  controller: getIt<ReportsController>(),
                                ),
                              ],
                            ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Why, what happened, and send.
class ReportForm extends StatefulWidget {
  const ReportForm({super.key, required this.itemId, required this.controller});

  final String itemId;
  final ReportsController controller;

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final _text = TextEditingController();
  ReportReason? _reason;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.send(
        itemId: widget.itemId,
        reason: _reason!,
        text: _text.text,
      );
      if (mounted) setState(() => _sent = true);
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } on Object catch (e) {
      setState(() => _error = 'It could not be sent: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return const Notice(
        ReportCopy.sent,
        icon: Icons.check_circle_outline_rounded,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: 'Reporting ',
            children: [
              TextSpan(
                text: widget.itemId,
                style: juMonoStyle.copyWith(color: context.colors.onSurface),
              ),
              const TextSpan(text: '. What is wrong with it?'),
            ],
          ),
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: JuSpacing.x2),
        RadioGroup<ReportReason>(
          groupValue: _reason,
          onChanged: (r) => setState(() => _reason = r),
          child: Column(
            children: [
              for (final r in ReportReason.values)
                RadioListTile<ReportReason>(
                  value: r,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.label, style: context.text.bodyMedium),
                ),
            ],
          ),
        ),
        const SizedBox(height: JuSpacing.x2),
        TextField(
          controller: _text,
          maxLines: 5,
          maxLength: ReportCopy.detailsMax,
          decoration: const InputDecoration(
            labelText: ReportCopy.detailsLabel,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: JuSpacing.x4),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _busy || _reason == null ? null : _send,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.flag_rounded, size: 18),
            label: const Text('Send the report'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: JuSpacing.x4),
          Notice(_error!, tone: NoticeTone.error),
        ],
      ],
    );
  }
}
