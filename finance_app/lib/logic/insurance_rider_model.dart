import 'package:vittara_fin_os/logic/insurance_model.dart';

// Each rider type maps to a specific insurance type.
// The enum values match the IRDAI-recognized riders in India.
enum InsuranceRiderType {
  // ── Term / Life riders ────────────────────────────────────────────────────
  accidentalDeathBenefit,
  accidentalDisability,
  criticalIllnessLife,
  waiverOfPremium,
  terminalIllness,
  incomeBenefit,
  returnOfPremium,
  spouseTerm,
  childTerm,

  // ── Health add-ons ────────────────────────────────────────────────────────
  roomRentWaiver,
  maternity,
  opdCover,
  criticalIllnessHealth,
  hospitalCash,
  personalAccidentHealth,
  pedWaiver,
  restorationBenefit,
  superBonus,
  inflationShield,
  consumablesHealth,
  diseaseSpecific,
  globalCover,
  homeCare,

  // ── Vehicle add-ons ───────────────────────────────────────────────────────
  zeroDepreciation,
  engineProtection,
  returnToInvoice,
  ncbProtection,
  roadsideAssistance,
  consumablesMotor,
  tyreProtection,
  keyReplacement,
  passengerPA,
  dailyAllowance,
  evBatteryCover,

  // ── Home add-ons ──────────────────────────────────────────────────────────
  valuableContents,
  burglaryTheft,
  personalAccidentHome,
  earthquakeCover,
  lossOfRent,
  electronicEquipment,
  publicLiabilityHome,

  // ── Travel add-ons ────────────────────────────────────────────────────────
  adventureSports,
  pedEmergencyTravel,
  tripCancellation,
  baggageDelay,
  flightDelay,
  missedConnection,
  passportLoss,
  personalLiabilityTravel,
  hijackAllowance,
  gadgetCover,
  homeBurglaryTravel,
}

extension InsuranceRiderTypeExtension on InsuranceRiderType {
  String get displayName {
    switch (this) {
      case InsuranceRiderType.accidentalDeathBenefit: return 'Accidental Death Benefit';
      case InsuranceRiderType.accidentalDisability: return 'Accidental Disability';
      case InsuranceRiderType.criticalIllnessLife: return 'Critical Illness';
      case InsuranceRiderType.waiverOfPremium: return 'Waiver of Premium';
      case InsuranceRiderType.terminalIllness: return 'Terminal Illness';
      case InsuranceRiderType.incomeBenefit: return 'Income Benefit';
      case InsuranceRiderType.returnOfPremium: return 'Return of Premium';
      case InsuranceRiderType.spouseTerm: return 'Spouse Term';
      case InsuranceRiderType.childTerm: return 'Child Term';
      case InsuranceRiderType.roomRentWaiver: return 'Room Rent Waiver';
      case InsuranceRiderType.maternity: return 'Maternity & Newborn';
      case InsuranceRiderType.opdCover: return 'OPD Cover';
      case InsuranceRiderType.criticalIllnessHealth: return 'Critical Illness';
      case InsuranceRiderType.hospitalCash: return 'Hospital Cash';
      case InsuranceRiderType.personalAccidentHealth: return 'Personal Accident';
      case InsuranceRiderType.pedWaiver: return 'PED Waiting Period Waiver';
      case InsuranceRiderType.restorationBenefit: return 'Restoration Benefit';
      case InsuranceRiderType.superBonus: return 'Super No-Claim Bonus';
      case InsuranceRiderType.inflationShield: return 'Inflation Shield';
      case InsuranceRiderType.consumablesHealth: return 'Consumables Cover';
      case InsuranceRiderType.diseaseSpecific: return 'Disease-Specific Cover';
      case InsuranceRiderType.globalCover: return 'Global / International Cover';
      case InsuranceRiderType.homeCare: return 'Home Care / Domiciliary';
      case InsuranceRiderType.zeroDepreciation: return 'Zero Depreciation';
      case InsuranceRiderType.engineProtection: return 'Engine & Gearbox Protection';
      case InsuranceRiderType.returnToInvoice: return 'Return to Invoice';
      case InsuranceRiderType.ncbProtection: return 'NCB Protector';
      case InsuranceRiderType.roadsideAssistance: return 'Roadside Assistance';
      case InsuranceRiderType.consumablesMotor: return 'Consumables Cover';
      case InsuranceRiderType.tyreProtection: return 'Tyre & Rim Protection';
      case InsuranceRiderType.keyReplacement: return 'Key Replacement';
      case InsuranceRiderType.passengerPA: return 'Passenger Personal Accident';
      case InsuranceRiderType.dailyAllowance: return 'Daily Allowance (Garage)';
      case InsuranceRiderType.evBatteryCover: return 'EV Battery Cover';
      case InsuranceRiderType.valuableContents: return 'Valuable Contents Cover';
      case InsuranceRiderType.burglaryTheft: return 'Burglary & Theft';
      case InsuranceRiderType.personalAccidentHome: return 'Personal Accident';
      case InsuranceRiderType.earthquakeCover: return 'Earthquake Cover';
      case InsuranceRiderType.lossOfRent: return 'Loss of Rent';
      case InsuranceRiderType.electronicEquipment: return 'Electronic Equipment';
      case InsuranceRiderType.publicLiabilityHome: return 'Public Liability';
      case InsuranceRiderType.adventureSports: return 'Adventure Sports Cover';
      case InsuranceRiderType.pedEmergencyTravel: return 'PED Emergency Cover';
      case InsuranceRiderType.tripCancellation: return 'Trip Cancellation / Interruption';
      case InsuranceRiderType.baggageDelay: return 'Baggage Delay';
      case InsuranceRiderType.flightDelay: return 'Flight Delay';
      case InsuranceRiderType.missedConnection: return 'Missed Connection';
      case InsuranceRiderType.passportLoss: return 'Passport / Document Loss';
      case InsuranceRiderType.personalLiabilityTravel: return 'Personal Liability';
      case InsuranceRiderType.hijackAllowance: return 'Hijack Distress Allowance';
      case InsuranceRiderType.gadgetCover: return 'Gadget / Electronic Cover';
      case InsuranceRiderType.homeBurglaryTravel: return 'Home Burglary (While Travelling)';
    }
  }

