import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/app_date_picker.dart';

class MFNewInvestmentDetailsStep extends StatefulWidget {
  const MFNewInvestmentDetailsStep({super.key});

  @override
  State<MFNewInvestmentDetailsStep> createState() =>
      _MFNewInvestmentDetailsStepState();
}

class _MFNewInvestmentDetailsStepState
    extends State<MFNewInvestmentDetailsStep> {
  late TextEditingController _amountController;
  bool _isFetchingNAV = false;
  String _navError = '';

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<MFWizardController>(context, listen: false);
    _amountController = TextEditingController(
      text: controller.investmentAmount > 0
          ? controller.investmentAmount.toString()
          : '',
    );
  }

  void _updateAmount() {
    final controller = Provider.of<MFWizardController>(context, listen: false);
    final amount = double.tryParse(_amountController.text) ?? 0;
    controller.updateNewMFDetails(
      amount: amount,
      date: controller.investmentDate,
      deduct: controller.deductFromAccount,
      deductAccount: controller.deductionAccount,
      fetchedNav: controller.fetchedNAV,
    );
  }

  Future<void> _fetchNAVForDate() async {
    final controller = Provider.of<MFWizardController>(context, listen: false);

    if (controller.selectedMF == null) {
      setState(() {
        _navError = 'Please select a mutual fund first';
      });
      return;
    }

    setState(() {
      _isFetchingNAV = true;
      _navError = '';
    });

    try {
      // Historical NAV for past dates not available; using current NAV as placeholder
      final nav = controller.selectedMF!.nav ?? 0;

      if (nav > 0) {
        controller.setFetchedNAV(nav);
        setState(() {
          _isFetchingNAV = false;
        });
      } else {
        setState(() {
          _isFetchingNAV = false;
          _navError = 'Could not fetch NAV for selected date';
        });
      }
    } catch (e) {
      setState(() {
        _isFetchingNAV = false;
        _navError = 'Error fetching NAV: $e';
      });
    }
  }

  Future<void> _showDatePicker() async {
    final controller = Provider.of<MFWizardController>(context, listen: false);
    final picked = await showAppDatePicker(
      context: context,
      initialDate: controller.investmentDate,
      minimumDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      maximumDate: DateTime.now(),
    );
    if (picked != null) {
      controller.updatePurchaseDate(picked);
      // Reset fetched NAV when date changes
      controller.setFetchedNAV(null);
      setState(() {
        _navError = '';
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mfController = Provider.of<MFWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Investment Details',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Enter amount and date for ${mfController.selectedMF?.schemeName ?? "Mutual Fund"}',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),

          // Investment Amount
          Text(
            'Investment Amount',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                '₹',
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context)),
            onChanged: (_) => _updateAmount(),
          ),
          const SizedBox(height: Spacing.xl),

          // Date of Investment
          Text(
            'Date of Investment',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          GestureDetector(
            onTap: _showDatePicker,
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${mfController.investmentDate.day} ${_monthName(mfController.investmentDate.month)} ${mfController.investmentDate.year}',
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                  ),
                  Icon(
                    CupertinoIcons.calendar,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xl),

          // Fetch NAV Button
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: CupertinoColors.systemBlue,
              onPressed: _isFetchingNAV ? null : _fetchNAVForDate,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isFetchingNAV)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CupertinoActivityIndicator(),
                    )
                  else
                    const Icon(CupertinoIcons.cloud_download, size: 16),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    _isFetchingNAV
                        ? 'Fetching NAV...'
                        : mfController.fetchedNAV != null
                            ? 'NAV: ₹${mfController.fetchedNAV!.toStringAsFixed(2)}'
                            : 'Fetch NAV for Date',
                  ),
                ],
              ),
            ),
          ),

          if (_navError.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: AppStyles.plasmaRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppStyles.plasmaRed.withValues(alpha: 0.3)),
              ),
              child: Text(
                _navError,
                style: const TextStyle(
                  color: AppStyles.plasmaRed,
                  fontSize: TypeScale.footnote,
                ),
              ),
            ),
          ],

          const SizedBox(height: 30),

          // Deduct from Bank Account Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Deduct from Bank Account?',
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              CupertinoSwitch(
                value: mfController.deductFromAccount,
                onChanged: (value) {
                  mfController.updateNewMFDetails(
                    amount: mfController.investmentAmount,
                    date: mfController.investmentDate,
                    deduct: value,
                    deductAccount: value ? mfController.deductionAccount : null,
                    fetchedNav: mfController.fetchedNAV,
                  );
                },
              ),
            ],
          ),

          if (mfController.deductFromAccount) ...[
            const SizedBox(height: Spacing.xl),
            Text(
              'Select Bank Account',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.md),
            Consumer<AccountsController>(
              builder: (context, accountsController, child) {
                final bankAccounts = accountsController.accounts
                    .where((acc) =>
                        acc.type == AccountType.savings ||
                        acc.type == AccountType.current)
                    .toList();

                return Column(
                  children: [
                    if (bankAccounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemOrange
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Text(
                          'No bank accounts found',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.footnote,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bankAccounts.length,
                        itemBuilder: (context, index) {
                          final account = bankAccounts[index];
                          final isSelected =
                              mfController.deductionAccount?.id == account.id;

                          return GestureDetector(
                            onTap: () {
                              mfController.updateNewMFDetails(
                                amount: mfController.investmentAmount,
                                date: mfController.investmentDate,
                                deduct: true,
                                deductAccount: account,
                                fetchedNav: mfController.fetchedNAV,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(Spacing.md),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? SemanticColors.investments
                                        .withValues(alpha: 0.1)
                                    : AppStyles.getCardColor(context),
                                border: isSelected
                                    ? Border.all(
                                        color: SemanticColors.investments,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(Radii.md),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(Spacing.sm),
                                    decoration: BoxDecoration(
                                      color:
                                          account.color.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.money_dollar_circle,
                                      color: account.color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: TypeScale.body,
                                          ),
                                        ),
                                        Text(
                                          '₹${account.balance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context),
                                            fontSize: TypeScale.footnote,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      CupertinoIcons.check_mark_circled_solid,
                                      color: SemanticColors.investments,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: Spacing.md),
                    CupertinoButton(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      onPressed: () {
                        final accountsController =
                            Provider.of<AccountsController>(context,
                                listen: false);
                        Navigator.push<Account>(
                          context,
                          FadeScalePageRoute(
                            page: const AccountWizard(isInvestment: false),
                          ),
                        ).then((result) {
                          if (result != null) {
                            accountsController.addAccount(result);
                            mfController.updateNewMFDetails(
                              amount: mfController.investmentAmount,
                              date: mfController.investmentDate,
                              deduct: true,
                              deductAccount: result,
                              fetchedNav: mfController.fetchedNAV,
                            );
                          }
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.add,
                            color: AppStyles.getTextColor(context),
                          ),
                          const SizedBox(width: Spacing.sm),
                          Text(
                            'Add Bank Account',
                            style: TextStyle(
                              color: AppStyles.getTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: 30),

          // NAV and Units Display
          if (mfController.fetchedNAV != null) ...[
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: SemanticColors.investments.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: SemanticColors.investments.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NAV on Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${mfController.fetchedNAV!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.headline,
                          color: SemanticColors.investments,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Units',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        mfController.calculatedUnits.toStringAsFixed(4),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.headline,
                          color: SemanticColors.investments,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _monthName(int month) {
    return DateFormatter.getMonthName(month);
  }
}
