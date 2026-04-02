import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider;
import 'package:flutter/services.dart';
import 'package:vittara_fin_os/logic/insurance_model.dart';
import 'package:vittara_fin_os/logic/insurance_rider_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';

/// Opens the rider add/edit sheet. Returns the saved rider via [onSave].
void showInsuranceRiderForm(
  BuildContext context, {
  required InsuranceType insuranceType,
  InsuranceRider? existing,
  required void Function(InsuranceRider) onSave,
}) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _InsuranceRiderForm(
      insuranceType: insuranceType,
      existing: existing,
      onSave: onSave,
    ),
  );
}

class _InsuranceRiderForm extends StatefulWidget {
  final InsuranceType insuranceType;
  final InsuranceRider? existing;
  final void Function(InsuranceRider) onSave;

  const _InsuranceRiderForm({
    required this.insuranceType,
    this.existing,
    required this.onSave,
  });

  @override
  State<_InsuranceRiderForm> createState() => _InsuranceRiderFormState();
}

class _InsuranceRiderFormState extends State<_InsuranceRiderForm> {
  // ── State ──────────────────────────────────────────────────────────────────
  late InsuranceRiderType _type;
  late bool _typeSelected;

  final _nameCtrl = TextEditingController();
  final _premiumCtrl = TextEditingController();
  final _sumAssuredCtrl = TextEditingController();
  final _illnessCountCtrl = TextEditingController();
  final _vehicleAgeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late String _premiumFrequency;
  late bool _isInbuilt;
  late bool _hasOwnTenure;
  late bool _isCiAccelerated;

