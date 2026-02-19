import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/utils/alert_service.dart';

class EditGoalModal extends StatefulWidget {
  final Goal goal;

  const EditGoalModal({super.key, required this.goal});

  @override
  State<EditGoalModal> createState() => _EditGoalModalState();
}

class _EditGoalModalState extends State<EditGoalModal> {
  late TextEditingController _nameController;
  late TextEditingController _targetAmountController;
  late TextEditingController _notesController;
  late GoalType _selectedType;
  late Color _selectedColor;
  late DateTime _targetDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.name);
    _targetAmountController =
        TextEditingController(text: widget.goal.targetAmount.toString());
    _notesController = TextEditingController(text: widget.goal.notes ?? '');
    _selectedType = widget.goal.type;
    _selectedColor = widget.goal.color;
    _targetDate = widget.goal.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateGoal() async {
    if (_nameController.text.trim().isEmpty) {
      AlertService.showError(context, 'Please enter a goal name');
      return;
    }

    final targetAmount = double.tryParse(_targetAmountController.text.trim());
    if (targetAmount == null || targetAmount <= 0) {
      AlertService.showError(context, 'Please enter a valid target amount');
      return;
    }

    final updatedGoal = widget.goal.copyWith(
      name: _nameController.text.trim(),
      type: _selectedType,
      targetAmount: targetAmount,
      targetDate: _targetDate,
      color: _selectedColor,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    await Provider.of<GoalsController>(context, listen: false)
        .updateGoal(updatedGoal);
    Navigator.pop(context);
    AlertService.showSuccess(context, 'Goal updated successfully!');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xxl))),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  margin: EdgeInsets.only(top: Spacing.md),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3,
                      borderRadius: BorderRadius.circular(2.5))),
              SizedBox(height: Spacing.xl),
              Text('Edit Goal',
                  style: TextStyle(
                      fontSize: TypeScale.title2,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getTextColor(context))),
              SizedBox(height: Spacing.xxl),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Spacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Goal Name',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                        controller: _nameController,
                        padding: EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                            color: AppStyles.getBackground(context),
                            borderRadius: BorderRadius.circular(Radii.md))),
                    SizedBox(height: Spacing.xl),
                    Text('Target Amount',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: _targetAmountController,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      prefix: Padding(
                          padding: EdgeInsets.only(left: Spacing.lg),
                          child: Text('₹')),
                      padding: EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                          color: AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(Radii.md)),
                    ),
                    SizedBox(height: Spacing.xxxl),
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
                        SizedBox(width: Spacing.md),
                        Expanded(
                            child: CupertinoButton(
                                color: SemanticColors.primary,
                                onPressed: _updateGoal,
                                child: Text('Update',
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
