import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_model.dart';
import 'package:vittara_fin_os/ui/manage/lending_wizard.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class LendingBorrowingScreen extends StatefulWidget {
  const LendingBorrowingScreen({super.key});

  @override
  State<LendingBorrowingScreen> createState() => _LendingBorrowingScreenState();
}

class _LendingBorrowingScreenState extends State<LendingBorrowingScreen> {
  final AppLogger logger = AppLogger();
  int _selectedTab = 0; // 0 = I Lent, 1 = I Borrowed, 2 = Settled
  String _sortBy = 'date';
  bool _sortAscending = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Lending & Borrowing',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showSortSheet(),
          child: Icon(
            CupertinoIcons.arrow_up_arrow_down,
            color: AppStyles.getPrimaryColor(context),
            size: 20,
          ),
        ),
      ),
      child: Consumer<LendingBorrowingController>(
        builder: (context, controller, child) {
          final lentRecords = controller.getLentActiveRecords();
          final borrowedRecords = controller.getBorrowedActiveRecords();
          final settledRecords = controller.getSettledRecords();
          final rawRecords = _selectedTab == 0
              ? lentRecords
              : _selectedTab == 1
                  ? borrowedRecords
                  : settledRecords;
          final sortedRecords = List<LendingBorrowing>.from(rawRecords)
            ..sort((a, b) {
              int cmp;
              switch (_sortBy) {
                case 'amount':
                  cmp = a.amount.compareTo(b.amount);
                  break;
                case 'name':
                  cmp = a.personName
                      .toLowerCase()
                      .compareTo(b.personName.toLowerCase());
                  break;
                default: // 'date'
                  cmp = a.date.compareTo(b.date);
              }
              return _sortAscending ? cmp : -cmp;
            });
          final q = _searchQuery.toLowerCase();
          final displayRecords = q.isEmpty
              ? sortedRecords
              : sortedRecords
                  .where((r) =>
                      r.personName.toLowerCase().contains(q) ||
                      r.amount.toString().contains(q) ||
                      (r.description?.toLowerCase().contains(q) ?? false))
                  .toList();

          return Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    // Tab Selector
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTabTile(
                              context,
                              title: 'I Lent',
                              subtitle:
                                  '₹${controller.getTotalLent().toStringAsFixed(0)}',
                              selected: _selectedTab == 0,
                              color: AppStyles.accentBlue,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedTab = 0);
                              },
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: _buildTabTile(
                              context,
                              title: 'I Borrowed',
                              subtitle:
                                  '₹${controller.getTotalBorrowed().toStringAsFixed(0)}',
                              selected: _selectedTab == 1,
                              color: AppStyles.plasmaRed,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedTab = 1);
                              },
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                          Expanded(
                            child: _buildTabTile(
                              context,
                              title: 'Settled',
                              subtitle: '${settledRecords.length}',
                              selected: _selectedTab == 2,
                              color: SemanticColors.success,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedTab = 2);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: CupertinoSearchTextField(
                        controller: _searchController,
                        placeholder: 'Search by name or amount',
                        onChanged: (v) => setState(() => _searchQuery = v),
                        onSubmitted: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    // Records List
                    Expanded(
                      child: displayRecords.isEmpty
                          ? EmptyStateView(
                              icon: _searchQuery.isNotEmpty
                                  ? CupertinoIcons.search
                                  : _selectedTab == 2
                                      ? CupertinoIcons.checkmark_seal
                                      : CupertinoIcons.person_2_fill,
                              title: _searchQuery.isNotEmpty
                                  ? 'No results for "$_searchQuery"'
                                  : _selectedTab == 0
                                      ? 'No lending records yet'
                                      : _selectedTab == 1
                                          ? 'No borrowing records yet'
                                          : 'No settled records yet',
                              subtitle:
                                  _searchQuery.isEmpty && _selectedTab == 2
                                      ? 'Settled records will appear here.'
                                      : null,
                              showPulse: false,
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                HapticFeedback.mediumImpact();
                                await Provider.of<LendingBorrowingController>(
                                        context,
                                        listen: false)
                                    .loadRecords();
                              },
                              child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: displayRecords.length,
                              itemBuilder: (context, index) {
                                final record = displayRecords[index];
                                return StaggeredItem(
                                  index: index,
                                  child: _buildRecordCard(
                                      record, context, controller),
                                );
                              },
                            ),
                            ),
                    ),
                  ],
                ),
              ),
              // Add Button
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl,
                child: FadingFAB(
                  onPressed: () => _showLendingTypeModal(context),
                  color: SemanticColors.lending,
                  heroTag: 'lending_fab',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : AppStyles.getSecondaryTextColor(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: TypeScale.subhead,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? color
                      : AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? color
                      : AppStyles.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Sort By'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                if (_sortBy == 'date') {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = 'date';
                  _sortAscending = false;
                }
              });
            },
            child: Text(
                'Date${_sortBy == 'date' ? (_sortAscending ? ' (Oldest first)' : ' (Newest first) ✓') : ''}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                if (_sortBy == 'amount') {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = 'amount';
                  _sortAscending = false;
                }
              });
            },
            child: Text(
                'Amount${_sortBy == 'amount' ? (_sortAscending ? ' (Low to High)' : ' (High to Low) ✓') : ''}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                if (_sortBy == 'name') {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = 'name';
                  _sortAscending = true;
                }
              });
            },
            child: Text(
                'Person Name${_sortBy == 'name' ? (_sortAscending ? ' (A–Z) ✓' : ' (Z–A)') : ''}'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showLendingTypeModal(BuildContext context) {
    Navigator.of(context).push(
      FadeScalePageRoute(
        page: Builder(
          builder: (newContext) => _TransactionTypeWizard(
            onTypeSelected: (type) {
              Navigator.pop(newContext);
              _navigateToLendingWizard(context, type);
            },
          ),
        ),
      ),
    );
  }

  void _navigateToLendingWizard(BuildContext context, LendingType type) {
    Navigator.of(context).push(
      FadeScalePageRoute(
        page: LendingWizard(
          type: type,
          onSave: (record) {
            Provider.of<LendingBorrowingController>(context, listen: false)
                .addRecord(record);
            logger.info(
              'Added ${type == LendingType.lent ? "lent" : "borrowed"} record: ${record.personName}',
              context: 'LendingBorrowingScreen',
            );
          },
        ),
      ),
    );
  }

  void _showRecordActions(
    BuildContext context,
    LendingBorrowing record,
    LendingBorrowingController controller,
  ) {
    final isLent = record.type == LendingType.lent;
    final color = isLent ? AppStyles.accentBlue : AppStyles.plasmaRed;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          record.personName,
          style: TextStyle(
            fontSize: TypeScale.title3,
            fontWeight: FontWeight.w700,
          ),
        ),
        message: Text(
          '₹${record.amount.toStringAsFixed(0)} • ${isLent ? "Lent" : "Borrowed"}',
          style: TextStyle(
            fontSize: TypeScale.body,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showHistoryModal(context, record);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.clock, color: SemanticColors.info),
                SizedBox(width: Spacing.sm),
                const Text('View History'),
              ],
            ),
          ),
          if (!record.isSettled) ...[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showPayoffCalculator(context, record);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.chart_bar_circle,
                      color: CupertinoColors.systemPurple),
                  SizedBox(width: Spacing.sm),
                  const Text('Payoff Calculator'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showPartialPaymentModal(context, record, controller);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.arrow_up_down_circle,
                      color: SemanticColors.info),
                  SizedBox(width: Spacing.sm),
                  const Text('Add/Reduce Amount'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _navigateToEditWizard(context, record);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.pencil,
                      color: SemanticColors.getPrimary(context)),
                  SizedBox(width: Spacing.sm),
                  const Text('Edit Details'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _settleRecord(record, controller);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.checkmark_circle,
                      color: SemanticColors.success),
                  SizedBox(width: Spacing.sm),
                  const Text('Mark as Settled'),
                ],
              ),
            ),
          ] else ...[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _reopenRecord(record, controller);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.arrow_counterclockwise,
                      color: SemanticColors.warning),
                  SizedBox(width: Spacing.sm),
                  const Text('Reopen Record'),
                ],
              ),
            ),
          ],
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteRecord(context, record, controller);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.trash, color: SemanticColors.error),
                SizedBox(width: Spacing.sm),
                const Text('Delete'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showPartialPaymentModal(
    BuildContext context,
    LendingBorrowing record,
    LendingBorrowingController controller,
  ) {
    final amountController = TextEditingController();
    bool isAdding = true;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext modalContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: 350,
            color: AppStyles.getCardColor(context),
            child: SafeArea(
              child: Column(
                children: [
                  ModalHandle(),
                  SizedBox(height: Spacing.md),
                  Text(
                    'Adjust Amount',
                    style: AppStyles.titleStyle(context).copyWith(
                      fontSize: TypeScale.title2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: Spacing.sm),
                  Text(
                    'Current: ₹${record.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.body,
                    ),
                  ),
                  SizedBox(height: Spacing.xxl),
                  // Add/Subtract Toggle
                  Padding(
                    padding: Spacing.screenPadding,
                    child: Row(
                      children: [
                        Expanded(
                          child: BouncyButton(
                            onPressed: () {
                              Haptics.selection();
                              setModalState(() => isAdding = true);
                            },
                            child: Container(
                              padding:
                                  EdgeInsets.symmetric(vertical: Spacing.md),
                              decoration: BoxDecoration(
                                color: isAdding
                                    ? SemanticColors.success
                                        .withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: Radii.buttonRadius,
                                border: Border.all(
                                  color: isAdding
                                      ? SemanticColors.success
                                      : AppStyles.getSecondaryTextColor(
                                          context),
                                  width: isAdding ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.add_circled,
                                    color: isAdding
                                        ? SemanticColors.success
                                        : AppStyles.getSecondaryTextColor(
                                            context),
                                  ),
                                  SizedBox(width: Spacing.xs),
                                  Text(
                                    'Add',
                                    style: TextStyle(
                                      color: isAdding
                                          ? SemanticColors.success
                                          : AppStyles.getSecondaryTextColor(
                                              context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: Spacing.md),
                        Expanded(
                          child: BouncyButton(
                            onPressed: () {
                              Haptics.selection();
                              setModalState(() => isAdding = false);
                            },
                            child: Container(
                              padding:
                                  EdgeInsets.symmetric(vertical: Spacing.md),
                              decoration: BoxDecoration(
                                color: !isAdding
                                    ? SemanticColors.warning
                                        .withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: Radii.buttonRadius,
                                border: Border.all(
                                  color: !isAdding
                                      ? SemanticColors.warning
                                      : AppStyles.getSecondaryTextColor(
                                          context),
                                  width: !isAdding ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.minus_circled,
                                    color: !isAdding
                                        ? SemanticColors.warning
                                        : AppStyles.getSecondaryTextColor(
                                            context),
                                  ),
                                  SizedBox(width: Spacing.xs),
                                  Text(
                                    'Reduce',
                                    style: TextStyle(
                                      color: !isAdding
                                          ? SemanticColors.warning
                                          : AppStyles.getSecondaryTextColor(
                                              context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Spacing.lg),
                  // Amount Input
                  Padding(
                    padding: Spacing.screenPadding,
                    child: CupertinoTextField(
                      controller: amountController,
                      placeholder: 'Enter amount',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      prefix: Padding(
                        padding: EdgeInsets.only(left: Spacing.md),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontSize: TypeScale.title2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontSize: TypeScale.title2,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: Radii.buttonRadius,
                        border: Border.all(
                          color: isAdding
                              ? SemanticColors.success
                              : SemanticColors.warning,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ActionButtonRow(
                    primaryLabel: 'Save',
                    onPrimaryPressed: () {
                      final amount = double.tryParse(amountController.text);
                      if (amount != null && amount > 0) {
                        controller.adjustRecordAmount(
                          record.id,
                          amount,
                          increase: isAdding,
                        );

                        Navigator.pop(modalContext);
                        Haptics.success();
                        toast.showSuccess(
                          isAdding
                              ? 'Added ₹${amount.toStringAsFixed(0)}'
                              : 'Reduced ₹${amount.toStringAsFixed(0)}',
                        );
                      }
                    },
                    secondaryLabel: 'Cancel',
                    onSecondaryPressed: () => Navigator.pop(modalContext),
                  ),
                  SizedBox(height: Spacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(amountController.dispose);
  }

  void _navigateToEditWizard(BuildContext context, LendingBorrowing record) {
    Navigator.of(context).push(
      FadeScalePageRoute(
        page: LendingWizard(
          type: record.type,
          existingRecord: record,
          onSave: (updatedRecord) {
            Provider.of<LendingBorrowingController>(context, listen: false)
                .updateRecord(
              record.id,
              updatedRecord,
              eventType: LendingHistoryEventType.edited,
              note: 'Details updated',
            );
            toast.showSuccess('Record updated');
            logger.info('Updated record: ${record.personName}',
                context: 'LendingBorrowingScreen');
          },
        ),
      ),
    );
  }

  void _settleRecord(
      LendingBorrowing record, LendingBorrowingController controller) {
    Haptics.success();
    controller.settleRecord(record.id);
    toast.showSuccess(
      'Marked as settled',
      actionLabel: 'Undo',
      onAction: () {
        controller.reopenRecord(record.id);
      },
    );
    logger.info('Settled record: ${record.personName}',
        context: 'LendingBorrowingScreen');
  }

  void _reopenRecord(
      LendingBorrowing record, LendingBorrowingController controller) {
    controller.reopenRecord(record.id);
    Haptics.success();
    toast.showInfo('Record reopened');
  }

  void _deleteRecord(
    BuildContext context,
    LendingBorrowing record,
    LendingBorrowingController controller,
  ) {
    Haptics.warning();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Record'),
        content: Text(
            'Are you sure you want to delete the record with ${record.personName}?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Haptics.delete();
              controller.removeRecord(record.id);
              Navigator.pop(context);
              toast.showSuccess(
                '"${record.personName}" deleted',
                actionLabel: 'Undo',
                onAction: () {
                  controller.addRecord(record);
                  toast.showInfo('Record restored');
                },
              );
              logger.info('Deleted record: ${record.personName}',
                  context: 'LendingBorrowingScreen');
            },
          ),
        ],
      ),
    );
  }

  void _showHistoryModal(BuildContext context, LendingBorrowing record) {
    final history = [...record.history]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModalHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${record.personName} • History',
                        style: AppStyles.titleStyle(context),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(modalContext),
                      child: const Icon(CupertinoIcons.xmark),
                    ),
                  ],
                ),
              ),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    'No history yet',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final event = history[index];
                      final color = _historyEventColor(event.type);
                      final delta = event.amountDelta;
                      final deltaText = delta == null
                          ? ''
                          : delta >= 0
                              ? '+₹${delta.toStringAsFixed(0)}'
                              : '-₹${delta.abs().toStringAsFixed(0)}';
                      return Container(
                        padding: const EdgeInsets.all(Spacing.md),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Radii.md),
                          border:
                              Border.all(color: color.withValues(alpha: 0.22)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _historyEventLabel(event.type),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                      fontSize: TypeScale.subhead,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDateTime(event.timestamp),
                                  style: TextStyle(
                                    fontSize: TypeScale.caption,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                              ],
                            ),
                            if (event.note != null &&
                                event.note!.isNotEmpty) ...[
                              const SizedBox(height: Spacing.xs),
                              Text(
                                event.note!,
                                style: TextStyle(
                                  fontSize: TypeScale.footnote,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  'Balance: ₹${event.resultingAmount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                ),
                                if (deltaText.isNotEmpty) ...[
                                  const Spacer(),
                                  Text(
                                    deltaText,
                                    style: TextStyle(
                                      fontSize: TypeScale.footnote,
                                      fontWeight: FontWeight.w700,
                                      color: delta! >= 0
                                          ? SemanticColors.success
                                          : SemanticColors.warning,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _historyEventLabel(LendingHistoryEventType type) {
    switch (type) {
      case LendingHistoryEventType.created:
        return 'Created';
      case LendingHistoryEventType.amountIncreased:
        return 'Amount Added';
      case LendingHistoryEventType.amountReduced:
        return 'Amount Reduced';
      case LendingHistoryEventType.edited:
        return 'Edited';
      case LendingHistoryEventType.settled:
        return 'Settled';
      case LendingHistoryEventType.reopened:
        return 'Reopened';
    }
  }

  Color _historyEventColor(LendingHistoryEventType type) {
    switch (type) {
      case LendingHistoryEventType.created:
        return SemanticColors.info;
      case LendingHistoryEventType.amountIncreased:
        return SemanticColors.success;
      case LendingHistoryEventType.amountReduced:
        return SemanticColors.warning;
      case LendingHistoryEventType.edited:
        return AppStyles.accentBlue;
      case LendingHistoryEventType.settled:
        return SemanticColors.success;
      case LendingHistoryEventType.reopened:
        return CupertinoColors.systemOrange;
    }
  }

  Widget _buildRecordCard(
    LendingBorrowing record,
    BuildContext context,
    LendingBorrowingController controller,
  ) {
    final isLent = record.type == LendingType.lent;
    final color = isLent ? AppStyles.accentBlue : AppStyles.plasmaRed;
    final icon =
        isLent ? CupertinoIcons.arrow_up_right : CupertinoIcons.arrow_down_left;
    final settledOn = DateTime.tryParse(record.settledDate ?? '');

    return BouncyButton(
      onPressed: () {
        Haptics.light();
        _showRecordActions(context, record, controller);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: Spacing.md),
        decoration: AppStyles.accentCardDecoration(context, color),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xxl),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color, color.withValues(alpha: 0.35)],
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
          children: [
            Padding(
              padding: Spacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Icon and Name
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconBox(
                        icon: icon,
                        color: color,
                        size: 48,
                      ),
                      SizedBox(width: Spacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              record.personName.isNotEmpty
                                  ? record.personName
                                  : 'Unknown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: TypeScale.callout,
                                fontWeight: FontWeight.w700,
                                color: AppStyles.getTextColor(context),
                              ),
                            ),
                            SizedBox(height: Spacing.xs),
                            Text(
                              '${_formatDate(record.date)} • ${isLent ? "Lent" : "Borrowed"}',
                              style: TextStyle(
                                fontSize: TypeScale.footnote,
                                fontWeight: FontWeight.w500,
                                color: AppStyles.getSecondaryTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: Spacing.md),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Spacing.md,
                          vertical: Spacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: Radii.chipRadius,
                        ),
                        child: AnimatedCounter(
                          value: record.amount,
                          prefix: '₹',
                          decimals: 0,
                          duration: AppDurations.counter,
                          style: TextStyle(
                            fontSize: TypeScale.callout,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (record.history.isNotEmpty) ...[
                    SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          size: IconSizes.xs,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                        SizedBox(width: Spacing.xs),
                        Text(
                          '${record.history.length} updates',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (record.description != null) ...[
                    SizedBox(height: Spacing.md),
                    Text(
                      record.description!,
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                  if (record.dueDate != null) ...[
                    SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: IconSizes.xs,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                        SizedBox(width: Spacing.xs),
                        Text(
                          'Due: ${_formatDate(record.dueDate!)}',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (record.isSettled && settledOn != null) ...[
                    SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          size: IconSizes.xs,
                          color: SemanticColors.success,
                        ),
                        SizedBox(width: Spacing.xs),
                        Text(
                          'Settled: ${_formatDate(settledOn)}',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: SemanticColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (record.isSettled)
              Positioned(
                right: Spacing.sm,
                top: Spacing.sm,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: SemanticColors.success,
                    borderRadius: Radii.chipRadius,
                  ),
                  child: Text(
                    'Settled ✓',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${DateFormatter.getMonthName(date.month)} ${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${_formatDate(date)} $hh:$mm';
  }

  void _showPayoffCalculator(BuildContext context, LendingBorrowing record) {
    final monthlyController =
        TextEditingController(text: (record.amount / 12).toStringAsFixed(0));
    final rateController = TextEditingController(text: '0');

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final isDark = AppStyles.isDarkMode(ctx);
          final monthly = double.tryParse(monthlyController.text) ?? 0;
          final annualRate = double.tryParse(rateController.text) ?? 0;
          final outstanding = record.amount;

          int months = 0;
          double totalInterest = 0;
          DateTime? payoffDate;

          if (monthly > 0 && outstanding > 0) {
            if (annualRate <= 0) {
              months = (outstanding / monthly).ceil();
            } else {
              final monthlyRate = annualRate / 100 / 12;
              if (monthly > outstanding * monthlyRate) {
                double balance = outstanding;
                while (balance > 0 && months < 600) {
                  final interest = balance * monthlyRate;
                  totalInterest += interest;
                  balance -= (monthly - interest);
                  months++;
                }
                if (months >= 600) months = 0;
              }
            }
            if (months > 0) {
              payoffDate =
                  DateTime.now().add(Duration(days: (months * 30.44).round()));
            }
          }

          Widget resultRow(String label, String value, {Color? valueColor}) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(ctx),
                          fontSize: TypeScale.body)),
                  Text(value,
                      style: TextStyle(
                          color: valueColor ?? AppStyles.getTextColor(ctx),
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey3,
                        borderRadius: BorderRadius.circular(2.5)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.chart_bar_circle,
                          color: CupertinoColors.systemPurple, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Payoff Calculator',
                        style: TextStyle(
                          color: AppStyles.getTextColor(ctx),
                          fontSize: TypeScale.title2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.personName,
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(ctx),
                      fontSize: TypeScale.body,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(ctx),
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            child: resultRow(
                              'Outstanding Balance',
                              CurrencyFormatter.format(outstanding),
                              valueColor: AppStyles.plasmaRed,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Monthly Payment',
                              style: TextStyle(
                                  color: AppStyles.getSecondaryTextColor(ctx),
                                  fontSize: TypeScale.footnote,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          CupertinoTextField(
                            controller: monthlyController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 12),
                              child: Text('₹'),
                            ),
                            style:
                                TextStyle(color: AppStyles.getTextColor(ctx)),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2C2C2E)
                                  : CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onChanged: (_) => setS(() {}),
                          ),
                          const SizedBox(height: 12),
                          Text('Annual Interest Rate (%)',
                              style: TextStyle(
                                  color: AppStyles.getSecondaryTextColor(ctx),
                                  fontSize: TypeScale.footnote,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          CupertinoTextField(
                            controller: rateController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            suffix: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Text('%'),
                            ),
                            style:
                                TextStyle(color: AppStyles.getTextColor(ctx)),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2C2C2E)
                                  : CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onChanged: (_) => setS(() {}),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(ctx),
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                            child: months > 0
                                ? Column(children: [
                                    resultRow('Payoff In',
                                        '$months month${months > 1 ? 's' : ''}',
                                        valueColor:
                                            AppStyles.bioGreen),
                                    if (payoffDate != null)
                                      resultRow('Estimated Date',
                                          DateFormatter.format(payoffDate)),
                                    if (totalInterest > 0)
                                      resultRow(
                                          'Total Interest',
                                          CurrencyFormatter.format(
                                              totalInterest),
                                          valueColor:
                                              CupertinoColors.systemOrange),
                                    resultRow(
                                        'Total Cost',
                                        CurrencyFormatter.format(
                                            outstanding + totalInterest)),
                                  ])
                                : Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      monthly > 0 && annualRate > 0
                                          ? 'Monthly payment too low to cover interest. Increase it.'
                                          : 'Enter monthly payment to see payoff schedule.',
                                      style: TextStyle(
                                        color: monthly > 0 && annualRate > 0
                                            ? CupertinoColors.systemOrange
                                            : AppStyles.getSecondaryTextColor(
                                                ctx),
                                        fontSize: TypeScale.body,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: CupertinoColors.systemGrey,
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TransactionTypeWizard extends StatelessWidget {
  final Function(LendingType) onTypeSelected;

  const _TransactionTypeWizard({required this.onTypeSelected});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'New Transaction',
          style: TextStyle(
            color: AppStyles.getTextColor(context),
            fontSize: TypeScale.headline,
            fontWeight: FontWeight.w600,
          ),
        ),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What would you like to record?',
                style: AppStyles.titleStyle(context).copyWith(
                  fontSize: TypeScale.largeTitle,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'Choose whether you lent or borrowed money',
                style: TextStyle(
                  fontSize: TypeScale.callout,
                  color: AppStyles.getSecondaryTextColor(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: Spacing.huge),
              _buildTransactionCard(
                context,
                title: 'I Lent Money',
                subtitle: 'Money that I gave to someone',
                icon: CupertinoIcons.arrow_up_right,
                color: AppStyles.accentBlue,
                onTap: () => onTypeSelected(LendingType.lent),
              ),
              const SizedBox(height: Spacing.lg),
              _buildTransactionCard(
                context,
                title: 'I Borrowed Money',
                subtitle: 'Money that I received from someone',
                icon: CupertinoIcons.arrow_down_left,
                color: AppStyles.plasmaRed,
                onTap: () => onTypeSelected(LendingType.borrowed),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: AppStyles.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: AppStyles.accentBlue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppStyles.accentBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.info,
                          size: 18,
                          color: AppStyles.accentBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keep Track',
                            style: TextStyle(
                              fontSize: TypeScale.footnote,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.getTextColor(context),
                            ),
                          ),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            'Add due dates and mark as settled when repaid',
                            style: TextStyle(
                              fontSize: TypeScale.caption,
                              color: AppStyles.getSecondaryTextColor(context),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.xl),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Icon(
              CupertinoIcons.chevron_right,
              size: 20,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ],
        ),
      ),
    );
  }

  // Note: _showPayoffCalculator is defined in _LendingBorrowingScreenState
}
// end of _TransactionTypeWizard
