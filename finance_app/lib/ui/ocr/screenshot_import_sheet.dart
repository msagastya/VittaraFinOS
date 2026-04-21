import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:vittara_fin_os/logic/ai/screenshot_parser.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Bottom sheet shown when user shares a payment screenshot to the app.
/// Returns [PaymentScreenshotData] on confirm, null on cancel.
class ScreenshotImportSheet extends StatefulWidget {
  final File imageFile;

  const ScreenshotImportSheet({required this.imageFile, super.key});

  static Future<PaymentScreenshotData?> show(
    BuildContext context,
    File imageFile,
  ) {
    return showCupertinoModalPopup<PaymentScreenshotData?>(
      context: context,
      builder: (_) => ScreenshotImportSheet(imageFile: imageFile),
    );
  }

  @override
  State<ScreenshotImportSheet> createState() => _ScreenshotImportSheetState();
}

class _ScreenshotImportSheetState extends State<ScreenshotImportSheet> {
  PaymentScreenshotData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  Future<void> _parse() async {
    try {
      final data = await ScreenshotParser.parse(widget.imageFile);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not read this screenshot.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Spacing.lg, Spacing.lg, Spacing.lg, Spacing.xl),
          child: _loading
              ? const _LoadingView()
              : _error != null
                  ? _ErrorView(error: _error!)
                  : _ResultView(
                      data: _data!,
                      imageFile: widget.imageFile,
                      onConfirm: () => Navigator.of(context).pop(_data),
                      onCancel: () => Navigator.of(context).pop(null),
                    ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(error,
            style: TextStyle(color: AppStyles.loss(context)),
            textAlign: TextAlign.center),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final PaymentScreenshotData data;
  final File imageFile;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ResultView({
    required this.data,
    required this.imageFile,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppStyles.getSecondaryTextColor(context)
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),

        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(imageFile,
                  width: 64, height: 64, fit: BoxFit.cover),
            ),
            const SizedBox(width: Spacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _appLabel(data.app),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
                Text(
                  data.amount != null
                      ? '₹${data.amount!.toStringAsFixed(0)}'
                      : 'Amount not found',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),

        if (data.recipient != null)
          _Field('To', data.recipient!, context),
        if (data.date != null)
          _Field('Date',
              '${data.date!.day}/${data.date!.month}/${data.date!.year}',
              context),
        if (data.upiRef != null)
          _Field('UPI Ref', data.upiRef!, context),

        const SizedBox(height: Spacing.xl),

        if (!data.hasMinimumData)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Text(
              'Could not extract amount — please fill it manually.',
              style:
                  TextStyle(fontSize: 13, color: AppStyles.loss(context)),
            ),
          ),

        Row(
          children: [
            Expanded(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(10),
                onPressed: onCancel,
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              flex: 2,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: AppStyles.aetherTeal,
                borderRadius: BorderRadius.circular(10),
                onPressed: onConfirm,
                child: const Text(
                  'Import',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _Field(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
                fontSize: 13,
                color: AppStyles.getSecondaryTextColor(context)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _appLabel(PaymentApp app) {
    switch (app) {
      case PaymentApp.gpay: return 'Google Pay';
      case PaymentApp.phonepe: return 'PhonePe';
      case PaymentApp.paytm: return 'Paytm';
      case PaymentApp.cred: return 'CRED';
      case PaymentApp.bhim: return 'BHIM';
      case PaymentApp.other: return 'Payment Screenshot';
    }
  }
}
