import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/category_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/utils/alert_service.dart';

class AddBudgetModal extends StatefulWidget {
  const AddBudgetModal({super.key});

  @override
  State<AddBudgetModal> createState() => _AddBudgetModalState();
}

class _AddBudgetModalState extends State<AddBudgetModal> {
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;
  Color _selectedColor = SemanticColors.primary;
  Category? _selectedCategory;

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _saveBudget() async {
    if (_nameController.text.trim().isEmpty) {
      AlertService.showError(context, 'Please enter a budget name');
      return;
    }

    final limit = double.tryParse(_limitController.text.trim());
    if (limit == null || limit <= 0) {
      AlertService.showError(context, 'Please enter a valid limit amount');
      return;
    }

    final now = DateTime.now();
    DateTime endDate;
    switch (_selectedPeriod) {
      case BudgetPeriod.daily:
        endDate = DateTime(now.year, now.month, now.day).add(Duration(days: 1));
        break;
      case BudgetPeriod.weekly:
        endDate = now.add(Duration(days: 7));
        break;
      case BudgetPeriod.monthly:
        endDate =
            DateTime(now.year, now.month + 1, 1).subtract(Duration(days: 1));
        break;
      case BudgetPeriod.yearly:
        endDate = DateTime(now.year + 1, 1, 1).subtract(Duration(days: 1));
        break;
    }

    final budget = Budget(
      id: 'budget_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      categoryId: _selectedCategory?.id,
      categoryName: _selectedCategory?.name,
      limitAmount: limit,
      spentAmount: 0,
      period: _selectedPeriod,
      startDate: now,
      endDate: endDate,
      color: _selectedColor,
    );

    await Provider.of<BudgetsController>(context, listen: false)
        .addBudget(budget);
    Navigator.pop(context);
    AlertService.showSuccess(context, 'Budget created successfully!');
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
              Text('Create New Budget',
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
                    Text('Budget Name',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                        controller: _nameController,
                        placeholder: 'Enter budget name',
                        padding: EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                            color: AppStyles.getBackground(context),
                            borderRadius: BorderRadius.circular(Radii.md))),
                    SizedBox(height: Spacing.xl),
                    Text('Category (optional)',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.sm),
                    GestureDetector(
                      onTap: () async {
                        final categories = Provider.of<CategoriesController>(
                                context,
                                listen: false)
                            .categories;
                        await showCupertinoModalPopup<void>(
                          context: context,
                          builder: (ctx) => Container(
                            height: 420,
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(ctx),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(Radii.xxl)),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Column(
                                children: [
                                  SizedBox(height: Spacing.md),
                                  Container(
                                    width: 40,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemGrey3,
                                      borderRadius: BorderRadius.circular(2.5),
                                    ),
                                  ),
                                  SizedBox(height: Spacing.lg),
                                  Text(
                                    'Select Category',
                                    style: TextStyle(
                                      fontSize: TypeScale.title3,
                                      fontWeight: FontWeight.bold,
                                      color: AppStyles.getTextColor(ctx),
                                    ),
                                  ),
                                  SizedBox(height: Spacing.md),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: categories.length + 1,
                                      itemBuilder: (itemCtx, index) {
                                        if (index == 0) {
                                          return CupertinoButton(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: Spacing.lg,
                                                vertical: Spacing.md),
                                            onPressed: () {
                                              setState(() =>
                                                  _selectedCategory = null);
                                              Navigator.pop(ctx);
                                            },
                                            child: Row(
                                              children: [
                                                Icon(
                                                  CupertinoIcons.clear_circled,
                                                  color: AppStyles
                                                      .getSecondaryTextColor(
                                                          ctx),
                                                ),
                                                SizedBox(width: Spacing.md),
                                                Text(
                                                  'No category',
                                                  style: TextStyle(
                                                      color: AppStyles
                                                          .getTextColor(ctx)),
                                                ),
                                              ],
                                            ),
                                          );
                                        }

                                        final category = categories[index - 1];
                                        final isSelected =
                                            _selectedCategory?.id ==
                                                category.id;
                                        return CupertinoButton(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: Spacing.lg,
                                              vertical: Spacing.md),
                                          onPressed: () {
                                            setState(() {
                                              _selectedCategory = category;
                                              _selectedColor = category.color;
                                              if (_nameController.text
                                                  .trim()
                                                  .isEmpty) {
                                                _nameController.text =
                                                    '${category.name} Budget';
                                              }
                                            });
                                            Navigator.pop(ctx);
                                          },
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: category.color
                                                      .withValues(alpha: 0.18),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(category.icon,
                                                    size: 16,
                                                    color: category.color),
                                              ),
                                              SizedBox(width: Spacing.md),
                                              Expanded(
                                                child: Text(
                                                  category.name,
                                                  style: TextStyle(
                                                      color: AppStyles
                                                          .getTextColor(ctx)),
                                                ),
                                              ),
                                              if (isSelected)
                                                Icon(
                                                  CupertinoIcons
                                                      .check_mark_circled_solid,
                                                  color: SemanticColors.primary,
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                          color: AppStyles.getBackground(context),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: Row(
                          children: [
                            if (_selectedCategory != null) ...[
                              Icon(_selectedCategory!.icon,
                                  color: _selectedCategory!.color),
                              SizedBox(width: Spacing.sm),
                            ],
                            Expanded(
                              child: Text(
                                _selectedCategory?.name ??
                                    'Choose from Manage Categories',
                                style: TextStyle(
                                  color: _selectedCategory == null
                                      ? AppStyles.getSecondaryTextColor(context)
                                      : AppStyles.getTextColor(context),
                                ),
                              ),
                            ),
                            Icon(CupertinoIcons.chevron_down,
                                color:
                                    AppStyles.getSecondaryTextColor(context)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: Spacing.xl),
                    Text('Limit Amount',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.sm),
                    CupertinoTextField(
                        controller: _limitController,
                        placeholder: '10000',
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        prefix: Padding(
                            padding: EdgeInsets.only(left: Spacing.lg),
                            child: Text('₹',
                                style: TextStyle(fontSize: TypeScale.callout))),
                        padding: EdgeInsets.all(Spacing.lg),
                        decoration: BoxDecoration(
                            color: AppStyles.getBackground(context),
                            borderRadius: BorderRadius.circular(Radii.md))),
                    SizedBox(height: Spacing.xl),
                    Text('Period',
                        style: TextStyle(
                            fontSize: TypeScale.subhead,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: Spacing.md),
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: BudgetPeriod.values.map((period) {
                        final dummyBudget = Budget(
                            id: '',
                            name: '',
                            limitAmount: 0,
                            spentAmount: 0,
                            period: period,
                            startDate: DateTime.now(),
                            endDate: DateTime.now(),
                            color: Colors.blue);
                        final isSelected = _selectedPeriod == period;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedPeriod = period),
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
                                    width: 2)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(dummyBudget.getPeriodIcon(),
                                    size: IconSizes.sm,
                                    color: isSelected
                                        ? SemanticColors.primary
                                        : AppStyles.getSecondaryTextColor(
                                            context)),
                                SizedBox(width: Spacing.xs),
                                Text(dummyBudget.getPeriodLabel(),
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? SemanticColors.primary
                                            : AppStyles.getTextColor(context))),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
                                onPressed: _saveBudget,
                                child: Text('Create Budget',
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
