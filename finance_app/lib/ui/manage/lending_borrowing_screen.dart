import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_model.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/ui/manage/lending_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
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
                              onTap: () => setState(() => _selectedTab = 0),
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
                                      Text(
                                        '₹${controller.getTotalLent().toStringAsFixed(0)}',
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
                              onTap: () => setState(() => _selectedTab = 1),
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
                                      Text(
                                        '₹${controller.getTotalBorrowed().toStringAsFixed(0)}',
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
                                return _buildRecordCard(record, context, controller);
                              },
                            ),
                    ),
                  ],
                ),
              ),
              // Add Button
              Positioned(
                right: 16,
                bottom: 32,
                child: FadingFloatingActionButton(
                  onPressed: () => _showLendingTypeModal(context),
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
            Provider.of<ContactsController>(context, listen: false).addOrGetContact(
              record.personName,
            );
            logger.info(
              'Added ${type == LendingType.lent ? "lent" : "borrowed"} record: ${record.personName}',
              context: 'LendingBorrowingScreen',
            );
          },
        ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Icon and Name
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(icon, color: color, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.personName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.getTextColor(context),
                            ),
                          ),
                          Text(
                            _formatDate(record.date),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${record.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (record.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    record.description!,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
                if (record.dueDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Due: ${_formatDate(record.dueDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (record.isSettled)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.green.withValues(alpha: 0.1),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Settled',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  controller.settleRecord(record.id);
                  logger.info('Settled record: ${record.personName}', context: 'LendingBorrowingScreen');
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(CupertinoIcons.checkmark, size: 14, color: CupertinoColors.systemGreen),
                  ),
                ),
              ),
            ),
        ],
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

class FadingFloatingActionButton extends StatefulWidget {
  final VoidCallback onPressed;
  const FadingFloatingActionButton({super.key, required this.onPressed});

  @override
  State<FadingFloatingActionButton> createState() => _FadingFloatingActionButtonState();
}

class _FadingFloatingActionButtonState extends State<FadingFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(_controller);
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    if (_controller.value > 0) _controller.reverse();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: GestureDetector(
            onTap: () {
              _startInactivityTimer();
              widget.onPressed();
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemBlue.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.add, color: Colors.white, size: 28),
            ),
          ),
        );
      },
    );
  }
}