  String get shortDescription {
    switch (this) {
      case InsuranceRiderType.accidentalDeathBenefit: return 'Extra lump sum if death from accident (up to 3× base SA)';
      case InsuranceRiderType.accidentalDisability: return 'Lump sum if totally & permanently disabled due to accident';
      case InsuranceRiderType.criticalIllnessLife: return 'Lump sum on diagnosis of listed critical illness';
      case InsuranceRiderType.waiverOfPremium: return 'Future premiums waived on disability or critical illness';
      case InsuranceRiderType.terminalIllness: return 'Early payout if life expectancy < 6–12 months (often inbuilt)';
      case InsuranceRiderType.incomeBenefit: return 'Monthly/annual income to nominees for a fixed period';
      case InsuranceRiderType.returnOfPremium: return 'All premiums returned if you survive the policy term';
      case InsuranceRiderType.spouseTerm: return 'Extends term cover to spouse under same policy';
      case InsuranceRiderType.childTerm: return 'Extends term cover to children under same policy';
      case InsuranceRiderType.roomRentWaiver: return 'Removes or upgrades room rent sub-limit';
      case InsuranceRiderType.maternity: return 'Normal/C-section delivery + newborn cover (2–4 yr waiting period)';
      case InsuranceRiderType.opdCover: return 'Consultations, pharmacy & diagnostics without hospitalization';
      case InsuranceRiderType.criticalIllnessHealth: return 'Lump sum on first diagnosis of listed critical illness';
      case InsuranceRiderType.hospitalCash: return 'Fixed daily cash for each day of hospitalization';
      case InsuranceRiderType.personalAccidentHealth: return 'Lump sum for accidental death or disability';
      case InsuranceRiderType.pedWaiver: return 'Reduces waiting period for pre-existing diseases';
      case InsuranceRiderType.restorationBenefit: return 'Restores sum insured once exhausted in the year';
      case InsuranceRiderType.superBonus: return 'Sum insured grows each claim-free year';
      case InsuranceRiderType.inflationShield: return 'Auto-increases SI annually to beat medical inflation';
      case InsuranceRiderType.consumablesHealth: return 'Covers consumables (gloves, syringes, PPE) excluded in base';
      case InsuranceRiderType.diseaseSpecific: return 'Targeted cover for a specific chronic condition';
      case InsuranceRiderType.globalCover: return 'Extends health cover for treatment abroad';
      case InsuranceRiderType.homeCare: return 'Covers treatment at home when hospitalization isn\'t possible';
      case InsuranceRiderType.zeroDepreciation: return 'Full claim without depreciation deduction on parts';
      case InsuranceRiderType.engineProtection: return 'Covers waterlogging/hydrostatic lock damage to engine';
      case InsuranceRiderType.returnToInvoice: return 'Claim = original invoice value in case of total loss';
      case InsuranceRiderType.ncbProtection: return 'Protects no-claim bonus even after a claim';
      case InsuranceRiderType.roadsideAssistance: return '24×7 on-road help: towing, flat tyre, battery jump-start';
      case InsuranceRiderType.consumablesMotor: return 'Covers nuts, bolts, oil, grease & other consumables';
      case InsuranceRiderType.tyreProtection: return 'Covers tyre/rim damage not due to accident';
      case InsuranceRiderType.keyReplacement: return 'Covers cost of lost or stolen keys and lock replacement';
      case InsuranceRiderType.passengerPA: return 'Personal accident cover for passengers in the vehicle';
      case InsuranceRiderType.dailyAllowance: return 'Daily cash while your vehicle is in garage for repairs';
      case InsuranceRiderType.evBatteryCover: return 'Covers EV battery damage from accident or water ingress';
      case InsuranceRiderType.valuableContents: return 'Covers jewellery, art, antiques & valuables at home';
      case InsuranceRiderType.burglaryTheft: return 'Covers household goods stolen in a burglary';
      case InsuranceRiderType.personalAccidentHome: return 'Personal accident cover for occupants of the home';
      case InsuranceRiderType.earthquakeCover: return 'Structural damage from earthquake (sometimes inbuilt)';
      case InsuranceRiderType.lossOfRent: return 'Rental income loss while home is under repair after claim';
      case InsuranceRiderType.electronicEquipment: return 'Covers home electronic appliances from breakdown/damage';
      case InsuranceRiderType.publicLiabilityHome: return 'Legal liability for bodily/property injury to third parties';
      case InsuranceRiderType.adventureSports: return 'Medical cover for injuries from adventure/extreme sports';
      case InsuranceRiderType.pedEmergencyTravel: return 'Emergency cover for life-threatening pre-existing condition events';
      case InsuranceRiderType.tripCancellation: return 'Reimburses non-refundable trip costs if cancelled/interrupted';
      case InsuranceRiderType.baggageDelay: return 'Essential items reimbursement when baggage is delayed 12h+';
      case InsuranceRiderType.flightDelay: return 'Hotel/meals allowance for flight delays beyond threshold';
      case InsuranceRiderType.missedConnection: return 'Covers re-booking when a connecting flight is missed';
      case InsuranceRiderType.passportLoss: return 'Expenses to obtain emergency passport replacement abroad';
      case InsuranceRiderType.personalLiabilityTravel: return 'Legal liability if you injure/damage others\' property abroad';
      case InsuranceRiderType.hijackAllowance: return 'Daily cash compensation during aircraft hijacking';
      case InsuranceRiderType.gadgetCover: return 'Accidental damage/theft of electronics during travel';
      case InsuranceRiderType.homeBurglaryTravel: return 'Burglary of your home while you are away on this trip';
    }
  }

