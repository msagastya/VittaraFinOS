import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/bond_cashflow_model.dart';
import 'package:vittara_fin_os/logic/budget_model.dart';
import 'package:vittara_fin_os/logic/goal_model.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller_v2.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

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

  // G7: CurrencyFormatter.compact() unit tests
  group('CurrencyFormatter.compact', () {
    test('formats amounts below 1K as plain rupees', () {
      expect(CurrencyFormatter.compact(0), '₹0');
      expect(CurrencyFormatter.compact(500), '₹500');
      expect(CurrencyFormatter.compact(999), '₹999');
    });

    test('formats thousands as K', () {
      expect(CurrencyFormatter.compact(1000), '₹1K');
      expect(CurrencyFormatter.compact(1500), '₹1.5K');
      expect(CurrencyFormatter.compact(99000), '₹99K');
    });

    test('formats lakhs as L', () {
      expect(CurrencyFormatter.compact(100000), '₹1L');
      expect(CurrencyFormatter.compact(250000), '₹2.5L');
    });

    test('formats crores as Cr', () {
      expect(CurrencyFormatter.compact(10000000), '₹1Cr');
      expect(CurrencyFormatter.compact(15000000), '₹1.5Cr');
    });

    test('handles negative amounts with sign prefix', () {
      expect(CurrencyFormatter.compact(-1000), '-₹1K');
      expect(CurrencyFormatter.compact(-100000), '-₹1L');
    });

    test('trims trailing decimal zeros', () {
      expect(CurrencyFormatter.compact(200000), '₹2L');
      expect(CurrencyFormatter.compact(10000000), '₹1Cr');
    });
  });

  // G7: CurrencyFormatter.format() unit tests
  group('CurrencyFormatter.format', () {
    test('formats with Indian number grouping', () {
      expect(CurrencyFormatter.format(250000), '₹2,50,000.00');
      expect(CurrencyFormatter.format(1234567.89), '₹12,34,567.89');
    });

    test('formatSigned adds + for positive values', () {
      expect(CurrencyFormatter.formatSigned(1000), '+₹1,000.00');
      expect(CurrencyFormatter.formatSigned(-1000), '-₹1,000.00');
    });
  });

  // G8: Budget model unit tests
  group('Budget.usagePercentage', () {
    final now = DateTime(2026, 1, 1);
    Budget _budget({required double limit, required double spent}) => Budget(
          id: 'b1',
          name: 'Test',
          limitAmount: limit,
          spentAmount: spent,
          period: BudgetPeriod.monthly,
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          color: const Color(0xFF0000FF),
        );

    test('returns 0 when nothing spent', () {
      expect(_budget(limit: 1000, spent: 0).usagePercentage, 0);
    });

    test('returns 50 at half spent', () {
      expect(_budget(limit: 1000, spent: 500).usagePercentage, 50);
    });

    test('returns 100 when exactly at limit', () {
      expect(_budget(limit: 1000, spent: 1000).usagePercentage, 100);
    });

    test('clamps above 100 when over limit', () {
      expect(_budget(limit: 1000, spent: 1500).usagePercentage, 150);
    });

    test('returns 0 when limit is zero', () {
      expect(_budget(limit: 0, spent: 0).usagePercentage, 0);
    });

    test('exceeded status when over limit', () {
      expect(
        _budget(limit: 1000, spent: 1001).status,
        BudgetStatus.exceeded,
      );
    });

    test('on track status when under limit with no warning threshold', () {
      expect(
        _budget(limit: 1000, spent: 500).status,
        BudgetStatus.onTrack,
      );
    });
  });

  // G9: Goal model unit tests
  group('Goal.progressPercentage', () {
    Goal _goal({required double target, required double current}) => Goal(
          id: 'g1',
          name: 'Test Goal',
          type: GoalType.custom,
          targetAmount: target,
          currentAmount: current,
          targetDate: DateTime(2030),
          color: const Color(0xFF00FF00),
          createdDate: DateTime(2024, 1, 1),
        );

    test('returns 0 when no contribution', () {
      expect(_goal(target: 10000, current: 0).progressPercentage, 0);
    });

    test('returns 50 at halfway', () {
      expect(_goal(target: 10000, current: 5000).progressPercentage, 50);
    });

    test('returns 100 when target reached', () {
      expect(_goal(target: 10000, current: 10000).progressPercentage, 100);
    });

    test('clamps at 100 even if over target', () {
      expect(_goal(target: 10000, current: 12000).progressPercentage, 100);
    });

    test('remaining amount is 0 when target met', () {
      expect(_goal(target: 5000, current: 5000).remainingAmount, 0);
    });

    test('remaining amount is target minus current', () {
      expect(_goal(target: 5000, current: 2000).remainingAmount, 3000);
    });

    test('returns 0 progress when target is 0', () {
      expect(_goal(target: 0, current: 0).progressPercentage, 0);
    });
  });

  test('Account round-trip supports cash account type', () {
    final original = Account(
      id: 'cash-1',
      name: 'Cash in Hand',
      bankName: 'Cash',
      type: AccountType.cash,
      balance: 10000,
      color: const Color(0xFF30D158),
    );

    final restored = Account.fromMap(original.toMap());

    expect(restored.type, AccountType.cash);
    expect(restored.bankName, 'Cash');
    expect(restored.balance, 10000);
  });
}