  DateTime? _riderStartDate;
  DateTime? _riderEndDate;
  int? _waitingPeriodDays;
  int? _survivalPeriodDays;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.type;
      _typeSelected = true;
      _nameCtrl.text = e.riderName;
      _premiumCtrl.text = e.riderPremium > 0 ? e.riderPremium.toStringAsFixed(0) : '';
      _sumAssuredCtrl.text = e.riderSumAssured != null ? e.riderSumAssured!.toStringAsFixed(0) : '';
      _illnessCountCtrl.text = e.illnessCount?.toString() ?? '';
      _vehicleAgeCtrl.text = e.vehicleAgeEligibilityYears?.toString() ?? '';
      _notesCtrl.text = e.notes ?? '';
      _premiumFrequency = e.premiumFrequency;
      _isInbuilt = e.isInbuilt;
      _hasOwnTenure = e.hasOwnTenure;
      _isCiAccelerated = e.isCiAccelerated ?? false;
      _riderStartDate = e.riderStartDate;
      _riderEndDate = e.riderEndDate;
      _waitingPeriodDays = e.waitingPeriodDays;
      _survivalPeriodDays = e.survivalPeriodDays;
    } else {
      final available = kRidersForInsuranceType[widget.insuranceType] ?? [];
      _type = available.isNotEmpty ? available.first : InsuranceRiderType.accidentalDeathBenefit;
      _typeSelected = false;
      _premiumFrequency = 'annual';
      _isInbuilt = false;
      _hasOwnTenure = false;
      _isCiAccelerated = false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _premiumCtrl.dispose();
    _sumAssuredCtrl.dispose();
    _illnessCountCtrl.dispose();
    _vehicleAgeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Type selector page ────────────────────────────────────────────────────

  void _onTypeSelected(InsuranceRiderType t) {
    setState(() {
      _type = t;
      _typeSelected = true;
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = t.displayName;
      if (t.canBeInbuilt) _isInbuilt = true;
    });
  }

  // ── Date pickers ──────────────────────────────────────────────────────────

  void _pickDate({required bool isStart}) {
    final initial = isStart
        ? (_riderStartDate ?? DateTime.now())
        : (_riderEndDate ?? DateTime.now().add(const Duration(days: 365)));
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final isDark = AppStyles.isDarkMode(ctx);
        return Container(
          height: 280,
          color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: initial,
                  onDateTimeChanged: (d) => setState(() {
                    if (isStart) _riderStartDate = d; else _riderEndDate = d;
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Waiting period picker ─────────────────────────────────────────────────

  void _pickWaitingPeriod() {
    final options = [30, 60, 90, 120, 180, 365, 730, 1095, 1460];
    final labels = ['30 days', '60 days', '90 days', '4 months', '6 months', '1 year', '2 years', '3 years', '4 years'];
    final current = _waitingPeriodDays ?? 90;
    int selectedIdx = options.indexOf(current);
    if (selectedIdx < 0) selectedIdx = 2;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final isDark = AppStyles.isDarkMode(ctx);
        return Container(
          height: 260,
          color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: selectedIdx),
                  itemExtent: 40,
                  onSelectedItemChanged: (i) => setState(() => _waitingPeriodDays = options[i]),
                  children: labels.map((l) => Center(child: Text(l))).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _pickSurvivalPeriod() {
    final options = [14, 30, 60, 90];
    final labels = ['14 days', '30 days', '60 days', '90 days'];
    final current = _survivalPeriodDays ?? 30;
    int selectedIdx = options.indexOf(current);
    if (selectedIdx < 0) selectedIdx = 1;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final isDark = AppStyles.isDarkMode(ctx);
        return Container(
          height: 240,
          color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground.resolveFrom(ctx),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: selectedIdx),
                  itemExtent: 40,
                  onSelectedItemChanged: (i) => setState(() => _survivalPeriodDays = options[i]),
                  children: labels.map((l) => Center(child: Text(l))).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  void _save() {
    if (!_typeSelected) {
      toast.showError('Please select a rider type');
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      toast.showError('Enter a rider name');
      return;
    }
    if (!_isInbuilt) {
      final p = double.tryParse(_premiumCtrl.text.trim());
      if (p == null || p <= 0) {
        toast.showError('Enter a valid premium amount');
        return;
      }
    }

    final rider = InsuranceRider(
      id: widget.existing?.id ?? IdGenerator.next(),
      type: _type,
      riderName: name,
      riderPremium: _isInbuilt ? 0 : (double.tryParse(_premiumCtrl.text.trim()) ?? 0),
      premiumFrequency: _premiumFrequency,
      riderSumAssured: _type.hasSumAssured
          ? double.tryParse(_sumAssuredCtrl.text.trim())
          : null,
      hasOwnTenure: _hasOwnTenure,
      riderStartDate: _hasOwnTenure ? _riderStartDate : null,
      riderEndDate: _hasOwnTenure ? _riderEndDate : null,
      isInbuilt: _isInbuilt,
      isActive: true,
      waitingPeriodDays: _type.hasWaitingPeriod ? _waitingPeriodDays : null,
      survivalPeriodDays: _type.hasSurvivalPeriod ? _survivalPeriodDays : null,
      illnessCount: _type.hasCIOptions
          ? int.tryParse(_illnessCountCtrl.text.trim())
          : null,
      isCiAccelerated: _type.hasCIOptions ? _isCiAccelerated : null,
      vehicleAgeEligibilityYears: _type.hasVehicleAgeGate
          ? int.tryParse(_vehicleAgeCtrl.text.trim())
          : null,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    widget.onSave(rider);
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final bg = isDark ? const Color(0xFF0D0D0D) : CupertinoColors.systemBackground.resolveFrom(context);
    final primaryText = AppStyles.getTextColor(context);
    final secondaryText = AppStyles.getSecondaryTextColor(context);
    final cardColor = isDark ? const Color(0xFF141414) : const Color(0xFFF7F7F7);
    final borderColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ModalHandle(),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existing != null ? 'Edit Rider' : 'Add Rider',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: primaryText,
                          ),
                        ),
                        if (_typeSelected)
                          Text(_type.displayName, style: TextStyle(fontSize: 12, color: secondaryText)),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: Icon(CupertinoIcons.xmark_circle_fill,
                        color: secondaryText.withValues(alpha: 0.3), size: 26),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Rider type selector ─────────────────────────────────
                    if (widget.existing == null) ...[
                      _sectionLabel('Select Rider Type', isDark),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (kRidersForInsuranceType[widget.insuranceType] ?? []).map((t) {
                          final isSelected = _typeSelected && _type == t;
                          return GestureDetector(
                            onTap: () => _onTypeSelected(t),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppStyles.accentBlue.withValues(alpha: 0.15)
                                    : cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? AppStyles.accentBlue.withValues(alpha: 0.7)
                                      : borderColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                t.displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? AppStyles.accentBlue : primaryText,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_typeSelected) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppStyles.accentBlue.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(CupertinoIcons.info_circle, size: 13, color: AppStyles.accentBlue),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _type.shortDescription,
                                  style: TextStyle(fontSize: 11, color: AppStyles.accentBlue, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],

                    if (_typeSelected) ...[

                      // ── Inbuilt toggle ──────────────────────────────────
                      if (_type.canBeInbuilt) ...[
                        _sectionLabel('Inbuilt / Free', isDark),
                        _switchRow(
                          icon: CupertinoIcons.gift_fill,
                          title: 'Included at no extra cost',
                          subtitle: 'Some riders are inbuilt in the base policy',
                          value: _isInbuilt,
                          color: AppStyles.gain(context),
                          onChanged: (v) => setState(() => _isInbuilt = v),
                          cardColor: cardColor,
                          borderColor: borderColor,
                          isDark: isDark,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                        ),
                        const SizedBox(height: 10),
                      ],

                      // ── Basic details ───────────────────────────────────
                      _sectionLabel('Rider Details', isDark),
                      _inputField(
                        controller: _nameCtrl,
                        placeholder: 'Rider name (e.g. ADB Rider)',
                        label: 'Name',
                        isDark: isDark,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        cardColor: cardColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(height: 8),

                      // Premium
                      if (!_isInbuilt) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _inputField(
                                controller: _premiumCtrl,
                                placeholder: '0',
                                label: 'Premium (₹)',
                                isDark: isDark,
                                primaryText: primaryText,
                                secondaryText: secondaryText,
                                cardColor: cardColor,
                                borderColor: borderColor,
                                keyboard: const TextInputType.numberWithOptions(decimal: true),
                                prefix: '₹',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _dropdownField(
                                label: 'Frequency',
                                value: _premiumFrequency,
                                options: const ['annual', 'monthly', 'single_pay'],
                                labels: const ['Annual', 'Monthly', 'Single Pay'],
                                isDark: isDark,
                                primaryText: primaryText,
                                secondaryText: secondaryText,
                                cardColor: cardColor,
                                borderColor: borderColor,
                                onChanged: (v) => setState(() => _premiumFrequency = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Sum Assured (if applicable)
                      if (_type.hasSumAssured) ...[
                        _inputField(
                          controller: _sumAssuredCtrl,
                          placeholder: '0',
                          label: _type.sumAssuredLabel,
                          isDark: isDark,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          keyboard: const TextInputType.numberWithOptions(decimal: true),
                          prefix: _type == InsuranceRiderType.globalCover ? 'USD' : '₹',
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── CI-specific fields ──────────────────────────────
                      if (_type.hasCIOptions) ...[
                        _sectionLabel('Critical Illness Details', isDark),
                        _inputField(
                          controller: _illnessCountCtrl,
                          placeholder: 'e.g. 36',
                          label: 'No. of illnesses covered',
                          isDark: isDark,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          keyboard: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                        if (_type == InsuranceRiderType.criticalIllnessLife) ...[
                          _switchRow(
                            icon: CupertinoIcons.arrow_down_circle_fill,
                            title: 'Accelerated payout',
                            subtitle: 'CI payout reduces base sum assured (vs paid on top)',
                            value: _isCiAccelerated,
                            color: AppStyles.accentOrange,
                            onChanged: (v) => setState(() => _isCiAccelerated = v),
                            cardColor: cardColor,
                            borderColor: borderColor,
                            isDark: isDark,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],

                      // ── Waiting / Survival periods ──────────────────────
                      if (_type.hasWaitingPeriod || _type.hasSurvivalPeriod) ...[
                        _sectionLabel('Periods', isDark),
                        if (_type.hasWaitingPeriod) ...[
                          GestureDetector(
                            onTap: _pickWaitingPeriod,
                            child: _infoRow(
                              icon: CupertinoIcons.clock,
                              color: AppStyles.accentOrange,
                              label: 'Waiting period',
                              value: _waitingPeriodDays != null ? _formatDays(_waitingPeriodDays!) : 'Tap to set',
                              cardColor: cardColor,
                              borderColor: borderColor,
                              primaryText: primaryText,
                              secondaryText: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_type.hasSurvivalPeriod) ...[
                          GestureDetector(
                            onTap: _pickSurvivalPeriod,
                            child: _infoRow(
                              icon: CupertinoIcons.waveform_path_ecg,
                              color: AppStyles.accentBlue,
                              label: 'Survival period',
                              value: _survivalPeriodDays != null ? _formatDays(_survivalPeriodDays!) : 'Tap to set',
                              cardColor: cardColor,
                              borderColor: borderColor,
                              primaryText: primaryText,
                              secondaryText: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],

                      // ── Vehicle age gate ────────────────────────────────
                      if (_type.hasVehicleAgeGate) ...[
                        _sectionLabel('Eligibility', isDark),
                        _inputField(
                          controller: _vehicleAgeCtrl,
                          placeholder: 'e.g. 5',
                          label: 'Max vehicle age for this add-on (years)',
                          isDark: isDark,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          keyboard: TextInputType.number,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── Own tenure ──────────────────────────────────────
                      if (_type.canHaveOwnTenure) ...[
                        _sectionLabel('Tenure', isDark),
                        _switchRow(
                          icon: CupertinoIcons.calendar_badge_minus,
                          title: 'Rider has shorter tenure',
                          subtitle: 'This rider ends before the base policy',
                          value: _hasOwnTenure,
                          color: AppStyles.violet(context),
                          onChanged: (v) => setState(() => _hasOwnTenure = v),
                          cardColor: cardColor,
                          borderColor: borderColor,
                          isDark: isDark,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                        ),
                        if (_hasOwnTenure) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _pickDate(isStart: true),
                                  child: _infoRow(
                                    icon: CupertinoIcons.calendar,
                                    color: AppStyles.accentBlue,
                                    label: 'Start date',
                                    value: _riderStartDate != null ? DateFormatter.format(_riderStartDate!) : 'Select',
                                    cardColor: cardColor,
                                    borderColor: borderColor,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _pickDate(isStart: false),
                                  child: _infoRow(
                                    icon: CupertinoIcons.calendar_badge_minus,
                                    color: AppStyles.loss(context),
                                    label: 'End date',
                                    value: _riderEndDate != null ? DateFormatter.format(_riderEndDate!) : 'Select',
                                    cardColor: cardColor,
                                    borderColor: borderColor,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],

                      // ── Notes ───────────────────────────────────────────
                      _sectionLabel('Notes (optional)', isDark),
                      _inputField(
                        controller: _notesCtrl,
                        placeholder: 'Any additional details...',
                        label: '',
                        isDark: isDark,
                        primaryText: primaryText,
                        secondaryText: secondaryText,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        maxLines: 3,
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Save button ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _typeSelected ? AppStyles.accentBlue : AppStyles.accentBlue.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      widget.existing != null ? 'Update Rider' : 'Add Rider',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  String _formatDays(int days) {
    if (days < 30) return '$days days';
    if (days == 30) return '30 days';
    if (days == 60) return '60 days';
    if (days == 90) return '90 days';
    if (days == 120) return '4 months';
    if (days == 180) return '6 months';
    if (days == 365) return '1 year';
    if (days == 730) return '2 years';
    if (days == 1095) return '3 years';
    if (days == 1460) return '4 years';
    return '$days days';
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF5A6A80) : const Color(0xFF8899AA),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: isDark ? const Color(0xFF1C2A3A) : const Color(0xFFDDEEFF), height: 1)),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String placeholder,
    required String label,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color cardColor,
    required Color borderColor,
    TextInputType? keyboard,
    String? prefix,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: TextStyle(fontSize: 12, color: secondaryText)),
          ),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboard,
          maxLines: maxLines,
          style: TextStyle(color: primaryText, fontSize: 14),
          placeholderStyle: TextStyle(color: secondaryText.withValues(alpha: 0.5), fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefix: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(prefix, style: TextStyle(color: secondaryText, fontSize: 13)),
                )
              : null,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> options,
    required List<String> labels,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required Color cardColor,
    required Color borderColor,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(label, style: TextStyle(fontSize: 12, color: secondaryText)),
        ),
        GestureDetector(
          onTap: () {
            final idx = options.indexOf(value);
            showCupertinoModalPopup<void>(
              context: context,
              builder: (ctx) {
                return Container(
                  height: 240,
                  color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground.resolveFrom(ctx),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          CupertinoButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(initialItem: idx >= 0 ? idx : 0),
                          itemExtent: 40,
                          onSelectedItemChanged: (i) => onChanged(options[i]),
                          children: labels.map((l) => Center(child: Text(l))).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    labels[options.indexOf(value) >= 0 ? options.indexOf(value) : 0],
                    style: TextStyle(fontSize: 14, color: primaryText),
                  ),
                ),
                Icon(CupertinoIcons.chevron_down, size: 12, color: secondaryText),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
    required Color cardColor,
    required Color borderColor,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? color.withValues(alpha: 0.4) : borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: value ? color : secondaryText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryText)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: secondaryText)),
              ],
            ),
          ),
          CupertinoSwitch(value: value, activeTrackColor: color, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required Color cardColor,
    required Color borderColor,
    required Color primaryText,
    required Color secondaryText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: secondaryText)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryText)),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right, size: 12, color: secondaryText),
        ],
      ),
    );
  }
}