  bool get hasSumAssured {
    switch (this) {
      case InsuranceRiderType.accidentalDeathBenefit:
      case InsuranceRiderType.accidentalDisability:
      case InsuranceRiderType.criticalIllnessLife:
      case InsuranceRiderType.criticalIllnessHealth:
      case InsuranceRiderType.incomeBenefit:
      case InsuranceRiderType.maternity:
      case InsuranceRiderType.hospitalCash:
      case InsuranceRiderType.personalAccidentHealth:
      case InsuranceRiderType.restorationBenefit:
      case InsuranceRiderType.returnToInvoice:
      case InsuranceRiderType.valuableContents:
      case InsuranceRiderType.burglaryTheft:
      case InsuranceRiderType.personalAccidentHome:
      case InsuranceRiderType.lossOfRent:
      case InsuranceRiderType.electronicEquipment:
      case InsuranceRiderType.publicLiabilityHome:
      case InsuranceRiderType.tripCancellation:
      case InsuranceRiderType.baggageDelay:
      case InsuranceRiderType.flightDelay:
      case InsuranceRiderType.hijackAllowance:
      case InsuranceRiderType.gadgetCover:
      case InsuranceRiderType.homeBurglaryTravel:
      case InsuranceRiderType.personalLiabilityTravel:
      case InsuranceRiderType.passportLoss:
      case InsuranceRiderType.globalCover:
      case InsuranceRiderType.spouseTerm:
      case InsuranceRiderType.childTerm:
      case InsuranceRiderType.opdCover:
        return true;
      default:
        return false;
    }
  }

