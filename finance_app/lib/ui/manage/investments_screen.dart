import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/ui/manage/investment_type_selection.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  final AppLogger logger = AppLogger();

  void _showInvestmentTypeSelection(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => InvestmentTypeSelectionModal(
        onTypeSelected: (investmentType) {
          logger.info('Selected investment type: ${investmentType.name}', context: 'InvestmentsScreen');
          // For now, just log. Later we'll create investment details form
          Navigator.pop(modalContext);
          final dummyInvestment = Investment(
            id: '',
            name: '',
            type: investmentType,
            amount: 0,
            color: Colors.grey,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${dummyInvestment.getTypeLabel()} selected - details form coming soon!'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    final investmentsController = Provider.of<InvestmentsController>(context, listen: false);
    investmentsController.reorderInvestments(oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Investments', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<InvestmentsController>(
        builder: (context, investmentsController, child) {
          final investments = investmentsController.investments;
          final totalAmount = investmentsController.getTotalInvestmentAmount();

          return Stack(
            children: [
              if (investments.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.chart_pie_fill,
                        size: 64,
                        color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Investments Added',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      CupertinoButton(
                        color: AppStyles.accentBlue,
                        child: const Text('Add Investment'),
                        onPressed: () => _showInvestmentTypeSelection(context),
                      ),
                    ],
                  ),
                )
              else
                SafeArea(
                  child: Column(
                    children: [
                      // Total Investment Card
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: AppStyles.cardDecoration(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Invested',
                                style: TextStyle(
                                  color: AppStyles.getSecondaryTextColor(context),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₹${totalAmount.toStringAsFixed(2)}',
                                style: AppStyles.titleStyle(context).copyWith(
                                  fontSize: 32,
                                  color: AppStyles.accentBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${investments.length} investments across ${_getDistinctTypesCount(investments)} categories',
                                style: TextStyle(
                                  color: AppStyles.getSecondaryTextColor(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Investments List
                      Expanded(
                        child: ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: investments.length,
                          onReorder: _onReorder,
                          itemBuilder: (context, index) {
                            return _buildInvestmentCard(investments[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                right: 16,
                bottom: 32,
                child: FadingFloatingActionButton(
                  onPressed: () => _showInvestmentTypeSelection(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _getDistinctTypesCount(List<Investment> investments) {
    return investments.map((inv) => inv.type).toSet().length;
  }

  Widget _buildInvestmentCard(Investment investment) {
    return Container(
      key: ValueKey(investment.id),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppStyles.cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: AppStyles.iconBoxDecoration(context, investment.color),
              child: Center(
                child: Icon(
                  CupertinoIcons.chart_bar_square_fill,
                  color: investment.color,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(investment.name, style: AppStyles.titleStyle(context)),
                  const SizedBox(height: 4),
                  Text(
                    investment.getTypeLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.getSecondaryTextColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${investment.amount.toStringAsFixed(2)}',
                  style: AppStyles.titleStyle(context).copyWith(
                    color: investment.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  CupertinoIcons.chevron_up,
                  size: 14,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ],
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
  Timer? _timer;
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
    _timer?.cancel();
    if (_controller.value > 0) _controller.reverse();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            onTapDown: (_) => _startInactivityTimer(),
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
