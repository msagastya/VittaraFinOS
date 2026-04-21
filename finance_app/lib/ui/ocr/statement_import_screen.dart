import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:image_picker/image_picker.dart';
import 'package:vittara_fin_os/logic/ai/statement_ocr_parser.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Multi-page bank statement import: scan → bulk review → confirm selected rows.
class StatementImportScreen extends StatefulWidget {
  const StatementImportScreen({super.key});

  static Future<List<StatementRow>?> show(BuildContext context) {
    return Navigator.of(context).push<List<StatementRow>?>(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (_) => const StatementImportScreen(),
      ),
    );
  }

  @override
  State<StatementImportScreen> createState() => _StatementImportScreenState();
}

class _StatementImportScreenState extends State<StatementImportScreen> {
  final _picker = ImagePicker();
  List<StatementRow>? _rows;
  bool _scanning = false;
  String? _error;

  Future<void> _pickAndScan() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2048,
      );
      if (xfile == null) return;
      setState(() {
        _scanning = true;
        _error = null;
        _rows = null;
      });
      final rows = await StatementOcrParser.parse(File(xfile.path));
      setState(() {
        _rows = rows;
        _scanning = false;
      });
      if (rows.isEmpty) {
        setState(() => _error = 'No transactions found. Try a clearer image.');
      }
    } catch (e) {
      setState(() {
        _scanning = false;
        _error = 'Could not read this image.';
      });
    }
  }

  void _toggleRow(int index) {
    setState(() => _rows![index].isSelected = !_rows![index].isSelected);
  }

  void _selectAll() => setState(() {
        for (final r in _rows!) r.isSelected = true;
      });

  void _deselectAll() => setState(() {
        for (final r in _rows!) r.isSelected = false;
      });

  void _import() {
    final selected = _rows!.where((r) => r.isSelected).toList();
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _rows?.where((r) => r.isSelected).length ?? 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackgroundColor(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppStyles.getBackgroundColor(context),
        middle: const Text('Import Statement'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        trailing: _rows != null && selectedCount > 0
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _import,
                child: Text(
                  'Import ($selectedCount)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : null,
      ),
      child: SafeArea(
        child: _scanning
            ? const Center(child: CupertinoActivityIndicator())
            : _rows == null
                ? _buildPrompt(context)
                : _buildReview(context),
      ),
    );
  }

  Widget _buildPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.doc_text_viewfinder,
            size: 64,
            color: AppStyles.getSecondaryTextColor(context),
          ),
          const SizedBox(height: Spacing.xl),
          Text(
            'Scan a bank statement page\nto import transactions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppStyles.getTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Works with HDFC, SBI, ICICI, Axis, Kotak',
            style: TextStyle(
              fontSize: 13,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: Spacing.md),
            Text(
              _error!,
              style: TextStyle(fontSize: 13, color: AppStyles.loss(context)),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: Spacing.xxxl),
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(12),
            onPressed: _pickAndScan,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.camera_fill, size: 18),
                SizedBox(width: 8),
                Text('Scan Statement'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final rows = _rows!;
    return Column(
      children: [
        // Select all / none bar
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.sm),
          child: Row(
            children: [
              Text(
                '${rows.length} transactions found',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _selectAll,
                child: const Text('All', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: Spacing.md),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _deselectAll,
                child: const Text('None', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            itemCount: rows.length,
            itemBuilder: (context, i) => _buildRow(context, rows[i], i),
          ),
        ),
        // Scan more button
        Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _pickAndScan,
            child: Text(
              '+ Scan another page',
              style: TextStyle(
                fontSize: 14,
                color: AppStyles.aetherTeal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, StatementRow row, int index) {
    final color = row.isExpense ? AppStyles.loss(context) : AppStyles.gain(context);
    final prefix = row.isExpense ? '-' : '+';
    final amount = row.amount;

    return GestureDetector(
      onTap: () => _toggleRow(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.sm),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: row.isSelected
                ? AppStyles.aetherTeal.withValues(alpha: 0.4)
                : AppStyles.getCardColor(context),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Icon(
              row.isSelected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              size: 20,
              color: row.isSelected
                  ? AppStyles.aetherTeal
                  : AppStyles.getSecondaryTextColor(context),
            ),
            const SizedBox(width: Spacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppStyles.getTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${row.date.day}/${row.date.month}/${row.date.year}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$prefix₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
