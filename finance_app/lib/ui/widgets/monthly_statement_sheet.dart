import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/services/monthly_statement_service.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

/// Shows a bottom sheet with year → month two-step picker.
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
  /// null → show year picker; non-null → show months for that year
  int? _selectedYear;

  /// Key: 'YYYY-MM', value: true while generating
  final Map<String, bool> _loading = {};

  bool get _isAnyLoading => _loading.values.any((v) => v);

  /// Returns years from earliest transaction year to current year (inclusive),
  /// always showing at least the current and previous year.
  List<int> _availableYears(BuildContext ctx) {
    final txCtrl = ctx.read<TransactionsController>();
    final now = DateTime.now();
    int earliest = now.year - 1;
    if (txCtrl.transactions.isNotEmpty) {
      final minYear = txCtrl.transactions
          .map((t) => t.dateTime.year)
          .reduce((a, b) => a < b ? a : b);
      if (minYear < earliest) earliest = minYear;
    }
    return List.generate(now.year - earliest + 1, (i) => now.year - i);
  }

  Future<void> _generate(BuildContext ctx, int year, int month) async {
    final key = '$year-$month';
    setState(() => _loading[key] = true);
    try {
      final txCtrl = ctx.read<TransactionsController>();
      final acCtrl = ctx.read<AccountsController>();
      final invCtrl = ctx.read<InvestmentsController>();
      final lbCtrl = ctx.read<LendingBorrowingController>();
      final goalCtrl = ctx.read<GoalsController>();
      final budgetCtrl = ctx.read<BudgetsController>();

      Uint8List? iconBytes;
      try {
        final data = await rootBundle.load('assets/app_icon.png');
        iconBytes = data.buffer.asUint8List();
      } catch (_) {}

      final file = await MonthlyStatementService.build(
        year: year,
        month: month,
        allTransactions: txCtrl.transactions,
        accounts: acCtrl.accounts,
        investments: invCtrl.investments,
        lendingRecords: lbCtrl.records,
        appIconBytes: iconBytes,
        goals: goalCtrl.goals,
        budgets: budgetCtrl.budgets,
      );

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'VittaraFinOS Monthly Statement — ${_monthLabel(DateTime(year, month))}',
      );
    } catch (e, st) {
      debugPrint('MonthlyStatement error: $e\n$st');
      if (mounted) toast.showError('Failed to generate statement: $e');
    } finally {
      if (mounted) setState(() => _loading.remove(key));
    }
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  static const _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : Colors.white;

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
                  // Back button (visible when a year is selected)
                  if (_selectedYear != null)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: _isAnyLoading ? null : () => setState(() => _selectedYear = null),
                      child: Icon(
                        CupertinoIcons.chevron_left,
                        size: 20,
                        color: _isAnyLoading
                            ? AppStyles.getSecondaryTextColor(context)
                            : const Color(0xFF00B890),
                      ),
                    )
                  else
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
                      child: const Icon(CupertinoIcons.doc_text_fill, color: Colors.white, size: 18),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedYear != null
                              ? '$_selectedYear'
                              : 'Monthly Statement',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                        Text(
                          _selectedYear != null
                              ? 'Select a month to download'
                              : 'Select a year to get started',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
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

            // Content — year picker or month grid
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _selectedYear == null
                  ? _buildYearPicker(context, isDark)
                  : _buildMonthGrid(context, isDark, _selectedYear!),
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

  Widget _buildYearPicker(BuildContext context, bool isDark) {
    final years = _availableYears(context);
    final now = DateTime.now();

    return ConstrainedBox(
      key: const ValueKey('years'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: years.length,
        separatorBuilder: (_, __) => Divider(
          color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFEEEEEE),
          height: 1,
          indent: 20,
          endIndent: 20,
        ),
        itemBuilder: (ctx, i) {
          final year = years[i];
          final isCurrent = year == now.year;
          return InkWell(
            onTap: () => setState(() => _selectedYear = year),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFF00B890).withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '$year',
                        style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? const Color(0xFF00B890)
                              : AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$year',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                        if (isCurrent)
                          Text(
                            'Current year',
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF00B890),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthGrid(BuildContext context, bool isDark, int year) {
    final now = DateTime.now();

    return ConstrainedBox(
      key: ValueKey('months-$year'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.52,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
          ),
          itemCount: 12,
          itemBuilder: (ctx, i) {
            final month = i + 1;
            final isCurrent = year == now.year && month == now.month;
            final isFuture = year > now.year ||
                (year == now.year && month > now.month);
            final key = '$year-$month';
            final isLoading = _loading[key] == true;
            final isDisabled = _isAnyLoading && !isLoading;

            return GestureDetector(
              onTap: (isFuture || isDisabled) ? null : () => _generate(ctx, year, month),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF00B890).withValues(alpha: 0.15)
                      : isFuture
                          ? (isDark ? const Color(0xFF111111) : const Color(0xFFF9F9F9))
                          : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF2F2F2)),
                  borderRadius: BorderRadius.circular(12),
                  border: isCurrent
                      ? Border.all(color: const Color(0xFF00B890).withValues(alpha: 0.4), width: 1)
                      : null,
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _shortMonths[i],
                            style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isFuture || isDisabled
                                  ? AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.35)
                                  : isCurrent
                                      ? const Color(0xFF00B890)
                                      : AppStyles.getTextColor(context),
                            ),
                          ),
                          if (isCurrent)
                            Text(
                              'Now',
                              style: TextStyle(
                                fontSize: 9,
                                color: const Color(0xFF00B890),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else if (!isFuture)
                            Icon(
                              CupertinoIcons.arrow_down_circle,
                              size: 12,
                              color: isDisabled
                                  ? AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.25)
                                  : AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.5),
                            ),
                        ],
                      ),
                    ),
                    if (isLoading)
                      const Positioned.fill(
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CupertinoActivityIndicator(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
