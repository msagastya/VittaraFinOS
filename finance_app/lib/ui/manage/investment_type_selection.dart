import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investment_type_preferences_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';

class InvestmentTypeSelectionModal extends StatefulWidget {
  final Function(InvestmentType) onTypeSelected;

  const InvestmentTypeSelectionModal({
    super.key,
    required this.onTypeSelected,
  });

  @override
  State<InvestmentTypeSelectionModal> createState() =>
      _InvestmentTypeSelectionModalState();
}

class _InvestmentTypeSelectionModalState
    extends State<InvestmentTypeSelectionModal> {
  bool _showAll = false;

  final Map<InvestmentType, Map<String, dynamic>> _investmentTypeDetails = {
    InvestmentType.stocks: {
      'label': 'Stocks & ETFs',
      'icon': CupertinoIcons.chart_bar_fill
    },
    InvestmentType.mutualFund: {
      'label': 'Mutual Fund',
      'icon': CupertinoIcons.chart_pie_fill
    },
    InvestmentType.digitalGold: {
      'label': 'Digital Gold',
      'icon': CupertinoIcons.star_circle_fill
    },
    InvestmentType.bonds: {
      'label': 'Bonds',
      'icon': CupertinoIcons.doc_circle_fill
    },
    InvestmentType.nationalSavingsScheme: {
      'label': 'NPS',
      'icon': CupertinoIcons.flag_circle_fill
    },
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<InvestmentTypePreferencesController>(
      builder: (context, prefsController, child) {
        final preferredTypes = prefsController.preferredTypes;
        final hiddenTypes = prefsController.hiddenTypes;

        final displayedTypes =
            (_showAll ? [...preferredTypes, ...hiddenTypes] : preferredTypes)
                .where(_investmentTypeDetails.containsKey)
                .toList();

        final resolvedDisplayedTypes = displayedTypes.isEmpty
            ? _investmentTypeDetails.keys.toList()
            : displayedTypes;

        return _buildContent(
          context,
          resolvedDisplayedTypes,
          prefsController,
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<InvestmentType> displayedTypes,
    InvestmentTypePreferencesController prefsController,
  ) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        decoration: AppStyles.bottomSheetDecoration(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModalHandle(),
              const SizedBox(height: Spacing.xl),

              // Title with Settings Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Investment Type',
                      style:
                          AppStyles.titleStyle(context).copyWith(fontSize: RT.largeTitle(context)),
                    ),
                    if (_showAll)
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(
                          CupertinoIcons.settings,
                          color: AppStyles.accentBlue,
                          size: 24,
                        ),
                        onPressed: () =>
                            _showSettingsModal(context, prefsController),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Choose the type of investment to add',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.body,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xxl),

              // Investment Types Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const cols = 2;
                    const spacing = 12.0;
                    final itemW = (constraints.maxWidth - (cols - 1) * spacing) / cols;
                    return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: 12,
                    childAspectRatio: itemW / (itemW * 1.2),
                  ),
                  itemCount: displayedTypes.length,
                  itemBuilder: (context, index) {
                    final invType = displayedTypes[index];
                    final details = _investmentTypeDetails[invType]!;
                    final color = Investment(
                      id: '',
                      name: '',
                      type: invType,
                      amount: 0,
                      color: CupertinoColors.systemGrey,
                    ).getTypeColor();

                    return BouncyButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onTypeSelected(invType);
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
                                  details['icon'],
                                  size: 28,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(height: Spacing.md),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                details['label'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: TypeScale.footnote,
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
                    );
                  },
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // More/Less Button
              if (!_showAll && prefsController.hiddenTypes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                    color: AppStyles.accentBlue.withValues(alpha: 0.1),
                    onPressed: () => setState(() => _showAll = true),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.chevron_down_circle,
                          size: 18,
                          color: AppStyles.accentBlue,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          'Show More (${prefsController.hiddenTypes.length})',
                          style: const TextStyle(
                            color: AppStyles.accentBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_showAll && prefsController.hiddenTypes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                    color: AppStyles.accentBlue.withValues(alpha: 0.1),
                    onPressed: () => setState(() => _showAll = false),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.chevron_up_circle,
                          size: 18,
                          color: AppStyles.accentBlue,
                        ),
                        SizedBox(width: Spacing.sm),
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
              const SizedBox(height: Spacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsModal(
    BuildContext context,
    InvestmentTypePreferencesController prefsController,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => InvestmentTypePreferencesModal(
        prefsController: prefsController,
        investmentTypeDetails: _investmentTypeDetails,
      ),
    );
  }
}

class InvestmentTypePreferencesModal extends StatefulWidget {
  final InvestmentTypePreferencesController prefsController;
  final Map<InvestmentType, Map<String, dynamic>> investmentTypeDetails;

  const InvestmentTypePreferencesModal({
    super.key,
    required this.prefsController,
    required this.investmentTypeDetails,
  });

  @override
  State<InvestmentTypePreferencesModal> createState() =>
      _InvestmentTypePreferencesModalState();
}

class _InvestmentTypePreferencesModalState
    extends State<InvestmentTypePreferencesModal> {
  late List<InvestmentType> _tempSelectedTypes;
  final int _maxSelectable =
      InvestmentTypePreferencesController.allTypes.length;

  @override
  void initState() {
    super.initState();
    _tempSelectedTypes = List.from(widget.prefsController.preferredTypes);
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        decoration: AppStyles.bottomSheetDecoration(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModalHandle(),
              const SizedBox(height: Spacing.xl),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customize First Screen',
                      style: AppStyles.titleStyle(context)
                          .copyWith(fontSize: RT.title2(context)),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Select investment types to show on the first screen',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // Selected Count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected: ${_tempSelectedTypes.length}/$_maxSelectable',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.prefsController.getRemainingSlots() > 0)
                      Text(
                        '${widget.prefsController.getRemainingSlots()} slot${widget.prefsController.getRemainingSlots() > 1 ? 's' : ''} left',
                        style: const TextStyle(
                          color: AppStyles.accentBlue,
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.lg),

              // All Investment Types List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children:
                      InvestmentTypePreferencesController.allTypes.map((type) {
                    final isSelected = _tempSelectedTypes.contains(type);
                    final details = widget.investmentTypeDetails[type]!;
                    final investment = Investment(
                      id: '',
                      name: '',
                      type: type,
                      amount: 0,
                      color: CupertinoColors.systemGrey,
                    );
                    final color = investment.getTypeColor();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _tempSelectedTypes.remove(type);
                            } else {
                              if (_tempSelectedTypes.length < _maxSelectable) {
                                _tempSelectedTypes.add(type);
                              }
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(Spacing.md),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.1)
                                : AppStyles.getCardColor(context),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : AppStyles.getSecondaryTextColor(context)
                                      .withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    details['icon'],
                                    size: 20,
                                    color: color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                child: Text(
                                  details['label'],
                                  style: TextStyle(
                                    fontSize: TypeScale.body,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: AppStyles.getTextColor(context),
                                  ),
                                ),
                              ),
                              CupertinoSwitch(
                                value: isSelected,
                                activeTrackColor: color,
                                onChanged: (_tempSelectedTypes.length < 6 ||
                                        isSelected)
                                    ? (value) {
                                        setState(() {
                                          if (value) {
                                            _tempSelectedTypes.add(type);
                                          } else {
                                            _tempSelectedTypes.remove(type);
                                          }
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // Save Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: CupertinoColors.systemGrey3,
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: CupertinoButton(
                        color: AppStyles.accentBlue,
                        onPressed: () {
                          widget.prefsController
                              .savePreferences(_tempSelectedTypes);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
