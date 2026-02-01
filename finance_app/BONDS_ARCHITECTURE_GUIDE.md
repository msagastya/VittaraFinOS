# Bond System Architecture - Cash Flow Based

## Core Principle
**Every bond is a time-ordered list of cash flows. Yield is just the IRR of those cash flows.**

## Files Created

### 1. `lib/logic/bond_cashflow_model.dart` ✅
This is the foundation. Contains:

#### `BondCashFlow` class
Represents a single cash flow event:
```dart
BondCashFlow(
  date: DateTime,
  amount: double,  // negative = outflow, positive = inflow
  description: String,  // "Purchase", "Coupon Payment", etc.
)
```

#### `BondType` enum
```dart
enum BondType {
  fixedCoupon,      // Regular coupon + principal at maturity
  zeroCoupon,       // Single payment at maturity
  monthlyFixed,     // Fixed coupon paid monthly (just frequency difference)
  amortizing,       // Principal repaid gradually
  floatingRate,     // Coupon varies with reference rate
}
```

#### `Bond` class
Master bond record:
- Metadata: name, type, dates, prices, rates
- **Core**: `List<BondCashFlow> cashFlows` - THE CRUCIAL TABLE
- Calculated: `yieldToMaturity` (IRR), `gainLoss`, etc.

#### `BondYieldCalculator` (UNIVERSAL for ALL types)
```dart
static double calculateYield(List<BondCashFlow> cashFlows)
```
- Uses Newton-Raphson method to find IRR
- **Same logic for all bond types**
- IRR = discount rate r where Σ[CashFlow_t / (1+r)^t] = 0

#### `CashFlowGenerator` (bond-type-specific)
Generates cash flows based on type:

**Fixed Coupon**:
```
T0:  -purchasePrice
T1:  +coupon
...
Tn:  +coupon + principal
```

**Zero Coupon**:
```
T0:  -purchasePrice
Tn:  +maturityValue
```

**Amortizing**:
```
T0:  -purchasePrice
T1:  +principal + interest
...
Tn:  +principal + interest
(interest decreases, principal constant)
```

**Floating Rate** (at time of entry):
```
T0:  -purchasePrice
T1:  +(referenceRate + spread) × faceValue
...
Tn:  +(referenceRate + spread) × faceValue + principal
(actual will differ as rates change)
```

---

### 2. `lib/ui/manage/bonds/bonds_wizard_controller_v2.dart` ✅
Manages 5-step wizard state:

```
Step 0: Bond Type & Name
  ├─ Select BondType enum
  └─ Enter bond name

Step 1: Dates & Prices
  ├─ Purchase Date
  ├─ Maturity Date
  ├─ Purchase Price
  ├─ Face Value
  └─ Payment Frequency (1=annual, 2=semi, 12=monthly)

Step 2: Rate Information (CONDITIONAL on BondType)
  ├─ IF fixedCoupon/monthlyFixed:  Fixed Coupon Rate (%)
  ├─ IF zeroCoupon:                Maturity Value
  ├─ IF amortizing:                Interest Rate (%)
  └─ IF floatingRate:              Reference Rate (%) + Spread (%)

Step 3: Cash Flow Review (AUTO-GENERATED)
  ├─ Displays generated cash flow table
  ├─ Shows total invested, total received, P&L
  └─ Shows calculated yield (IRR)

Step 4: Confirmation
  └─ Final review and save
```

### Key Method:
```dart
void generateCashFlows() {
  // Based on selectedType, calls appropriate CashFlowGenerator method
  // Automatically calculates yield using BondYieldCalculator
  // User sees the table before confirming
}
```

---

## How Different Bond Types Use The SAME Yield Engine

| Bond Type | Cash Flow Generation | Yield Calculation |
|-----------|----------------------|-------------------|
| Fixed Coupon | Generate schedule: coupon every period + principal at maturity | **IRR of schedule** |
| Zero Coupon | Generate single maturity payment | **IRR = (MaturityValue/PurchasePrice)^(1/years) - 1** |
| Monthly Fixed | Same as fixed, but 12 times/year | **IRR on 12 flows per year** |
| Amortizing | Generate schedule: declining interest + constant principal | **IRR of declining payments** |
| Floating Rate | Use current ref+spread for coupon | **IRR with assumed rates; updates as rates change** |

**The bond type ONLY affects how cash flows are generated. The yield calculation is identical!**

---

## Integration Steps

To use this system, you need to:

### 1. Replace Old Bonds Wizard (if using)
```dart
import 'package:vittara_fin_os/logic/bond_cashflow_model.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_wizard_controller_v2.dart';
```

