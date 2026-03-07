import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/pension_model.dart';
import 'package:vittara_fin_os/ui/manage/pension/pension_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

class PensionWizard extends StatelessWidget {
  const PensionWizard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PensionWizardController(),
      child: const _PensionWizardContent(),
    );
  }
}

class _PensionWizardContent extends StatefulWidget {
  const _PensionWizardContent();

  @override
  State<_PensionWizardContent> createState() => _PensionWizardContentState();
}

class _PensionWizardContentState extends State<_PensionWizardContent> {
  late PageController _pageController;
  int _previousStep = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveInvestment(
    BuildContext context,
    PensionWizardController ctrl,
  ) async {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);

    try {
      final pension = PensionScheme(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        accountNumber: ctrl.accountNumber!,
        type: ctrl.selectedScheme,
        principalContributed: ctrl.principalContributed!,
        currentValue: ctrl.currentValue!,
        contributions: [],
        createdDate: DateTime.now(),
        notes: ctrl.notes,
      );

      final investment = Investment(
        id: pension.id,
        name: pension.getTypeLabel(),
        type: InvestmentType.pensionSchemes,
        amount: ctrl.principalContributed!,
        color: const Color(0xFF27AE60),
        metadata: {
          'pensionData': pension.toMap(),
          'currentValue': ctrl.currentValue,
        },
      );

      await investmentsController.addInvestment(investment);

      if (context.mounted) {
        Haptics.success();
        toast.showSuccess('Pension scheme added successfully!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        toast.showError('Failed to save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<PensionWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Handle page navigation when currentStep changes
    if (ctrl.currentStep != _previousStep) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ctrl.currentStep > _previousStep) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
      _previousStep = ctrl.currentStep;
    }

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Add Pension Scheme',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        backgroundColor: AppStyles.getBackground(context),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () {
            if (ctrl.currentStep > 0) {
              ctrl.previousPage();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: List.generate(4, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= ctrl.currentStep
                            ? const Color(0xFF27AE60)
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
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SchemeSelectionStep(ctrl),
                  _AccountDetailsStep(ctrl),
                  _ContributionStep(ctrl),
                  _ReviewStep(ctrl),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: ctrl.canProceed()
                      ? () async {
                          if (ctrl.currentStep < 3) {
                            ctrl.nextPage();
                          } else {
                            await _saveInvestment(context, ctrl);
                          }
                        }
                      : null,
                  child: Text(
                      ctrl.currentStep >= 3 ? 'Confirm & Save' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchemeSelectionStep extends StatelessWidget {
  final PensionWizardController ctrl;

  const _SchemeSelectionStep(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Pension Scheme', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Column(
            children: PensionSchemeType.values.map((scheme) {
              final isSelected = ctrl.selectedScheme == scheme;
              final details = {
                PensionSchemeType.apy: (
                  'Atal Pension Yojana (APY)',
                  '₹1000-₹5000/month, Govt. backed'
                ),
                PensionSchemeType.epf: (
                  'EPF',
                  'Employee Provident Fund, 12% employee'
                ),
                PensionSchemeType.ppf: (
                  'PPF',
                  'Public Provident Fund, ₹500-₹150K/year'
                ),
              };
              final (title, desc) = details[scheme]!;

              return GestureDetector(
                onTap: () => ctrl.selectScheme(scheme),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF27AE60).withValues(alpha: 0.1)
                        : AppStyles.getCardColor(context),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF27AE60)
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
                                ? const Color(0xFF27AE60)
                                : CupertinoColors.systemGrey,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF27AE60),
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
                            Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(desc,
                                style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    color: AppStyles.getSecondaryTextColor(
                                        context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AccountDetailsStep extends StatefulWidget {
  final PensionWizardController ctrl;

  const _AccountDetailsStep(this.ctrl);

  @override
  State<_AccountDetailsStep> createState() => _AccountDetailsStepState();
}

class _AccountDetailsStepState extends State<_AccountDetailsStep> {
  late TextEditingController _accountController;

  @override
  void initState() {
    super.initState();
    _accountController =
        TextEditingController(text: widget.ctrl.accountNumber ?? '');
  }

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account Details', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Text('Account/Reference Number',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _accountController,
            placeholder: 'Enter account number',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            onChanged: (v) => widget.ctrl.updateAccountNumber(v),
          ),
        ],
      ),
    );
  }
}

class _ContributionStep extends StatefulWidget {
  final PensionWizardController ctrl;

  const _ContributionStep(this.ctrl);

  @override
  State<_ContributionStep> createState() => _ContributionStepState();
}

class _ContributionStepState extends State<_ContributionStep> {
  late TextEditingController _principalController;
  late TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _principalController = TextEditingController(
      text: widget.ctrl.principalContributed?.toString() ?? '',
    );
    _valueController = TextEditingController(
      text: widget.ctrl.currentValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _principalController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contributions & Valuation',
              style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Text('Total Contributed (₹)',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _principalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: const Text('₹'),
            ),
            onChanged: (v) {
              final amt = double.tryParse(v) ?? 0;
              if (amt > 0) ctrl.updatePrincipal(amt);
            },
          ),
          const SizedBox(height: Spacing.xxl),
          Text('Current Value (₹)',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: const Text('₹'),
            ),
            onChanged: (v) {
              final val = double.tryParse(v) ?? 0;
              if (val > 0) ctrl.updateCurrentValue(val);
            },
          ),
          const SizedBox(height: Spacing.xxl),
          if (ctrl.principalContributed != null &&
              ctrl.currentValue != null) ...{
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF27AE60).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  _Summary('Return', '₹${ctrl.gainLoss.toStringAsFixed(2)}',
                      ctrl.gainLoss >= 0),
                  const SizedBox(height: Spacing.md),
                  _Summary(
                      'Return %',
                      '${ctrl.gainLossPercent.toStringAsFixed(2)}%',
                      ctrl.gainLossPercent >= 0,
                      isBold: true),
                ],
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  final PensionWizardController ctrl;

  const _ReviewStep(this.ctrl);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Confirm', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          _Card(
            children: [
              _Row('Scheme', ctrl.selectedScheme.toString().split('.').last),
              _Row('Account', ctrl.accountNumber ?? 'N/A'),
              _Row('Contributed',
                  '₹${ctrl.principalContributed?.toStringAsFixed(2) ?? '0'}'),
              _Row('Current Value',
                  '₹${ctrl.currentValue?.toStringAsFixed(2) ?? '0'}',
                  isBold: true),
              _Row('Gain/Loss', '₹${ctrl.gainLoss.toStringAsFixed(2)}',
                  isGain: ctrl.gainLoss >= 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: List.generate(
          children.length,
          (i) => Column(
            children: [
              children[i],
              if (i < children.length - 1) const SizedBox(height: Spacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isGain;

  const _Row(this.label, this.value, {this.isBold = false, this.isGain = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.subhead)),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 14 : 13,
                color: isBold ? const Color(0xFF27AE60) : null)),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final String label;
  final String value;
  final bool isPositive;
  final bool isBold;

  const _Summary(this.label, this.value, this.isPositive,
      {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.subhead)),
        Text(value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: isBold ? 14 : 13,
                color: isPositive
                    ? CupertinoColors.systemGreen
                    : CupertinoColors.systemRed)),
      ],
    );
  }
}
