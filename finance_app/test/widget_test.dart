import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/bond_cashflow_model.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller_v2.dart';

void main() {
  test('Account round-trip preserves extended fields', () {
    final now = DateTime(2025, 1, 2, 3, 4, 5);
    final original = Account(
      id: 'acc-1',
      name: 'Primary Savings',
      bankName: 'Test Bank',
      type: AccountType.savings,
      balance: 1234.56,
      color: const Color(0xFF123456),
      creditCardNumber: null,
      creditLimit: null,
      currency: 'INR',
      institutionName: 'Test Institution',
      createdDate: now,
      metadata: const {
        'archived': true,
        'tags': ['test']
      },
    );

    final roundTripped = Account.fromMap(original.toMap());

    expect(roundTripped.id, original.id);
    expect(roundTripped.name, original.name);
    expect(roundTripped.bankName, original.bankName);
    expect(roundTripped.type, original.type);
    expect(roundTripped.balance, original.balance);
    expect(roundTripped.color.toARGB32(), original.color.toARGB32());
    expect(roundTripped.currency, 'INR');
    expect(roundTripped.institutionName, 'Test Institution');
    expect(roundTripped.createdDate.toIso8601String(), now.toIso8601String());
    expect(roundTripped.metadata?['archived'], true);
  });

  test('BondsWizardControllerV2 generates fixed coupon cash flows', () {
    final ctrl = BondsWizardControllerV2()
      ..selectType(BondType.fixedCoupon)
      ..updatePurchaseDate(DateTime(2024, 1, 1))
      ..updateMaturityDate(DateTime(2026, 1, 1))
      ..updatePurchasePrice(950)
      ..updateFaceValue(1000)
      ..updateFixedCouponRate(8)
      ..updatePaymentsPerYear(2);

    final flows = ctrl.generatedCashFlows;

    expect(flows, isNotEmpty);
    expect(flows.first.amount, lessThan(0)); // Initial purchase outflow.
    expect(ctrl.totalInvested, greaterThan(0));
    expect(ctrl.totalReceived, greaterThan(0));
    expect(ctrl.calculatedYield, isNotNull);

    ctrl.dispose();
  });
}
