import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
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

  void _saveContribution() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      AlertService.showError(context, 'Please enter a valid amount');
      return;
    }

    final contribution = GoalContribution(
      id: 'contrib_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      date: DateTime.now(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    await Provider.of<GoalsController>(context, listen: false).addContribution(widget.goal.id, contribution);
    Navigator.pop(context);
    AlertService.showSuccess(context, 'Contribution added successfully!');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: Spacing.md),
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: CupertinoColors.systemGrey3, borderRadius: BorderRadius.circular(2.5)),
              ),
              SizedBox(height: Spacing.xl),
              Text('Add Contribution', style: TextStyle(fontSize: TypeScale.title2, fontWeight: FontWeight.bold, color: AppStyles.getTextColor(context))),
              SizedBox(height: Spacing.xxl),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Spacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount', style: TextStyle(fontSize: TypeScale.subhead, fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: _amountController,
                      placeholder: '0.00',
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      prefix: Padding(padding: EdgeInsets.only(left: Spacing.lg), child: Text('₹', style: TextStyle(fontSize: TypeScale.callout))),
                      padding: EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(color: AppStyles.getBackground(context), borderRadius: BorderRadius.circular(Radii.md)),
                      autofocus: true,
                    ),
                    SizedBox(height: Spacing.xl),
                    Text('Notes (Optional)', style: TextStyle(fontSize: TypeScale.subhead, fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: _notesController,
                      placeholder: 'Add a note',
                      maxLines: 3,
                      padding: EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(color: AppStyles.getBackground(context), borderRadius: BorderRadius.circular(Radii.md)),
                    ),
                    SizedBox(height: Spacing.xxxl),
                    Row(
                      children: [
                        Expanded(child: CupertinoButton(color: CupertinoColors.systemGrey3, onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppStyles.getTextColor(context))))),
                        SizedBox(width: Spacing.md),
                        Expanded(child: CupertinoButton(color: widget.goal.color, onPressed: _saveContribution, child: Text('Add', style: TextStyle(color: Colors.white)))),
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
