import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller_v2.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class BondConfirmationStep extends StatelessWidget {
  final BondsWizardControllerV2 ctrl;

  const BondConfirmationStep(this.ctrl, {super.key});

  @override
  Widget build(BuildContext context) {
    final investmentsController =
        Provider.of<InvestmentsController>(context, listen: false);
    final existingNpsSchemes = investmentsController.investments
        .where((inv) => inv.type.name == 'nationalSavingsScheme')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirmation & NPS Linking',
              style: AppStyles.titleStyle(context)),
          const SizedBox(height: 20),
          _ConfirmationCard(
            title: 'Bond Details',
            children: [
              _ConfirmationRow('Bond Name', ctrl.bondName),
              _ConfirmationRow(
                  'Bond Type', ctrl.selectedType.toString().split('.').last),
              _ConfirmationRow('Purchase Date',
                  '${ctrl.purchaseDate.day}/${ctrl.purchaseDate.month}/${ctrl.purchaseDate.year}'),
              _ConfirmationRow('Maturity Date',
                  '${ctrl.maturityDate.day}/${ctrl.maturityDate.month}/${ctrl.maturityDate.year}'),
              _ConfirmationRow('Purchase Price',
                  '₹${ctrl.purchasePrice.toStringAsFixed(2)}'),
              _ConfirmationRow(
                  'Face Value', '₹${ctrl.faceValue.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 20),
          _ConfirmationCard(
            title: 'Financial Summary',
            children: [
              _ConfirmationRow('Total Invested',
                  '₹${ctrl.totalInvested.toStringAsFixed(2)}'),
              _ConfirmationRow('Total to Receive',
                  '₹${ctrl.totalReceived.toStringAsFixed(2)}'),
              _ConfirmationRow(
                'Gain/Loss',
                '${ctrl.gainLoss >= 0 ? '+' : ''}₹${ctrl.gainLoss.toStringAsFixed(2)}',
                isHighlight: true,
              ),
              _ConfirmationRow(
                'Yield to Maturity',
                '${((ctrl.calculatedYield ?? 0) * 100).toStringAsFixed(2)}%',
                isHighlight: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ConfirmationCard(
            title: 'Account Linking',
            children: [
              _ConfirmationRow(
                'Purchase Account',
                ctrl.purchaseAccountName ?? 'Not linked',
              ),
              const SizedBox(height: 8),
              _ConfirmationRow(
                'Auto-Debit',
                ctrl.autoDebitFromPurchaseAccount ? 'Enabled' : 'Disabled',
              ),
              const SizedBox(height: 8),
              _ConfirmationRow(
                'Payment Account',
                ctrl.paymentAccountName ?? 'Not linked',
              ),
              const SizedBox(height: 8),
              _ConfirmationRow(
                'Auto-Transfer',
                ctrl.autoTransferPayments ? 'Enabled' : 'Disabled',
              ),
            ],
          ),
          const SizedBox(height: 20),
          // NPS Linking Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Link to NPS Scheme (Optional)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                Text(
                  'Some bonds are part of NPS (National Pension Scheme) portfolios. Link this bond to an existing NPS record or create a new one if this bond is a pension investment.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.getSecondaryTextColor(context)),
                ),
                const SizedBox(height: 16),
                // Link to NPS Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Link to NPS?',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    CupertinoSwitch(
                      value: ctrl.linkToNPS,
                      onChanged: (value) => ctrl.updateLinkToNPS(value),
                    ),
                  ],
                ),
                if (ctrl.linkToNPS) ...[
                  const SizedBox(height: 16),
                  // Option 1: Link to existing NPS
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B59B6).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Link to Existing NPS Scheme',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 12),
                        if (existingNpsSchemes.isEmpty)
                          Text(
                            'No NPS schemes found. Create a new one below.',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    AppStyles.getSecondaryTextColor(context)),
                          )
                        else
                          ...existingNpsSchemes.map((nps) {
                            return GestureDetector(
                              onTap: () => ctrl.updateLinkedNps(nps.id),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: ctrl.linkedNpsId == nps.id
                                      ? const Color(0xFF9B59B6)
                                          .withValues(alpha: 0.2)
                                      : AppStyles.getBackground(context),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: ctrl.linkedNpsId == nps.id
                                        ? const Color(0xFF9B59B6)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nps.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (ctrl.linkedNpsId == nps.id)
                                      const Icon(CupertinoIcons.checkmark_alt,
                                          color: Color(0xFF9B59B6), size: 16),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Option 2: Create new NPS
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B59B6).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Create New NPS Entry',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            CupertinoSwitch(
                              value: ctrl.createNewNps,
                              onChanged: (value) =>
                                  ctrl.updateCreateNewNps(value),
                            ),
                          ],
                        ),
                        if (ctrl.createNewNps) ...[
                          const SizedBox(height: 12),
                          CupertinoTextField(
                            placeholder: 'Enter NPS scheme name',
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppStyles.getBackground(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onChanged: (v) => ctrl.updateNewNpsName(v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ConfirmationCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          ...List.generate(
            children.length,
            (i) => Column(
              children: [
                children[i],
                if (i < children.length - 1) const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _ConfirmationRow(
    this.label,
    this.value, {
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppStyles.getSecondaryTextColor(context),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 13,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight
                ? const Color(0xFF00A6CC)
                : AppStyles.getTextColor(context),
          ),
        ),
      ],
    );
  }
}
