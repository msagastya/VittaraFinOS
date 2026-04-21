import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/ai/statement_ocr_parser.dart';
import 'package:vittara_fin_os/logic/ai/voice_transaction_handler.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/transaction_account_adjuster.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/dashboard/quick_entry_sheet.dart';
import 'package:vittara_fin_os/ui/ocr/receipt_scanner_screen.dart';
import 'package:vittara_fin_os/ui/ocr/screenshot_import_sheet.dart';
import 'package:vittara_fin_os/ui/ocr/statement_import_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/voice/voice_overlay_widget.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';

/// Semi-transparent floating button that sits above the SMS button (or in its
/// place when SMS is off). Opens a bottom sheet with 4 AI-powered entry modes.
class AITrayButton extends StatelessWidget {
  const AITrayButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showAITray(context);
          },
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              // Almost transparent — just a ghost of a button
              color: AppStyles.isDarkMode(context)
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.15)
                  : const Color(0xFF6C63FF).withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: const Icon(
              CupertinoIcons.sparkles,
              color: Color(0xFF6C63FF),
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
      ],
    );
  }

  void _showAITray(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => _AITraySheet(rootContext: context),
    );
  }
}

// ── The sheet itself ─────────────────────────────────────────────────────────

class _AITraySheet extends StatelessWidget {
  final BuildContext rootContext;
  const _AITraySheet({required this.rootContext});

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final bg = isDark ? const Color(0xFF0D0D0D) : CupertinoColors.systemBackground;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                const Icon(CupertinoIcons.sparkles,
                    color: Color(0xFF6C63FF), size: 18),
                const SizedBox(width: 8),
                Text(
                  'AI Entry',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
              ],
            ),
          ),

          // 4 entries
          _AITrayRow(
            icon: CupertinoIcons.mic_fill,
            color: AppStyles.aetherTeal,
            label: 'Voice',
            subtitle: 'Say "₹500 for coffee" to log instantly',
            onTap: () async {
              Navigator.pop(context);
              final result = await VoiceOverlayWidget.show(rootContext);
              if (result != null && rootContext.mounted) {
                await VoiceTransactionHandler.handle(rootContext, result);
              }
            },
          ),
          _AITrayRow(
            icon: CupertinoIcons.camera_fill,
            color: const Color(0xFFFF6B6B),
            label: 'Scan Receipt',
            subtitle: 'Photo → auto-fill amount & merchant',
            onTap: () async {
              Navigator.pop(context);
              final extraction = await ReceiptScannerScreen.show(rootContext);
              if (extraction != null && rootContext.mounted) {
                showQuickEntrySheet(
                  rootContext,
                  initialAmount: extraction.totalAmount,
                  initialMerchant: extraction.merchantName,
                  initialDate: extraction.date,
                );
              }
            },
          ),
          _AITrayRow(
            icon: CupertinoIcons.photo_fill,
            color: const Color(0xFFFF9500),
            label: 'Payment Screenshot',
            subtitle: 'Import from GPay, PhonePe, Paytm, CRED…',
            onTap: () async {
              Navigator.pop(context);
              final picker = ImagePicker();
              final xfile = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 90,
              );
              if (xfile == null) return;
              if (!rootContext.mounted) return;
              final data =
                  await ScreenshotImportSheet.show(rootContext, File(xfile.path));
              if (data != null && rootContext.mounted) {
                showQuickEntrySheet(
                  rootContext,
                  initialAmount: data.amount,
                  initialMerchant: data.recipient,
                  initialDate: data.date,
                );
              }
            },
          ),
          _AITrayRow(
            icon: CupertinoIcons.doc_on_clipboard_fill,
            color: const Color(0xFF6C63FF),
            label: 'Import Statement',
            subtitle: 'Scan bank statement → batch import',
            isLast: true,
            onTap: () async {
              Navigator.pop(context);
              final rows = await StatementImportScreen.show(rootContext);
              if (rows != null && rows.isNotEmpty && rootContext.mounted) {
                await _importStatementRows(rootContext, rows);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _importStatementRows(
      BuildContext ctx, List<StatementRow> rows) async {
    final txController = ctx.read<TransactionsController>();
    final accountsController = ctx.read<AccountsController>();
    final paymentApps = ctx.read<PaymentAppsController>();

    final transactions = rows.asMap().entries.map((e) {
      final i = e.key;
      final row = e.value;
      final isCredit = row.credit != null && row.credit! > 0;
      final amount = isCredit ? row.credit! : (row.debit ?? 0);
      return Transaction(
        id: IdGenerator.next(),
        description: row.description.isNotEmpty
            ? row.description
            : (isCredit ? 'Credit' : 'Debit'),
        amount: amount,
        type: isCredit ? TransactionType.income : TransactionType.expense,
        dateTime: row.date.copyWith(
            hour: 23, minute: 59, second: i.clamp(0, 59)),
      );
    }).toList();

    await txController.addTransactionsBatch(transactions);
    for (final tx in transactions) {
      await TransactionAccountAdjuster.applyTransaction(
          accountsController, tx, paymentApps);
    }

    if (ctx.mounted) {
      showCupertinoDialog(
        context: ctx,
        barrierDismissible: true,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Import Complete'),
          content: Text(
              '${transactions.length} transaction${transactions.length == 1 ? '' : 's'} imported.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            ),
          ],
        ),
      );
    }
  }
}

// ── Row widget ───────────────────────────────────────────────────────────────

class _AITrayRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _AITrayRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 1,
              indent: 74,
              endIndent: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
        ],
      ),
    );
  }
}
