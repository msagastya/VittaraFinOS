import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_model.dart';
import 'package:vittara_fin_os/ui/manage/lending_wizard.dart';
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
  int _selectedTab = 0; // 0 = I Lent, 1 = I Borrowed

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Lending & Borrowing', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<LendingBorrowingController>(
        builder: (context, controller, child) {
          final lentRecords = controller.getLentRecords();
          final borrowedRecords = controller.getBorrowedRecords();
          final displayRecords = _selectedTab == 0 ? lentRecords : borrowedRecords;

          return Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    // Tab Selector
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedTab = 0);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 0
                                      ? AppStyles.accentBlue.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _selectedTab == 0
                                        ? AppStyles.accentBlue
                                        : AppStyles.getSecondaryTextColor(context),
                                    width: _selectedTab == 0 ? 1.5 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        'I Lent',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _selectedTab == 0
                                              ? AppStyles.accentBlue
                                              : AppStyles.getSecondaryTextColor(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedCounter(
                                        value: controller.getTotalLent(),
                                        prefix: '₹',
                                        decimals: 0,
                                        duration: const Duration(milliseconds: 600),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _selectedTab == 0
                                              ? AppStyles.accentBlue
                                              : AppStyles.getSecondaryTextColor(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedTab = 1);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1
                                      ? CupertinoColors.systemRed.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _selectedTab == 1
                                        ? CupertinoColors.systemRed
                                        : AppStyles.getSecondaryTextColor(context),
                                    width: _selectedTab == 1 ? 1.5 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        'I Borrowed',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _selectedTab == 1
                                              ? CupertinoColors.systemRed
                                              : AppStyles.getSecondaryTextColor(context),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedCounter(
                                        value: controller.getTotalBorrowed(),
                                        prefix: '₹',
                                        decimals: 0,
                                        duration: const Duration(milliseconds: 600),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _selectedTab == 1
                                              ? CupertinoColors.systemRed
                                              : AppStyles.getSecondaryTextColor(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Records List
                    Expanded(
                      child: displayRecords.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    CupertinoIcons.person_2_fill,
                                    size: 48,
                                    color: AppStyles.getSecondaryTextColor(context),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _selectedTab == 0
                                        ? 'No lending records yet'
                                        : 'No borrowing records yet',
                                    style: TextStyle(
                                      color: AppStyles.getSecondaryTextColor(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: displayRecords.length,
                              itemBuilder: (context, index) {
                                final record = displayRecords[index];
                                return StaggeredItem(
                                  index: index,
                                  child: _buildRecordCard(record, context, controller),
                                );
                              },
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

  void _showLendingTypeModal(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (newContext) => _TransactionTypeWizard(
          onTypeSelected: (type) {
            Navigator.pop(newContext);
            _navigateToLendingWizard(context, type);
          },
        ),
      ),
    );
  }

  void _navigateToLendingWizard(BuildContext context, LendingType type) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (newContext) => LendingWizard(
          type: type,
          onSave: (record) {
            Provider.of<LendingBorrowingController>(context, listen: false).addRecord(record);
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
    final color = isLent ? AppStyles.accentBlue : CupertinoColors.systemRed;

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
          if (!record.isSettled) ...[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showPartialPaymentModal(context, record, controller);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.arrow_up_down_circle, color: SemanticColors.info),
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
                  Icon(CupertinoIcons.pencil, color: SemanticColors.getPrimary(context)),
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
                  Icon(CupertinoIcons.checkmark_circle, color: SemanticColors.success),
                  SizedBox(width: Spacing.sm),
                  const Text('Mark as Settled'),
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
                              padding: EdgeInsets.symmetric(vertical: Spacing.md),
                              decoration: BoxDecoration(
                                color: isAdding
                                    ? SemanticColors.success.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: Radii.buttonRadius,
                                border: Border.all(
                                  color: isAdding
                                      ? SemanticColors.success
                                      : AppStyles.getSecondaryTextColor(context),
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
                                        : AppStyles.getSecondaryTextColor(context),
                                  ),
                                  SizedBox(width: Spacing.xs),
                                  Text(
                                    'Add',
                                    style: TextStyle(
                                      color: isAdding
                                          ? SemanticColors.success
                                          : AppStyles.getSecondaryTextColor(context),
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
                              padding: EdgeInsets.symmetric(vertical: Spacing.md),
                              decoration: BoxDecoration(
                                color: !isAdding
                                    ? SemanticColors.warning.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: Radii.buttonRadius,
                                border: Border.all(
                                  color: !isAdding
                                      ? SemanticColors.warning
                                      : AppStyles.getSecondaryTextColor(context),
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
                                        : AppStyles.getSecondaryTextColor(context),
                                  ),
                                  SizedBox(width: Spacing.xs),
                                  Text(
                                    'Reduce',
                                    style: TextStyle(
                                      color: !isAdding
                                          ? SemanticColors.warning
                                          : AppStyles.getSecondaryTextColor(context),
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
                      keyboardType: TextInputType.number,
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
                        double newAmount;
                        if (isAdding) {
                          newAmount = record.amount + amount;
                        } else {
                          newAmount = record.amount - amount;
                          if (newAmount < 0) newAmount = 0;
                        }

                        final updatedRecord = record.copyWith(amount: newAmount);
                        controller.updateRecord(record.id, updatedRecord);

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
    );
  }

  void _navigateToEditWizard(BuildContext context, LendingBorrowing record) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (newContext) => LendingWizard(
          type: record.type,
          existingRecord: record,
          onSave: (updatedRecord) {
            Provider.of<LendingBorrowingController>(context, listen: false)
                .updateRecord(record.id, updatedRecord);
            toast.showSuccess('Record updated');
            logger.info('Updated record: ${record.personName}', context: 'LendingBorrowingScreen');
          },
        ),
      ),
    );
  }

  void _settleRecord(LendingBorrowing record, LendingBorrowingController controller) {
    Haptics.success();
    controller.settleRecord(record.id);
    toast.showSuccess(
      'Marked as settled',
      actionLabel: 'Undo',
      onAction: () {
        final unsettledRecord = record.copyWith(
          isSettled: false,
          settledDate: null,
        );
        controller.updateRecord(record.id, unsettledRecord);
      },
    );
    logger.info('Settled record: ${record.personName}', context: 'LendingBorrowingScreen');
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
        content: Text('Are you sure you want to delete the record with ${record.personName}?'),
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
              logger.info('Deleted record: ${record.personName}', context: 'LendingBorrowingScreen');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(
    LendingBorrowing record,
    BuildContext context,
    LendingBorrowingController controller,
  ) {
    final isLent = record.type == LendingType.lent;
    final color = isLent ? AppStyles.accentBlue : CupertinoColors.systemRed;
    final icon = isLent ? CupertinoIcons.arrow_up_right : CupertinoIcons.arrow_down_left;

    return BouncyButton(
      onPressed: () {
        Haptics.light();
        _showRecordActions(context, record, controller);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: Spacing.md),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: Radii.cardRadius,
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                              record.personName.isNotEmpty ? record.personName : 'Unknown',
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
                              _formatDate(record.date),
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
                ],
              ),
            ),
            if (record.isSettled)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: Radii.cardRadius,
                    color: SemanticColors.success.withValues(alpha: 0.1),
                  ),
                  child: Center(
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
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
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
            fontSize: 16,
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
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose whether you lent or borrowed money',
                style: TextStyle(
                  fontSize: 15,
                  color: AppStyles.getSecondaryTextColor(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              _buildTransactionCard(
                context,
                title: 'I Lent Money',
                subtitle: 'Money that I gave to someone',
                icon: CupertinoIcons.arrow_up_right,
                color: AppStyles.accentBlue,
                onTap: () => onTypeSelected(LendingType.lent),
              ),
              const SizedBox(height: 16),
              _buildTransactionCard(
                context,
                title: 'I Borrowed Money',
                subtitle: 'Money that I received from someone',
                icon: CupertinoIcons.arrow_down_left,
                color: CupertinoColors.systemRed,
                onTap: () => onTypeSelected(LendingType.borrowed),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppStyles.accentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keep Track',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.getTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add due dates and mark as settled when repaid',
                            style: TextStyle(
                              fontSize: 11,
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.getSecondaryTextColor(context),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
}

