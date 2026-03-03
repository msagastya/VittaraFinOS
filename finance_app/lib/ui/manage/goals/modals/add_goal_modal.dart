import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/utils/alert_service.dart';

class AddGoalModal extends StatefulWidget {
  const AddGoalModal({super.key});

  @override
  State<AddGoalModal> createState() => _AddGoalModalState();
}

class _AddGoalModalState extends State<AddGoalModal> {
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _notesController = TextEditingController();

  GoalType _selectedType = GoalType.custom;
  Color _selectedColor = SemanticColors.primary;
  DateTime _targetDate = DateTime.now().add(Duration(days: 365));

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveGoal() async {
    if (_nameController.text.trim().isEmpty) {
      AlertService.showError(context, 'Please enter a goal name');
      return;
    }

    final targetAmount = double.tryParse(_targetAmountController.text.trim());
    if (targetAmount == null || targetAmount <= 0) {
      AlertService.showError(context, 'Please enter a valid target amount');
      return;
    }

    final goal = Goal(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      type: _selectedType,
      targetAmount: targetAmount,
      currentAmount: 0,
      createdDate: DateTime.now(),
      targetDate: _targetDate,
      color: _selectedColor,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    await Provider.of<GoalsController>(context, listen: false).addGoal(goal);
    Navigator.pop(context);
    AlertService.showSuccess(context, 'Goal created successfully!');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
      ),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: Spacing.md),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              SizedBox(height: Spacing.xl),
              Text(
                'Create New Goal',
                style: TextStyle(
                  fontSize: TypeScale.title2,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context),
                ),
              ),
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
                      placeholder: 'e.g., Emergency Fund',
                      padding: EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    SizedBox(height: Spacing.xl),
                    Text('Goal Type',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.md),
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: GoalType.values.map((type) {
                        final dummyGoal = Goal(
                          id: '',
                          name: '',
                          type: type,
                          targetAmount: 0,
                          currentAmount: 0,
                          createdDate: DateTime.now(),
                          targetDate: DateTime.now(),
                          color: CupertinoColors.activeBlue,
                        );
                        final isSelected = _selectedType == type;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = type),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: Spacing.lg, vertical: Spacing.md),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? SemanticColors.primary
                                      .withValues(alpha: 0.1)
                                  : AppStyles.getBackground(context),
                              borderRadius: BorderRadius.circular(Radii.full),
                              border: Border.all(
                                color: isSelected
                                    ? SemanticColors.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(dummyGoal.getTypeIcon(),
                                    size: IconSizes.sm,
                                    color: isSelected
                                        ? SemanticColors.primary
                                        : AppStyles.getSecondaryTextColor(
                                            context)),
                                SizedBox(width: Spacing.xs),
                                Text(
                                  dummyGoal.getTypeLabel(),
                                  style: TextStyle(
                                    fontSize: TypeScale.footnote,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? SemanticColors.primary
                                        : AppStyles.getTextColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: Spacing.xl),
                    Text('Target Amount',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: _targetAmountController,
                      placeholder: '100000',
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      prefix: Padding(
                        padding: EdgeInsets.only(left: Spacing.lg),
                        child: Text('₹',
                            style: TextStyle(fontSize: TypeScale.callout)),
                      ),
                      padding: EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    SizedBox(height: Spacing.xl),
                    Text('Target Date',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.sm),
                    GestureDetector(
                      onTap: () {
                        showCupertinoModalPopup(
                          context: context,
                          builder: (context) => Container(
                            height: 300,
                            color: AppStyles.getCardColor(context),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    CupertinoButton(
                                      child: Text('Cancel'),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    CupertinoButton(
                                      child: Text('Done'),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                                Expanded(
                                  child: CupertinoDatePicker(
                                    mode: CupertinoDatePickerMode.date,
                                    initialDateTime: _targetDate,
                                    minimumDate: DateTime.now(),
                                    onDateTimeChanged: (date) =>
                                        setState(() => _targetDate = date),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}'),
                            Icon(CupertinoIcons.calendar, size: IconSizes.md),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: Spacing.xl),
                    Text('Color',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ColorPalettes.accountColors.map((color) {
                          final isSelected = _selectedColor == color;
                          return Padding(
                            padding: EdgeInsets.only(right: Spacing.md),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedColor = color),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                              color:
                                                  color.withValues(alpha: 0.5),
                                              blurRadius: 10,
                                              offset: Offset(0, 4))
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: Spacing.xl),
                    Text('Notes (Optional)',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: _notesController,
                      placeholder: 'Add any notes about this goal',
                      maxLines: 3,
                      padding: EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
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
                                    color: AppStyles.getTextColor(context))),
                          ),
                        ),
                        SizedBox(width: Spacing.md),
                        Expanded(
                          child: CupertinoButton(
                            color: SemanticColors.success,
                            onPressed: _saveGoal,
                            child: Text('Create Goal',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
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
