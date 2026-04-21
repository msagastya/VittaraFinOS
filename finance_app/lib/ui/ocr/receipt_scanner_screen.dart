import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, FloatingActionButton;
import 'package:image_picker/image_picker.dart';
import 'package:vittara_fin_os/logic/ai/receipt_ocr_parser.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Launches camera or gallery to scan a receipt and extracts transaction data.
/// Returns [ReceiptExtraction] or null on cancel.
class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  static Future<ReceiptExtraction?> show(BuildContext context) {
    return Navigator.of(context).push<ReceiptExtraction?>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ReceiptScannerScreen(),
      ),
    );
  }

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final _picker = ImagePicker();
  ReceiptExtraction? _result;
  File? _imageFile;
  bool _scanning = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
      );
      if (xfile == null) return;
      final file = File(xfile.path);
      setState(() {
        _imageFile = file;
        _scanning = true;
        _error = null;
        _result = null;
      });
      final extraction = await ReceiptOcrParser.parse(file);
      setState(() {
        _result = extraction;
        _scanning = false;
      });
    } catch (e) {
      setState(() {
        _scanning = false;
        _error = 'Could not read this image. Try a clearer photo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackgroundColor(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppStyles.getBackgroundColor(context),
        middle: const Text('Scan Receipt'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        trailing: _result != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(_result),
                child: const Text(
                  'Use',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: _imageFile == null
            ? _buildPickerPrompt(context)
            : _buildResultView(context),
      ),
    );
  }

  Widget _buildPickerPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.camera_viewfinder,
            size: 64,
            color: AppStyles.getSecondaryTextColor(context),
          ),
          const SizedBox(height: Spacing.xl),
          Text(
            'Scan a receipt to\nauto-fill a transaction',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppStyles.getTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.xxxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PickerButton(
                icon: CupertinoIcons.camera_fill,
                label: 'Camera',
                onTap: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(width: Spacing.xl),
              _PickerButton(
                icon: CupertinoIcons.photo_on_rectangle,
                label: 'Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _imageFile!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: Spacing.lg),

          if (_scanning)
            const Center(child: CupertinoActivityIndicator())
          else if (_error != null)
            _buildError(context)
          else if (_result != null)
            _buildExtraction(context),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Text(
        _error!,
        style: TextStyle(color: AppStyles.loss(context)),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildExtraction(BuildContext context) {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Extracted Data',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context))),
          const SizedBox(height: Spacing.md),
          if (r.merchantName != null)
            _Row('Merchant', r.merchantName!, context),
          if (r.totalAmount != null)
            _Row('Amount', '₹${r.totalAmount!.toStringAsFixed(2)}', context),
          if (r.date != null)
            _Row('Date',
                '${r.date!.day}/${r.date!.month}/${r.date!.year}', context),
          const SizedBox(height: Spacing.md),
          if (!r.hasMinimumData)
            Text(
              'Could not extract enough data. Try a clearer image.',
              style:
                  TextStyle(fontSize: 13, color: AppStyles.loss(context)),
            ),
          if (r.hasMinimumData)
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(10),
                onPressed: () => Navigator.of(context).pop(r),
                child: const Text('Use This'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _Row(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.getSecondaryTextColor(context))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getTextColor(context))),
        ],
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppStyles.aetherTeal.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppStyles.aetherTeal, size: 32),
            const SizedBox(height: Spacing.sm),
            Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.getTextColor(context)),
            ),
          ],
        ),
      ),
    );
  }
}
