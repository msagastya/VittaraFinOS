import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/services/monthly_statement_service.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

/// Shows a bottom sheet listing the last 12 months.
/// Tapping a month generates the comprehensive PDF statement and shares it.
void showMonthlyStatementSheet(BuildContext context) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => const _MonthlyStatementSheet(),
  );
}

class _MonthlyStatementSheet extends StatefulWidget {
  const _MonthlyStatementSheet();

  @override
  State<_MonthlyStatementSheet> createState() => _MonthlyStatementSheetState();
}

class _MonthlyStatementSheetState extends State<_MonthlyStatementSheet> {
  // null means nothing is loading; non-null is the index being generated
  int? _loadingIndex;

  // Build last 12 months starting from current month going backwards
  static List<DateTime> _months() {
    final now = DateTime.now();
    return List.generate(12, (i) {
      int m = now.month - i;
      int y = now.year;
      while (m <= 0) {
        m += 12;
        y -= 1;
      }
      return DateTime(y, m);
    });
  }

  Future<void> _generate(BuildContext ctx, DateTime month, int idx) async {
    setState(() => _loadingIndex = idx);
    try {
      final txCtrl = ctx.read<TransactionsController>();
      final acCtrl = ctx.read<AccountsController>();
      final invCtrl = ctx.read<InvestmentsController>();
      final lbCtrl = ctx.read<LendingBorrowingController>();

      // Load real app icon for PDF branding
      Uint8List? iconBytes;
      try {
        final data = await rootBundle.load('assets/app_icon.png');
        iconBytes = data.buffer.asUint8List();
      } catch (_) {}

      final file = await MonthlyStatementService.build(
        year: month.year,
        month: month.month,
        allTransactions: txCtrl.transactions,
        accounts: acCtrl.accounts,
        investments: invCtrl.investments,
        lendingRecords: lbCtrl.records,
        appIconBytes: iconBytes,
      );

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'VittaraFinOS Monthly Statement — ${_monthLabel(month)}',
      );
    } catch (e) {
      if (mounted) toast.showError('Failed to generate statement: $e');
    } finally {
      if (mounted) setState(() => _loadingIndex = null);
    }
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : Colors.white;
    final months = _months();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B890), Color(0xFF7B5CEF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.doc_richtext, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Statement',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      Text(
                        'Complete PDF — 20–50 pages',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Divider(
              color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFEEEEEE),
              height: 1,
            ),

            // Month list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: months.length,
                separatorBuilder: (_, __) => Divider(
                  color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFEEEEEE),
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                itemBuilder: (ctx, i) {
                  final m = months[i];
                  final isLoading = _loadingIndex == i;
                  final isAnyLoading = _loadingIndex != null;
                  final isCurrentMonth = m.year == DateTime.now().year && m.month == DateTime.now().month;

                  return _MonthTile(
                    month: m,
                    label: _monthLabel(m),
                    isCurrentMonth: isCurrentMonth,
                    isLoading: isLoading,
                    disabled: isAnyLoading && !isLoading,
                    onTap: isAnyLoading ? null : () => _generate(ctx, m, i),
                  );
                },
              ),
            ),

            // Footer note
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'Includes all accounts, investments, categories, merchants, lending & borrowing records.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  final DateTime month;
  final String label;
  final bool isCurrentMonth;
  final bool isLoading;
  final bool disabled;
  final VoidCallback? onTap;

  const _MonthTile({
    required this.month,
    required this.label,
    required this.isCurrentMonth,
    required this.isLoading,
    required this.disabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = disabled
        ? AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.4)
        : AppStyles.getTextColor(context);

    return InkWell(
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Month icon / number badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCurrentMonth
                    ? const Color(0xFF00B890).withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _shortMonth(month.month),
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCurrentMonth
                          ? const Color(0xFF00B890)
                          : AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                  Text(
                    '${month.year}',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isCurrentMonth
                          ? const Color(0xFF00B890)
                          : AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (isCurrentMonth)
                    Text(
                      'Current month',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF00B890),
                      ),
                    ),
                ],
              ),
            ),

            // Action area
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CupertinoActivityIndicator(),
              )
            else
              Icon(
                CupertinoIcons.arrow_down_circle,
                size: 22,
                color: disabled
                    ? AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.3)
                    : const Color(0xFF00B890),
              ),
          ],
        ),
      ),
    );
  }

  static String _shortMonth(int m) {
    const s = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    return s[m - 1];
  }
}
