import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/logic/bond_cashflow_model.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller_v2.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class BondRatesStep extends StatefulWidget {
  final BondsWizardControllerV2 ctrl;

  const BondRatesStep(this.ctrl, {super.key});

  @override
  State<BondRatesStep> createState() => _BondRatesStepState();
}

class _BondRatesStepState extends State<BondRatesStep> {
  late TextEditingController _rateController;
  late TextEditingController _spreadController;

  @override
  void initState() {
    super.initState();
    _rateController = TextEditingController();
    _spreadController = TextEditingController();
  }

  @override
  void dispose() {
    _rateController.dispose();
    _spreadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate Information', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          if (widget.ctrl.selectedType == BondType.fixedCoupon ||
              widget.ctrl.selectedType == BondType.monthlyFixed) ...[
            _FixedCouponRateInput(ctrl: widget.ctrl),
          ] else if (widget.ctrl.selectedType == BondType.zeroCoupon) ...[
            _ZeroCouponInput(ctrl: widget.ctrl),
          ] else if (widget.ctrl.selectedType == BondType.amortizing) ...[
            _AmortizingRateInput(ctrl: widget.ctrl),
          ] else if (widget.ctrl.selectedType == BondType.floatingRate) ...[
            _FloatingRateInput(ctrl: widget.ctrl),
          ],
        ],
      ),
    );
  }
}

class _FixedCouponRateInput extends StatefulWidget {
  final BondsWizardControllerV2 ctrl;

  const _FixedCouponRateInput({required this.ctrl});

  @override
  State<_FixedCouponRateInput> createState() => _FixedCouponRateInputState();
}

class _FixedCouponRateInputState extends State<_FixedCouponRateInput> {
  late TextEditingController _couponController;

  @override
  void initState() {
    super.initState();
    _couponController = TextEditingController(
      text: widget.ctrl.fixedCouponRate?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Annual Coupon Rate (%)',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
        const SizedBox(height: Spacing.md),
        CupertinoTextField(
          controller: _couponController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: '0.00',
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: const Text('%'),
          ),
          onChanged: (v) {
            final rate = double.tryParse(v) ?? 0;
            if (rate >= 0) widget.ctrl.updateFixedCouponRate(rate);
          },
        ),
        const SizedBox(height: Spacing.md),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF00A6CC).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'This rate is used for all coupon payments.',
            style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context)),
          ),
        ),
      ],
    );
  }
}

class _ZeroCouponInput extends StatefulWidget {
  final BondsWizardControllerV2 ctrl;

  const _ZeroCouponInput({required this.ctrl});

  @override
  State<_ZeroCouponInput> createState() => _ZeroCouponInputState();
}

class _ZeroCouponInputState extends State<_ZeroCouponInput> {
  late TextEditingController _maturityValueController;

  @override
  void initState() {
    super.initState();
    _maturityValueController = TextEditingController(
      text: widget.ctrl.zeroMaturityValue?.toString() ??
          widget.ctrl.faceValue.toString(),
    );
  }

  @override
  void dispose() {
    _maturityValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Maturity Value (₹)',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
        const SizedBox(height: Spacing.md),
        CupertinoTextField(
          controller: _maturityValueController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: '1000',
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: const Text('₹'),
          ),
          onChanged: (v) {
            final value = double.tryParse(v) ?? 0;
            if (value > 0) widget.ctrl.updateZeroMaturityValue(value);
          },
        ),
        const SizedBox(height: Spacing.md),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF00A6CC).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No coupon payments. You receive only the maturity value at the end.',
                style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Implicit yield: (${widget.ctrl.zeroMaturityValue?.toStringAsFixed(0) ?? widget.ctrl.faceValue.toStringAsFixed(0)} / ${widget.ctrl.purchasePrice.toStringAsFixed(2)})^(1/years) - 1',
                style: TextStyle(
                    fontSize: TypeScale.caption,
                    color: AppStyles.getSecondaryTextColor(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AmortizingRateInput extends StatefulWidget {
  final BondsWizardControllerV2 ctrl;

  const _AmortizingRateInput({required this.ctrl});

  @override
  State<_AmortizingRateInput> createState() => _AmortizingRateInputState();
}

class _AmortizingRateInputState extends State<_AmortizingRateInput> {
  late TextEditingController _interestController;

  @override
  void initState() {
    super.initState();
    _interestController = TextEditingController(
      text: widget.ctrl.interestRate?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _interestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Annual Interest Rate (%)',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
        const SizedBox(height: Spacing.md),
        CupertinoTextField(
          controller: _interestController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: '0.00',
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: const Text('%'),
          ),
          onChanged: (v) {
            final rate = double.tryParse(v) ?? 0;
            if (rate >= 0) widget.ctrl.updateInterestRate(rate);
          },
        ),
        const SizedBox(height: Spacing.md),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF00A6CC).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Principal is repaid gradually. Interest decreases over time as balance decreases.',
            style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context)),
          ),
        ),
      ],
    );
  }
}

class _FloatingRateInput extends StatefulWidget {
  final BondsWizardControllerV2 ctrl;

  const _FloatingRateInput({required this.ctrl});

  @override
  State<_FloatingRateInput> createState() => _FloatingRateInputState();
}

class _FloatingRateInputState extends State<_FloatingRateInput> {
  late TextEditingController _referenceController;
  late TextEditingController _spreadController;

  @override
  void initState() {
    super.initState();
    _referenceController = TextEditingController(
      text: widget.ctrl.referenceRate?.toString() ?? '',
    );
    _spreadController = TextEditingController(
      text: widget.ctrl.spread?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _spreadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentRate =
        ((widget.ctrl.referenceRate ?? 0) + (widget.ctrl.spread ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reference Rate (%) - Current',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
        const SizedBox(height: Spacing.md),
        CupertinoTextField(
          controller: _referenceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: '0.00',
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: const Text('%'),
          ),
          onChanged: (v) {
            final rate = double.tryParse(v) ?? 0;
            widget.ctrl.updateReferenceRate(rate);
          },
        ),
        const SizedBox(height: Spacing.xxl),
        Text('Spread (%) - Fixed',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
        const SizedBox(height: Spacing.md),
        CupertinoTextField(
          controller: _spreadController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: '0.00',
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: const Text('%'),
          ),
          onChanged: (v) {
            final spread = double.tryParse(v) ?? 0;
            widget.ctrl.updateSpread(spread);
          },
        ),
        const SizedBox(height: Spacing.md),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF00A6CC).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Coupon Rate = Reference Rate + Spread',
                style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.getTextColor(context)),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Current Rate: ${currentRate.toStringAsFixed(2)}%',
                style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00A6CC)),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Coupon adjusts as reference rate changes. You maintain this record manually as rates change.',
                style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getSecondaryTextColor(context)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