  bool get hasWaitingPeriod {
    switch (this) {
      case InsuranceRiderType.criticalIllnessLife:
      case InsuranceRiderType.criticalIllnessHealth:
      case InsuranceRiderType.maternity:
      case InsuranceRiderType.opdCover:
      case InsuranceRiderType.hospitalCash:
      case InsuranceRiderType.pedWaiver:
      case InsuranceRiderType.restorationBenefit:
      case InsuranceRiderType.diseaseSpecific:
      case InsuranceRiderType.waiverOfPremium:
        return true;
      default:
        return false;
    }
  }

  bool get hasSurvivalPeriod {
    switch (this) {
      case InsuranceRiderType.criticalIllnessLife:
      case InsuranceRiderType.criticalIllnessHealth:
        return true;
      default:
        return false;
    }
  }

  bool get hasCIOptions {
    switch (this) {
      case InsuranceRiderType.criticalIllnessLife:
      case InsuranceRiderType.criticalIllnessHealth:
        return true;
      default:
        return false;
    }
  }

  bool get hasVehicleAgeGate {
    switch (this) {
      case InsuranceRiderType.zeroDepreciation:
      case InsuranceRiderType.engineProtection:
      case InsuranceRiderType.returnToInvoice:
        return true;
      default:
        return false;
    }
  }

  bool get canBeInbuilt {
    switch (this) {
      case InsuranceRiderType.terminalIllness:
      case InsuranceRiderType.earthquakeCover:
      case InsuranceRiderType.baggageDelay:
      case InsuranceRiderType.passportLoss:
      case InsuranceRiderType.hijackAllowance:
        return true;
      default:
        return false;
    }
  }

  /// Whether the rider can have its own tenure shorter than the base policy.
  bool get canHaveOwnTenure {
    switch (this) {
      case InsuranceRiderType.accidentalDeathBenefit:
      case InsuranceRiderType.accidentalDisability:
      case InsuranceRiderType.criticalIllnessLife:
      case InsuranceRiderType.waiverOfPremium:
      case InsuranceRiderType.incomeBenefit:
      case InsuranceRiderType.spouseTerm:
      case InsuranceRiderType.childTerm:
        return true;
      default:
        return false;
    }
  }

  String get sumAssuredLabel {
    switch (this) {
      case InsuranceRiderType.hospitalCash: return 'Daily Cash Amount (₹/day)';
      case InsuranceRiderType.hijackAllowance: return 'Daily Allowance (₹/day)';
      case InsuranceRiderType.incomeBenefit: return 'Monthly Income Amount';
      case InsuranceRiderType.maternity: return 'Maternity Benefit Limit';
      case InsuranceRiderType.opdCover: return 'Annual OPD Limit';
      case InsuranceRiderType.globalCover: return 'Global Cover Amount (USD)';
      case InsuranceRiderType.tripCancellation: return 'Trip Cost Covered';
      default: return 'Rider Sum Assured';
    }
  }
}

// ── Catalog: which rider types are available for each insurance type ──────────

