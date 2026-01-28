import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class TenureStep extends StatefulWidget {
  const TenureStep({super.key});

  @override
  State<TenureStep> createState() => _TenureStepState();
}

class _TenureStepState extends State<TenureStep> {
  late TextEditingController _durationController;
  late TenureUnit _selectedUnit;

  @override
  void initState() {
    super.initState();
    final controller = Provider.of<FDWizardController>(context, listen: false);
    _selectedUnit = controller.tenureUnit ?? TenureUnit.months;
    _durationController = TextEditingController(
      text: controller.tenureDuration.toString(),
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  void _updateTenure() {
    final controller = Provider.of<FDWizardController>(context, listen: false);
    final duration = int.tryParse(_durationController.text) ?? 12;
    controller.updateTenureWithUnit(duration, _selectedUnit);
  }

  int _convertToDays(int duration, TenureUnit unit) {
    switch (unit) {
      case TenureUnit.days:
        return duration;
      case TenureUnit.months:
        return (duration * 365 / 12).toInt();
      case TenureUnit.years:
        return duration * 365;
    }
  }

  String _getUnitLabel(TenureUnit unit) {
    switch (unit) {
      case TenureUnit.days:
        return 'Days';
      case TenureUnit.months:
        return 'Months';
      case TenureUnit.years:
        return 'Years';
    }
  }

  void _showUnitPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        color: AppStyles.getBackground(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Unit',
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Done'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            ...TenureUnit.values.map((unit) {
              final isSelected = _selectedUnit == unit;
              return CupertinoButton(
                padding: EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
                onPressed: () {
                  setState(() {
                    _selectedUnit = unit;
                    _updateTenure();
                  });
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppStyles.getPrimaryColor(context).withOpacity(0.1)
                        : AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppStyles.getPrimaryColor(context)
                          : AppStyles.getDividerColor(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    _getUnitLabel(unit),
                    style: TextStyle(
                      color: isSelected
                          ? AppStyles.getPrimaryColor(context)
                          : AppStyles.getTextColor(context),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tenure Duration',
            style: AppStyles.titleStyle(context),
          ),
          const SizedBox(height: 8),
          Text(
            'How long do you want to keep this FD?',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 30),
          Text(
            'Duration',
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  placeholder: '12',
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  style: TextStyle(color: AppStyles.getTextColor(context)),
                  onChanged: (_) => _updateTenure(),
                ),
              ),
              SizedBox(width: Spacing.md),
              Container(
                padding: EdgeInsets.symmetric(horizontal: Spacing.md),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.getDividerColor(context),
                    width: 1,
                  ),
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showUnitPicker(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getUnitLabel(_selectedUnit),
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: Spacing.sm),
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 16,
                        color: AppStyles.getPrimaryColor(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Consumer<FDWizardController>(
            builder: (context, controller, child) {
              final maturityDate = controller.maturityDate;
              String durationText = '';

              if (controller.tenureUnit != null) {
                switch (controller.tenureUnit) {
                  case TenureUnit.days:
                    durationText = '${controller.tenureDuration} day${controller.tenureDuration > 1 ? 's' : ''}';
                    break;
                  case TenureUnit.months:
                    durationText = '${controller.tenureDuration} month${controller.tenureDuration > 1 ? 's' : ''}';
                    break;
                  case TenureUnit.years:
                    durationText = '${controller.tenureDuration} year${controller.tenureDuration > 1 ? 's' : ''}';
                    break;
                  case null:
                    final years = controller.tenureMonths ~/ 12;
                    final months = controller.tenureMonths % 12;
                    durationText = years > 0
                        ? '$years year${years > 1 ? 's' : ''} ${months > 0 ? '$months month${months > 1 ? 's' : ''}' : ''}'
                        : '${controller.tenureMonths} month${controller.tenureMonths > 1 ? 's' : ''}';
                }
              } else {
                final years = controller.tenureMonths ~/ 12;
                final months = controller.tenureMonths % 12;
                durationText = years > 0
                    ? '$years year${years > 1 ? 's' : ''} ${months > 0 ? '$months month${months > 1 ? 's' : ''}' : ''}'
                    : '${controller.tenureMonths} month${controller.tenureMonths > 1 ? 's' : ''}';
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppStyles.getBackground(context).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.getPrimaryColor(context).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maturity Details',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Duration',
                          style:
                              TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          durationText,
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Maturity Date',
                          style:
                              TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                        ),
                        Text(
                          '${maturityDate.day} ${_monthName(maturityDate.month)} ${maturityDate.year}',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
