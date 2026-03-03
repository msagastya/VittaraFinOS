import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/fo_model.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class FOGreeksStep extends StatefulWidget {
  final FOWizardController ctrl;

  const FOGreeksStep(this.ctrl, {super.key});

  @override
  State<FOGreeksStep> createState() => _FOGreeksStepState();
}

class _FOGreeksStepState extends State<FOGreeksStep> {
  late TextEditingController _strikePriceController;
  late TextEditingController _volatilityController;
  late TextEditingController _riskFreeRateController;

  @override
  void initState() {
    super.initState();
    _strikePriceController = TextEditingController(
      text: widget.ctrl.strikePrice?.toString() ?? '',
    );
    _volatilityController = TextEditingController(
      text: widget.ctrl.volatility?.toString() ?? '20',
    );
    _riskFreeRateController = TextEditingController(
      text: widget.ctrl.riskFreeRate?.toString() ?? '6',
    );
  }

  @override
  void dispose() {
    _strikePriceController.dispose();
    _volatilityController.dispose();
    _riskFreeRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ctrl.selectedType == FOType.futures) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.info_circle_fill,
                  size: 48, color: AppStyles.getSecondaryTextColor(context)),
              const SizedBox(height: Spacing.lg),
              Text('Greeks are not applicable for Futures',
                  style: AppStyles.titleStyle(context),
                  textAlign: TextAlign.center),
              const SizedBox(height: Spacing.sm),
              Text('Greeks are calculated for Options only.',
                  style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context)),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Greeks & Volatility', style: AppStyles.titleStyle(context)),
          const SizedBox(height: 30),
          Text('Strike Price (₹)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _strikePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '0.00',
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
              final price = double.tryParse(v) ?? 0;
              if (price > 0) widget.ctrl.updateStrikePrice(price);
            },
          ),
          const SizedBox(height: Spacing.xxl),
          Text('Volatility (% p.a.)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _volatilityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '20',
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
              final vol = double.tryParse(v) ?? 20;
              if (vol > 0) widget.ctrl.updateVolatility(vol);
            },
          ),
          const SizedBox(height: Spacing.xxl),
          Text('Risk-Free Rate (% p.a.)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
          const SizedBox(height: Spacing.md),
          CupertinoTextField(
            controller: _riskFreeRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '6',
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
              final rate = double.tryParse(v) ?? 6;
              widget.ctrl.updateRiskFreeRate(rate);
            },
          ),
          if (widget.ctrl.greeks != null) ...[
            const SizedBox(height: 30),
            Text('Calculated Greeks',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: TypeScale.body)),
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _GreekRow(
                      'Delta',
                      widget.ctrl.greeks!.delta.toStringAsFixed(4),
                      'Sensitivity to underlying price'),
                  _Divider(),
                  _GreekRow(
                      'Gamma',
                      widget.ctrl.greeks!.gamma.toStringAsFixed(6),
                      'Rate of change of Delta'),
                  _Divider(),
                  _GreekRow(
                      'Theta',
                      widget.ctrl.greeks!.theta.toStringAsFixed(4),
                      'Time decay per day'),
                  _Divider(),
                  _GreekRow('Vega', widget.ctrl.greeks!.vega.toStringAsFixed(4),
                      'Sensitivity to volatility (per 1%)'),
                  _Divider(),
                  _GreekRow('Rho', widget.ctrl.greeks!.rho.toStringAsFixed(4),
                      'Sensitivity to interest rates (per 1%)',
                      isLast: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GreekRow extends StatelessWidget {
  final String label;
  final String value;
  final String description;
  final bool isLast;

  const _GreekRow(this.label, this.value, this.description,
      {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: TypeScale.subhead)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: TypeScale.subhead,
                      color: Color(0xFF1ABC9C))),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(description,
              style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: AppStyles.getSecondaryTextColor(context))),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: CupertinoColors.systemGrey.withValues(alpha: 0.2), height: 1),
    );
  }
}
