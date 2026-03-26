import 'dart:math' as math;
import 'package:vittara_fin_os/logic/fd_renewal_cycle.dart';

/// Utility class for FD calculations
class FDCalculations {
  /// Calculate CAGR (Compound Annual Growth Rate) based on actual elapsed days
  ///
  /// CAGR = (Current Value / Original Invested)^(1 / Years Elapsed) - 1
  /// Where Years Elapsed = Total Days / 365.25
  static double calculateCAGR(
    double originalInvested,
    double currentValue,
    DateTime originalInvestmentDate,
    DateTime asOfDate,
  ) {
    if (originalInvested <= 0 || currentValue <= 0) return 0;
    if (originalInvestmentDate.isAfter(asOfDate)) return 0;

    // Calculate exact days elapsed
    final daysDifference = asOfDate.difference(originalInvestmentDate).inDays;

    // If less than 1 day, return 0
    if (daysDifference == 0) return 0;

    // Convert days to years (365.25 accounts for leap years)
    final yearsElapsed = daysDifference / 365.25;

    // CAGR formula
    final ratio = currentValue / originalInvested;
    final cagr = (math.pow(ratio, 1 / yearsElapsed) - 1) * 100;

    return cagr.isFinite ? cagr.toDouble() : 0.0;
  }

  /// Calculate total current value across all cycles
  static double calculateTotalCurrentValue(
    List<FDRenewalCycle> cycles,
    DateTime asOfDate,
  ) {
    if (cycles.isEmpty) return 0;

    // Get the latest cycle (current active cycle)
    final latestCycle = cycles.last;
    return latestCycle.getAccruedValue(asOfDate);
  }

  /// Calculate total interest earned across all cycles
  static double calculateTotalInterestEarned(
    double originalInvested,
    double currentValue,
  ) {
    return currentValue - originalInvested;
  }

  /// Get the original invested amount (from first cycle)
  static double getOriginalInvested(List<FDRenewalCycle> cycles) {
    if (cycles.isEmpty) return 0;
    return cycles.first.principal;
  }

  /// Get the current cycle
  static FDRenewalCycle? getCurrentCycle(List<FDRenewalCycle> cycles) {
    if (cycles.isEmpty) return null;
    return cycles.last;
  }

  /// Check if FD is still active (current cycle not completed/withdrawn)
  static bool isActive(List<FDRenewalCycle> cycles) {
    final currentCycle = getCurrentCycle(cycles);
    if (currentCycle == null) return false;
    return !currentCycle.isCompleted && !currentCycle.isWithdrawn;
  }

  /// Get days until maturity for current cycle
  static int getDaysUntilMaturity(List<FDRenewalCycle> cycles) {
    final currentCycle = getCurrentCycle(cycles);
    if (currentCycle == null) return 0;
    return currentCycle.maturityDate.difference(DateTime.now()).inDays;
  }

  /// Calculate the effective/average rate across all cycles
  static double calculateEffectiveRate(List<FDRenewalCycle> cycles) {
    if (cycles.isEmpty) return 0;
    // Simple average of all cycle rates
    final totalRate =
        cycles.fold<double>(0, (sum, cycle) => sum + cycle.interestRate);
    return totalRate / cycles.length;
  }
}
