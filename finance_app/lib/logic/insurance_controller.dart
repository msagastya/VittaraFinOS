import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vittara_fin_os/logic/insurance_model.dart';

const String _kInsurancePoliciesKey = 'insurance_policies';

class InsuranceController with ChangeNotifier {
  List<InsurancePolicy> _policies = [];

  List<InsurancePolicy> get policies => List.unmodifiable(_policies);

  List<InsurancePolicy> get activePolicies =>
      _policies.where((p) => p.isActive).toList();

  List<InsurancePolicy> get policiesExpiringSoon =>
      activePolicies.where((p) => p.isExpiringSoon).toList();

  double get totalAnnualPremium =>
      activePolicies.fold(0.0, (sum, p) => sum + p.annualPremium);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kInsurancePoliciesKey);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList =
            jsonDecode(jsonString) as List<dynamic>;
        _policies = jsonList
            .map((item) =>
                InsurancePolicy.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {
        _policies = [];
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString =
        jsonEncode(_policies.map((p) => p.toMap()).toList());
    await prefs.setString(_kInsurancePoliciesKey, jsonString);
  }

  Future<void> addPolicy(InsurancePolicy policy) async {
    _policies.add(policy);
    await _save();
    notifyListeners();
  }

  Future<void> updatePolicy(InsurancePolicy policy) async {
    final index = _policies.indexWhere((p) => p.id == policy.id);
    if (index != -1) {
      _policies[index] = policy;
      await _save();
      notifyListeners();
    }
  }

  Future<void> deletePolicy(String id) async {
    _policies.removeWhere((p) => p.id == id);
    await _save();
    notifyListeners();
  }

  InsurancePolicy? getPolicyById(String id) {
    try {
      return _policies.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<InsurancePolicy> get policiesWithActiveMandate =>
      activePolicies
          .where((p) => p.mandateEnabled && p.mandateNextDueDate != null)
          .toList();

  Future<void> advanceMandateDate(String policyId) async {
    final policy = getPolicyById(policyId);
    if (policy == null || policy.mandateNextDueDate == null) return;
    final cur = policy.mandateNextDueDate!;
    final DateTime next;
    switch (policy.premiumFrequency) {
      case 'monthly':
        next = DateTime(cur.year, cur.month + 1, cur.day);
        break;
      case 'quarterly':
        next = DateTime(cur.year, cur.month + 3, cur.day);
        break;
      case 'annual':
      default:
        next = DateTime(cur.year + 1, cur.month, cur.day);
    }
    await updatePolicy(policy.copyWith(mandateNextDueDate: next));
  }
}
