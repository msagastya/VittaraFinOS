import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

class InvestmentTypeSelectionModal extends StatefulWidget {
  final Function(InvestmentType) onTypeSelected;

  const InvestmentTypeSelectionModal({
    super.key,
    required this.onTypeSelected,
  });

  @override
  State<InvestmentTypeSelectionModal> createState() => _InvestmentTypeSelectionModalState();
}

class _InvestmentTypeSelectionModalState extends State<InvestmentTypeSelectionModal> {
  bool _showAll = false;

  final List<Map<String, dynamic>> _investmentTypes = [
    // Top 5
    {'type': InvestmentType.stocks, 'label': 'Stocks', 'icon': CupertinoIcons.chart_bar_fill},
    {'type': InvestmentType.mutualFund, 'label': 'Mutual Fund', 'icon': CupertinoIcons.chart_pie_fill},
    {'type': InvestmentType.fixedDeposit, 'label': 'Fixed Deposit (FD)', 'icon': CupertinoIcons.lock_circle_fill},
    {'type': InvestmentType.recurringDeposit, 'label': 'Recurring Deposit (RD)', 'icon': CupertinoIcons.arrow_2_circlepath_circle_fill},
    {'type': InvestmentType.bonds, 'label': 'Bonds', 'icon': CupertinoIcons.doc_circle_fill},
    // Rest 7
    {'type': InvestmentType.nationalSavingsScheme, 'label': 'National Savings Scheme', 'icon': CupertinoIcons.flag_circle_fill},
    {'type': InvestmentType.digitalGold, 'label': 'Digital Gold', 'icon': CupertinoIcons.star_circle_fill},
    {'type': InvestmentType.pensionSchemes, 'label': 'Pension Schemes', 'icon': CupertinoIcons.calendar_circle_fill},
    {'type': InvestmentType.cryptocurrency, 'label': 'Cryptocurrency', 'icon': CupertinoIcons.cube_box_fill},
    {'type': InvestmentType.futuresOptions, 'label': 'Futures & Options', 'icon': CupertinoIcons.arrow_up_arrow_down_circle_fill},
    {'type': InvestmentType.forexCurrency, 'label': 'Forex/Currency', 'icon': CupertinoIcons.money_dollar_circle_fill},
    {'type': InvestmentType.commodities, 'label': 'Commodities', 'icon': CupertinoIcons.square_fill},
  ];

  @override
  Widget build(BuildContext context) {
    final displayedTypes = _showAll ? _investmentTypes : _investmentTypes.sublist(0, 5);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Select Investment Type',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Choose the type of investment to add',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Investment Types Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: displayedTypes.length,
                  itemBuilder: (context, index) {
                    final invType = displayedTypes[index];
                    final color = (invType['type'] as InvestmentType).index == 0
                        ? const Color(0xFF00B050)
                        : Investment(
                            id: '',
                            name: '',
                            type: invType['type'],
                            amount: 0,
                            color: Colors.grey,
                          ).getTypeColor();

                    return BouncyButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onTypeSelected(invType['type']);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppStyles.getCardColor(context),
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  invType['icon'],
                                  size: 28,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                invType['label'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.getTextColor(context),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // More/Less Button
              if (!_showAll)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    color: AppStyles.accentBlue.withValues(alpha: 0.1),
                    onPressed: () => setState(() => _showAll = true),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.chevron_down_circle,
                          size: 18,
                          color: AppStyles.accentBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Show More (7)',
                          style: TextStyle(
                            color: AppStyles.accentBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    color: AppStyles.accentBlue.withValues(alpha: 0.1),
                    onPressed: () => setState(() => _showAll = false),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.chevron_up_circle,
                          size: 18,
                          color: AppStyles.accentBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Show Less',
                          style: TextStyle(
                            color: AppStyles.accentBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
