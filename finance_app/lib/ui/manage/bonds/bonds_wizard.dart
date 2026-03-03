import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/bond_payout_generator.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller_v2.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class BondsWizard extends StatelessWidget {
  const BondsWizard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BondsWizardControllerV2(),
      child: const _BondsWizardContent(),
    );
  }
}

class _BondsWizardContent extends StatelessWidget {
  const _BondsWizardContent();

  Future<void> _saveInvestment(
    BuildContext context,
    BondsWizardControllerV2 controller,
  ) async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);

    try {
      // Generate payout schedule
      final payoutSchedule = BondPayoutGenerator.generatePayoutSchedule(
        frequency: controller.payoutFrequency,
        maturityDate: controller.maturityDate,
        firstPayoutMonth: controller.firstPayoutMonth,
        firstPayoutDay: controller.firstPayoutDay,
      );

      // Convert schedule to map for storage
      final payoutsMap = payoutSchedule.map((p) => p.toMap()).toList();

      final investment = Investment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: controller.bondName,
        type: InvestmentType.bonds,
        amount: controller.bondAmount,
        color: const Color(0xFF00A6CC),
        metadata: {
          'purchaseDate': DateTime.now().toIso8601String(),
          'maturityDate': controller.maturityDate.toIso8601String(),
          'payoutFrequency':
              controller.payoutFrequency.toString().split('.').last,
          'firstPayoutMonth': controller.firstPayoutMonth,
          'firstPayoutDay': controller.firstPayoutDay,
          'linkedAccountId': controller.linkedAccountId,
          'linkedAccountName': controller.linkedAccountName,
          'autoDebit': controller.autoDebit,
          'payoutSchedule': payoutsMap,
          'pastPayouts': <Map<String, dynamic>>[],
          'lastUpdated': DateTime.now().toIso8601String(),
        },
      );

      await investmentsController.addInvestment(investment);

      if (context.mounted) {
        toast.showSuccess('Bond investment added successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        toast.showError('Failed to save investment: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<BondsWizardControllerV2>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Add Bond Investment',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        backgroundColor: AppStyles.getBackground(context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () {
            if (controller.currentStep > 0) {
              controller.previousPage();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: List.generate(controller.totalSteps, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= controller.currentStep
                            ? const Color(0xFF00A6CC)
                            : (isDark ? Colors.grey[800] : Colors.grey[300]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: controller.pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Step 0: Bond Name
                  _BondNameStep(controller),
                  // Step 1: Bond Amount
                  _BondAmountStep(controller),
                  // Step 2: Account Selection
                  _AccountSelectionStep(controller),
                  // Step 3: Payout Frequency
                  _PayoutFrequencyStep(controller),
                  // Step 4: Payout Dates
                  _PayoutDatesStep(controller),
                  // Step 5: Review
                  _ReviewStep(controller),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: controller.canProceed()
                      ? () async {
                          if (controller.currentStep <
                              controller.totalSteps - 1) {
                            controller.nextPage();
                          } else {
                            await _saveInvestment(context, controller);
                          }
                        }
                      : null,
                  child: Text(
                    controller.currentStep >= controller.totalSteps - 1
                        ? 'Save Bond'
                        : 'Continue',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ STEP 0: Bond Name ============
class _BondNameStep extends StatelessWidget {
  final BondsWizardControllerV2 ctrl;
  const _BondNameStep(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bond Name', style: AppStyles.titleStyle(context)),
          const SizedBox(height: Spacing.xl),
          Text('Enter a name to identify this bond',
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context),
              )),
          const SizedBox(height: Spacing.lg),
          CupertinoTextField(
            placeholder: 'e.g., RBI Bond 2028, Government Securities',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
            ),
            onChanged: ctrl.updateBondName,
          ),
        ],
      ),
    );
  }
}

// ============ STEP 1: Bond Amount ============
class _BondAmountStep extends StatelessWidget {
  final BondsWizardControllerV2 ctrl;
  const _BondAmountStep(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Investment Amount', style: AppStyles.titleStyle(context)),
          const SizedBox(height: Spacing.xl),
          Text('How much are you investing in this bond?',
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context),
              )),
          const SizedBox(height: Spacing.lg),
          CupertinoTextField(
            placeholder: '0.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: const Text('₹'),
            ),
            onChanged: (v) {
              final amount = double.tryParse(v) ?? 0;
              ctrl.updateBondAmount(amount);
            },
          ),
        ],
      ),
    );
  }
}