const Map<InsuranceType, List<InsuranceRiderType>> kRidersForInsuranceType = {
  InsuranceType.term: [
    InsuranceRiderType.accidentalDeathBenefit,
    InsuranceRiderType.accidentalDisability,
    InsuranceRiderType.criticalIllnessLife,
    InsuranceRiderType.waiverOfPremium,
    InsuranceRiderType.terminalIllness,
    InsuranceRiderType.incomeBenefit,
    InsuranceRiderType.returnOfPremium,
    InsuranceRiderType.spouseTerm,
    InsuranceRiderType.childTerm,
  ],
  InsuranceType.life: [
    InsuranceRiderType.accidentalDeathBenefit,
    InsuranceRiderType.accidentalDisability,
    InsuranceRiderType.criticalIllnessLife,
    InsuranceRiderType.waiverOfPremium,
    InsuranceRiderType.terminalIllness,
    InsuranceRiderType.incomeBenefit,
    InsuranceRiderType.returnOfPremium,
    InsuranceRiderType.spouseTerm,
    InsuranceRiderType.childTerm,
  ],
  InsuranceType.health: [
    InsuranceRiderType.roomRentWaiver,
    InsuranceRiderType.maternity,
    InsuranceRiderType.opdCover,
    InsuranceRiderType.criticalIllnessHealth,
    InsuranceRiderType.hospitalCash,
    InsuranceRiderType.personalAccidentHealth,
    InsuranceRiderType.pedWaiver,
    InsuranceRiderType.restorationBenefit,
    InsuranceRiderType.superBonus,
    InsuranceRiderType.inflationShield,
    InsuranceRiderType.consumablesHealth,
    InsuranceRiderType.diseaseSpecific,
    InsuranceRiderType.globalCover,
    InsuranceRiderType.homeCare,
  ],
  InsuranceType.vehicle: [
    InsuranceRiderType.zeroDepreciation,
    InsuranceRiderType.engineProtection,
    InsuranceRiderType.returnToInvoice,
    InsuranceRiderType.ncbProtection,
    InsuranceRiderType.roadsideAssistance,
    InsuranceRiderType.consumablesMotor,
    InsuranceRiderType.tyreProtection,
    InsuranceRiderType.keyReplacement,
    InsuranceRiderType.passengerPA,
    InsuranceRiderType.dailyAllowance,
    InsuranceRiderType.evBatteryCover,
  ],
  InsuranceType.home: [
    InsuranceRiderType.valuableContents,
    InsuranceRiderType.burglaryTheft,
    InsuranceRiderType.personalAccidentHome,
    InsuranceRiderType.earthquakeCover,
    InsuranceRiderType.lossOfRent,
    InsuranceRiderType.electronicEquipment,
    InsuranceRiderType.publicLiabilityHome,
  ],
  InsuranceType.travel: [
    InsuranceRiderType.adventureSports,
    InsuranceRiderType.pedEmergencyTravel,
    InsuranceRiderType.tripCancellation,
    InsuranceRiderType.baggageDelay,
    InsuranceRiderType.flightDelay,
    InsuranceRiderType.missedConnection,
    InsuranceRiderType.passportLoss,
    InsuranceRiderType.personalLiabilityTravel,
    InsuranceRiderType.hijackAllowance,
    InsuranceRiderType.gadgetCover,
    InsuranceRiderType.homeBurglaryTravel,
  ],
  InsuranceType.other: [
    InsuranceRiderType.accidentalDeathBenefit,
    InsuranceRiderType.accidentalDisability,
    InsuranceRiderType.criticalIllnessLife,
    InsuranceRiderType.waiverOfPremium,
    InsuranceRiderType.personalAccidentHealth,
    InsuranceRiderType.hospitalCash,
  ],
};

// ── InsuranceRider entity ────────────────────────────────────────────────────

const Object _riderSentinel = Object();

class InsuranceRider {
  final String id;
  final InsuranceRiderType type;
  final String riderName;           // editable display name
  final double riderPremium;        // annual premium; 0 if inbuilt
  final String premiumFrequency;    // 'annual', 'monthly', 'single_pay'
  final double? riderSumAssured;    // null if no own SA
  final bool hasOwnTenure;
  final DateTime? riderStartDate;
  final DateTime? riderEndDate;     // null = same as base policy end
  final bool isInbuilt;             // included in base at no extra cost
  final bool isActive;
  // Health / CI specifics
  final int? waitingPeriodDays;     // null if not applicable
  final int? survivalPeriodDays;    // for CI riders
  final int? illnessCount;          // "covers X critical illnesses"
  final bool? isCiAccelerated;      // for CI life: accelerated = reduces base SA
  // Motor specifics
  final int? vehicleAgeEligibilityYears;  // max vehicle age to be eligible
  // Notes
  final String? notes;

