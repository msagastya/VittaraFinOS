import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
import 'package:vittara_fin_os/utils/alert_service.dart';

class AddContributionModal extends StatefulWidget {
  final Goal goal;

  const AddContributionModal({super.key, required this.goal});

  @override
  State<AddContributionModal> createState() => _AddContributionModalState();
}

class _AddContributionModalState extends State<AddContributionModal> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveContribution() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AlertService.showError(context, 'Please enter a valid amount');
      return;
    }

    final remaining = widget.goal.targetAmount - widget.goal.currentAmount;
    if (amount > remaining && remaining > 0) {
      final proceed = await showCupertinoDialog<bool>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Exceeds Remaining Target'),
          content: Text(
              'Contribution of ₹${amount.toStringAsFixed(2)} exceeds the remaining ₹${remaining.toStringAsFixed(2)}. Proceed anyway?'),
          actions: [
            CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Proceed')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final contribution = GoalContribution(
      id: 'contrib_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      date: DateTime.now(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final prevProgress = widget.goal.targetAmount > 0
        ? (widget.goal.currentAmount / widget.goal.targetAmount) * 100
        : 0.0;

    await Provider.of<GoalsController>(context, listen: false)
        .addContribution(widget.goal.id, contribution);

    final newAmount = widget.goal.currentAmount + amount;
    final newProgress = widget.goal.targetAmount > 0
        ? (newAmount / widget.goal.targetAmount) * 100
        : 0.0;

    // J8 — milestone celebrations at 25/50/75/100%
    final milestones = [100.0, 75.0, 50.0, 25.0];
    String? milestone;
    for (final m in milestones) {
      if (prevProgress < m && newProgress >= m) {
        milestone = m == 100.0 ? '🎉 Goal Achieved!' : '${m.toInt()}% reached!';
        break;
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
    if (milestone != null) {
      Haptics.success();
      toast_lib.toast.showSuccess('${widget.goal.name}: $milestone');
    } else {
      AlertService.showSuccess(context, 'Contribution added successfully!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModalHandle(),
              const SizedBox(height: Spacing.xl),
              Text('Add Contribution',
                  style: TextStyle(
                      fontSize: RT.title2(context),
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getTextColor(context))),
              const SizedBox(height: Spacing.xxl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Amount',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: _amountController,
                      placeholder: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      prefix: const Padding(
                          padding: EdgeInsets.only(left: Spacing.lg),
                          child: Text('₹',
                              style: TextStyle(fontSize: TypeScale.callout))),
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                          color: AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(Radii.md)),
                      autofocus: true,
                    ),
                    const SizedBox(height: Spacing.xl),
                    const Text('Notes (Optional)',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: _notesController,
                      placeholder: 'Add a note',
                      maxLines: 3,
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                          color: AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(Radii.md)),
                    ),
                    const SizedBox(height: Spacing.xxxl),
                    Row(
                      children: [
                        Expanded(
                            child: CupertinoButton(
                                color: CupertinoColors.systemGrey3,
                                onPressed: () => Navigator.pop(context),
                                child: Text('Cancel',
                                    style: TextStyle(
                                        color:
                                            AppStyles.getTextColor(context))))),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                            child: CupertinoButton(
                                color: widget.goal.color,
                                onPressed: _saveContribution,
                                child: const Text('Add',
                                    style: TextStyle(color: Colors.white)))),
                      ],
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
}