// ============ STEP 2: Account Selection ============
class _AccountSelectionStep extends StatefulWidget {
  final BondsWizardControllerV2 ctrl;
  const _AccountSelectionStep(this.ctrl);

  @override
  State<_AccountSelectionStep> createState() => _AccountSelectionStepState();
}

class _AccountSelectionStepState extends State<_AccountSelectionStep> {
  @override
  void initState() {
    super.initState();
    // Refresh accounts when entering this step
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await Provider.of<AccountsController>(context, listen: false)
            .loadAccounts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountsController>(
      builder: (context, accountsController, child) {
        // Show all accounts (bonds can be linked to any account type)
        final accounts = accountsController.accounts;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Linked Account', style: AppStyles.titleStyle(context)),
              const SizedBox(height: Spacing.xl),
              Text('Select an account to link with this bond (optional)',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getSecondaryTextColor(context),
                  )),
              const SizedBox(height: Spacing.lg),
              if (accounts.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.briefcase,
                          size: 48, color: CupertinoColors.systemGrey),
                      const SizedBox(height: Spacing.lg),
                      Text(
                        'No Accounts Found',
                        style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context)),
                      ),
                    ],
                  ),
                )
              else
                ...accounts.map((account) {
                  final isSelected = widget.ctrl.linkedAccountId == account.id;

                  return GestureDetector(
                    onTap: () {
                      widget.ctrl.updateLinkedAccount(account.id, account.name);
                      // Auto-proceed to next step
                      Future.delayed(const Duration(milliseconds: 300), () {
                        widget.ctrl.nextPage();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00A6CC).withValues(alpha: 0.1)
                            : AppStyles.getCardColor(context),
                        border: isSelected
                            ? Border.all(color: const Color(0xFF00A6CC))
                            : Border.all(color: Colors.transparent),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          if (!isSelected)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: account.color.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CupertinoIcons.briefcase_fill,
                                color: account.color),
                          ),
                          const SizedBox(width: Spacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: TypeScale.headline),
                                ),
                                Text(
                                  account.bankName,
                                  style: TextStyle(
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                    fontSize: TypeScale.subhead,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${account.balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Icon(
                                      CupertinoIcons.check_mark_circled_solid,
                                      color: Color(0xFF00A6CC),
                                      size: 20),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: Spacing.xl),
              CupertinoButton(
                color:
                    isDarkMode(context) ? Colors.grey[800] : Colors.grey[200],
                onPressed: () {
                  final accountsController =
                      Provider.of<AccountsController>(context, listen: false);

                  Navigator.push<Account>(
                    context,
                    FadeScalePageRoute(
                      page: const AccountWizard(isInvestment: false),
                    ),
                  ).then((result) {
                    if (result != null) {
                      // Save the newly created account
                      accountsController.addAccount(result);
                      // Auto-select the newly added account
                      widget.ctrl.updateLinkedAccount(result.id, result.name);
                      // Auto-proceed to next step
                      Future.delayed(const Duration(milliseconds: 300), () {
                        widget.ctrl.nextPage();
                      });
                    }
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.add,
                        color: AppStyles.getTextColor(context)),
                    const SizedBox(width: Spacing.sm),
                    Text('Add Account',
                        style:
                            TextStyle(color: AppStyles.getTextColor(context))),
                  ],
                ),
              ),
              if (widget.ctrl.linkedAccountId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Auto-debit from account',
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                      CupertinoSwitch(
                        value: widget.ctrl.autoDebit,
                        onChanged: widget.ctrl.updateAutoDebit,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

// ============ STEP 3: Payout Frequency ============
class _PayoutFrequencyStep extends StatelessWidget {
  final BondsWizardControllerV2 ctrl;
  const _PayoutFrequencyStep(this.ctrl);

  @override
  Widget build(BuildContext context) {
    final frequencies = [
      (PayoutFrequency.monthly, 'Monthly', 'Payout every month'),
      (PayoutFrequency.quarterly, 'Quarterly', 'Payout every 3 months'),
      (PayoutFrequency.semiAnnual, 'Semi-Annual', 'Payout twice a year'),
      (PayoutFrequency.annual, 'Annual', 'Payout once a year'),
      (PayoutFrequency.atMaturity, 'At Maturity', 'Single payout at maturity'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payout Frequency', style: AppStyles.titleStyle(context)),
          const SizedBox(height: Spacing.xl),
          ...frequencies.map((f) {
            final isSelected = ctrl.payoutFrequency == f.$1;
            return GestureDetector(
              onTap: () => ctrl.updatePayoutFrequency(f.$1),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00A6CC).withValues(alpha: 0.1)
                      : AppStyles.getCardColor(context),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00A6CC)
                        : CupertinoColors.systemGrey.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00A6CC)
                              : CupertinoColors.systemGrey,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00A6CC),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$2,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(f.$3,
                              style: TextStyle(
                                fontSize: TypeScale.footnote,
                                color: AppStyles.getSecondaryTextColor(context),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============ STEP 4: Payout Dates ============
class _PayoutDatesStep extends StatelessWidget {
  final BondsWizardControllerV2 ctrl;
  const _PayoutDatesStep(this.ctrl);

  @override
  Widget build(BuildContext context) {
    final isAtMaturity = ctrl.payoutFrequency == PayoutFrequency.atMaturity;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bond Dates', style: AppStyles.titleStyle(context)),
          const SizedBox(height: Spacing.xl),
          if (!isAtMaturity) ...[
            Text('First Payout Month & Day',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    placeholder: 'Month (1-12)',
                    keyboardType: TextInputType.number,
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
                    ),
                    onChanged: (v) {
                      final month = int.tryParse(v) ?? 1;
                      ctrl.updateFirstPayoutMonth(month);
                    },
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: CupertinoTextField(
                    placeholder: 'Day (1-31)',
                    keyboardType: TextInputType.number,
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
                    ),
                    onChanged: (v) {
                      final day = int.tryParse(v) ?? 1;
                      ctrl.updateFirstPayoutDay(day);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xxl),
          ],
          Text('Bond Maturity Date',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          GestureDetector(
            onTap: () {
              showCupertinoModalPopup(
                context: context,
                builder: (ctx) => Container(
                  height: 300,
                  color: AppStyles.getBackground(context),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          border: Border(
                            bottom: BorderSide(
                                color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Select Date',
                                style: TextStyle(
                                    fontSize: TypeScale.headline, fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: const Icon(CupertinoIcons.xmark),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: ctrl.maturityDate,
                          onDateTimeChanged: ctrl.updateMaturityDate,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${ctrl.maturityDate.day}/${ctrl.maturityDate.month}/${ctrl.maturityDate.year}',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  const Icon(CupertinoIcons.calendar),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ STEP 5: Review ============
class _ReviewStep extends StatelessWidget {
  final BondsWizardControllerV2 ctrl;
  const _ReviewStep(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review Bond Details', style: AppStyles.titleStyle(context)),
          const SizedBox(height: Spacing.xl),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewRow('Bond Name', ctrl.bondName),
                const SizedBox(height: Spacing.md),
                _ReviewRow('Investment Amount',
                    '₹${ctrl.bondAmount.toStringAsFixed(2)}'),
                const SizedBox(height: Spacing.md),
                _ReviewRow('Payout Frequency', ctrl.payoutFrequencyLabel),
                if (ctrl.linkedAccountId != null) ...[
                  const SizedBox(height: Spacing.md),
                  _ReviewRow(
                      'Linked Account', ctrl.linkedAccountName ?? 'Unknown'),
                  const SizedBox(height: Spacing.md),
                  _ReviewRow(
                      'Auto-Debit', ctrl.autoDebit ? 'Enabled' : 'Disabled'),
                ],
                const SizedBox(height: Spacing.md),
                _ReviewRow(
                  'Maturity Date',
                  '${ctrl.maturityDate.day}/${ctrl.maturityDate.month}/${ctrl.maturityDate.year}',
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF00A6CC).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF00A6CC).withValues(alpha: 0.3)),
            ),
            child: Text(
              'You will receive payout reminders 2 days before each scheduled payout date via Notifications and Actions.',
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: TypeScale.subhead,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: TypeScale.subhead,
            fontWeight: FontWeight.w600,
            color: AppStyles.getTextColor(context),
          ),
        ),
      ],
    );
  }
}