  const InsuranceRider({
    required this.id,
    required this.type,
    required this.riderName,
    required this.riderPremium,
    this.premiumFrequency = 'annual',
    this.riderSumAssured,
    this.hasOwnTenure = false,
    this.riderStartDate,
    this.riderEndDate,
    this.isInbuilt = false,
    this.isActive = true,
    this.waitingPeriodDays,
    this.survivalPeriodDays,
    this.illnessCount,
    this.isCiAccelerated,
    this.vehicleAgeEligibilityYears,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'riderName': riderName,
        'riderPremium': riderPremium,
        'premiumFrequency': premiumFrequency,
        'riderSumAssured': riderSumAssured,
        'hasOwnTenure': hasOwnTenure,
        'riderStartDate': riderStartDate?.toIso8601String(),
        'riderEndDate': riderEndDate?.toIso8601String(),
        'isInbuilt': isInbuilt,
        'isActive': isActive,
        'waitingPeriodDays': waitingPeriodDays,
        'survivalPeriodDays': survivalPeriodDays,
        'illnessCount': illnessCount,
        'isCiAccelerated': isCiAccelerated,
        'vehicleAgeEligibilityYears': vehicleAgeEligibilityYears,
        'notes': notes,
      };

  factory InsuranceRider.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] as String?) ?? 'accidentalDeathBenefit';
    final parsedType = InsuranceRiderType.values.firstWhere(
      (t) => t.name == rawType,
      orElse: () => InsuranceRiderType.accidentalDeathBenefit,
    );
    return InsuranceRider(
      id: map['id'] as String,
      type: parsedType,
      riderName: (map['riderName'] as String?) ?? parsedType.displayName,
      riderPremium: (map['riderPremium'] as num?)?.toDouble() ?? 0.0,
      premiumFrequency: (map['premiumFrequency'] as String?) ?? 'annual',
      riderSumAssured: (map['riderSumAssured'] as num?)?.toDouble(),
      hasOwnTenure: (map['hasOwnTenure'] as bool?) ?? false,
      riderStartDate: (map['riderStartDate'] as String?) != null
          ? DateTime.parse(map['riderStartDate'] as String)
          : null,
      riderEndDate: (map['riderEndDate'] as String?) != null
          ? DateTime.parse(map['riderEndDate'] as String)
          : null,
      isInbuilt: (map['isInbuilt'] as bool?) ?? false,
      isActive: (map['isActive'] as bool?) ?? true,
      waitingPeriodDays: map['waitingPeriodDays'] as int?,
      survivalPeriodDays: map['survivalPeriodDays'] as int?,
      illnessCount: map['illnessCount'] as int?,
      isCiAccelerated: map['isCiAccelerated'] as bool?,
      vehicleAgeEligibilityYears: map['vehicleAgeEligibilityYears'] as int?,
      notes: map['notes'] as String?,
    );
  }

  InsuranceRider copyWith({
    String? id,
    InsuranceRiderType? type,
    String? riderName,
    double? riderPremium,
    String? premiumFrequency,
    Object? riderSumAssured = _riderSentinel,
    bool? hasOwnTenure,
    Object? riderStartDate = _riderSentinel,
    Object? riderEndDate = _riderSentinel,
    bool? isInbuilt,
    bool? isActive,
    Object? waitingPeriodDays = _riderSentinel,
    Object? survivalPeriodDays = _riderSentinel,
    Object? illnessCount = _riderSentinel,
    Object? isCiAccelerated = _riderSentinel,
    Object? vehicleAgeEligibilityYears = _riderSentinel,
    Object? notes = _riderSentinel,
  }) {
    return InsuranceRider(
      id: id ?? this.id,
      type: type ?? this.type,
      riderName: riderName ?? this.riderName,
      riderPremium: riderPremium ?? this.riderPremium,
      premiumFrequency: premiumFrequency ?? this.premiumFrequency,
      riderSumAssured: riderSumAssured == _riderSentinel ? this.riderSumAssured : riderSumAssured as double?,
      hasOwnTenure: hasOwnTenure ?? this.hasOwnTenure,
      riderStartDate: riderStartDate == _riderSentinel ? this.riderStartDate : riderStartDate as DateTime?,
      riderEndDate: riderEndDate == _riderSentinel ? this.riderEndDate : riderEndDate as DateTime?,
      isInbuilt: isInbuilt ?? this.isInbuilt,
      isActive: isActive ?? this.isActive,
      waitingPeriodDays: waitingPeriodDays == _riderSentinel ? this.waitingPeriodDays : waitingPeriodDays as int?,
      survivalPeriodDays: survivalPeriodDays == _riderSentinel ? this.survivalPeriodDays : survivalPeriodDays as int?,
      illnessCount: illnessCount == _riderSentinel ? this.illnessCount : illnessCount as int?,
      isCiAccelerated: isCiAccelerated == _riderSentinel ? this.isCiAccelerated : isCiAccelerated as bool?,
      vehicleAgeEligibilityYears: vehicleAgeEligibilityYears == _riderSentinel ? this.vehicleAgeEligibilityYears : vehicleAgeEligibilityYears as int?,
      notes: notes == _riderSentinel ? this.notes : notes as String?,
    );
  }

  /// Annual cost of this rider (0 if inbuilt).
  double get annualCost {
    if (isInbuilt) return 0;
    switch (premiumFrequency) {
      case 'monthly': return riderPremium * 12;
      case 'single_pay': return riderPremium;
      default: return riderPremium;
    }
  }
}
