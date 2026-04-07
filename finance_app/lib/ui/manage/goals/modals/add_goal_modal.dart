import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/utils/alert_service.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

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
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveGoal() async {
    if (_isSaving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_nameController.text.trim().isEmpty) {
      AlertService.showError(context, 'Please enter a goal name');
      return;
    }

    final targetAmount = double.tryParse(_targetAmountController.text.trim());
    if (targetAmount == null || targetAmount <= 0) {
      AlertService.showError(context, 'Please enter a valid target amount');
      return;
    }
    if (targetAmount > 1000000000) {
      AlertService.showError(context, 'Target amount seems too high (max ₹100 Cr)');
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

    setState(() => _isSaving = true);
    try {
      await Provider.of<GoalsController>(context, listen: false).addGoal(goal);
      if (!mounted) return;
      Navigator.pop(context);
      AlertService.showSuccess(context, 'Goal created successfully!');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModalHandle(),
              const SizedBox(height: Spacing.xl),
              Text(
                'Create New Goal',
                style: TextStyle(
                  fontSize: TypeScale.title2,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const SizedBox(height: Spacing.xxl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Goal Name',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: _nameController,
                      placeholder: 'e.g., Emergency Fund',
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    const Text('Goal Type',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.md),
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
                          color: AppStyles.teal(context),
                        );
                        final isSelected = _selectedType == type;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
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
                                const SizedBox(width: Spacing.xs),
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
                    const SizedBox(height: Spacing.xl),
                    const Text('Target Amount',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: _targetAmountController,
                      placeholder: '100000',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: Spacing.lg),
                        child: Text('₹',
                            style: TextStyle(fontSize: TypeScale.callout)),
                      ),
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    const Text('Target Date',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.sm),
                    GestureDetector(
                      onTap: () {
                        showCupertinoModalPopup(
                          context: context,
                          builder: (context) => RLayout.tabletConstrain(
                            context,
                            Container(
                            height: 300,
                            color: AppStyles.getCardColor(context),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    CupertinoButton(
                                      child: const Text('Cancel'),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    CupertinoButton(
                                      child: const Text('Done'),
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
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                '${_targetDate.day}/${_targetDate.month}/${_targetDate.year}'),
                            const Icon(CupertinoIcons.calendar, size: IconSizes.md),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    const Text('Color',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ColorPalettes.accountColors.map((color) {
                          final isSelected = _selectedColor == color;
                          return Padding(
                            padding: const EdgeInsets.only(right: Spacing.md),
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
                                              offset: const Offset(0, 4))
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    const Text('Notes (Optional)',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                      controller: _notesController,
                      placeholder: 'Add any notes about this goal',
                      maxLines: 3,
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(context),
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
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
                                    color: AppStyles.getTextColor(context))),
                          ),
                        ),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: CupertinoButton(
                            color: SemanticColors.success,
                            onPressed: _isSaving ? null : _saveGoal,
                            child: _isSaving
                                ? const CupertinoActivityIndicator(
                                    color: Colors.white)
                                : const Text('Create Goal',
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