### 2. Create 5-Step Wizard UI
Each step should:
- Show relevant input fields based on `controller.selectedType`
- Call `controller.nextPage()` when "Continue" is clicked
- In Step 2→Step 3 transition, `generateCashFlows()` is called automatically

### 3. Display Cash Flow Table in Step 3
```dart
ListView.builder(
  itemCount: controller.generatedCashFlows.length,
  itemBuilder: (context, index) {
    final cf = controller.generatedCashFlows[index];
    return Row(
      children: [
        Text(cf.date),
        Text(cf.amount.toStringAsFixed(2)),
        Text(cf.description),
      ],
    );
  },
)
```

### 4. Save to Investment
```dart
final bond = Bond(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  name: controller.bondName,
  type: controller.selectedType,
  faceValue: controller.faceValue,
  issueDate: controller.purchaseDate,
  maturityDate: controller.maturityDate,
  purchaseDate: controller.purchaseDate,
  purchasePrice: controller.purchasePrice,
  fixedCouponRate: controller.fixedCouponRate,
  referenceRate: controller.referenceRate,
  spread: controller.spread,
  paymentsPerYear: controller.paymentsPerYear,
  cashFlows: controller.generatedCashFlows,
  yieldToMaturity: controller.calculatedYield,
  createdDate: DateTime.now(),
  notes: controller.notes,
);

final investment = Investment(
  id: bond.id,
  name: bond.name,
  type: InvestmentType.bonds,
  amount: controller.purchasePrice,
  color: const Color(0xFF00A6CC),
  metadata: {
    'bondData': bond.toMap(),
    'cashFlows': bond.cashFlows.map((cf) => cf.toMap()).toList(),
    'yield': bond.yieldToMaturity,
  },
);

await investmentsController.addInvestment(investment);
```

### 5. Display in Details Screen
Show:
- Bond metadata (name, type, dates, rates)
- **Cash flow table** (the core truth)
- Calculated metrics:
  - YTM (IRR)
  - Total invested
  - Total received
  - Gain/Loss
  - Return %

---

## Why This Architecture is Better

❌ **Old way**: Different logic for each bond type
- Fixed Coupon: custom YTM calculation
- Zero Coupon: custom discount formula
- Amortizing: custom schedule logic
- Result: 4 different yield implementations, error-prone

✅ **New way**: One universal yield engine
- Bond type only controls **cash flow generation**
- All bonds use **same IRR calculation**
- Result: Single source of truth for yield math, easily testable

---

## Example: Creating a Fixed Coupon Bond

```dart
final controller = BondsWizardControllerV2();

// Step 0
controller.selectType(BondType.fixedCoupon);
controller.updateBondName("RBI Bond 2028");

// Step 1
controller.updatePurchaseDate(DateTime(2024, 1, 15));
controller.updateMaturityDate(DateTime(2028, 1, 15));
controller.updatePurchasePrice(1000);
controller.updateFaceValue(1000);
controller.updatePaymentsPerYear(2); // Semi-annual

// Step 2
controller.updateFixedCouponRate(7.5); // 7.5% p.a.

// Step 3 (automatic)
controller.generateCashFlows();

// Generated cash flows:
// 2024-01-15: -1000 (Purchase)
// 2024-07-15: +37.5  (Coupon = 1000 × 0.075 / 2)
// 2025-01-15: +37.5
// ... (repeat)
// 2028-01-15: +1037.5 (Final coupon + principal)

// Calculated yield (IRR):
// 7.5% (because bond is purchased at par)

print(controller.calculatedYield); // 0.075 (7.5%)
```

---

## Testing the Yield Calculator

```dart
// Zero Coupon Example
// Buy $751, get $1,000 in 3 years
// Expected IRR: (1000/751)^(1/3) - 1 = 10% p.a.

final cashFlows = [
  BondCashFlow(date: DateTime(2024, 1, 1), amount: -751, description: 'Buy'),
  BondCashFlow(date: DateTime(2027, 1, 1), amount: 1000, description: 'Maturity'),
];

final yield = BondYieldCalculator.calculateYield(cashFlows);
print(yield); // Should print ~0.10 (10%)
```

---

## Next Steps

1. **Create the 5-step UI** using `BondsWizardControllerV2`
2. **Add step-by-step input fields** (conditional on bond type)
3. **Display cash flow table** in Step 3 for user review
4. **Save Bond to database** with full cash flow history
5. **Create details screen** showing cash flow table + metrics

All yield math is already done. Just build the UI! ✨
