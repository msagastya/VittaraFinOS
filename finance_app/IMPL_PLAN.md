# VittaraFinOS — Implementation Plan
> Cross-reference: `MASTER_PLAN.md` for issue details.
> This file is the working document. Update status as work progresses.
> Rule: **one batch at a time, commit + APK after each batch completes.**

---

## Quick Status Dashboard
| Batch | Name | Issues | Status | Commit |
|-------|------|--------|--------|--------|
| B01 | Model Defensive Coding | 16 | `[x]` | 45b3100 |
| B02 | Controller Saves + Concurrency | 9 | `[x]` | dc3476c |
| B03 | HTTP Timeouts + Export Security | 6 | `[x]` | f589cdd |
| B04 | Async / Mounted Checks | 9 | `[x]` | f5dd684 |
| B05 | Transactional Integrity | 4 | `[x]` | e506f86 |
| B06 | Wizard Controller Fixes | 15 | `[ ]` | — |
| B07 | Security Layer | 7 | `[ ]` | — |
| B08 | CRUD Cascade + Delete Safety | 4 | `[ ]` | — |
| B09 | Memory & Resource Leaks | 5 | `[ ]` | — |
| B10 | Services + SMS | 7 | `[ ]` | — |
| B11 | Calculation Correctness | 7 | `[ ]` | — |
| B12 | Startup, Lock Screen, Lifecycle | 5 | `[ ]` | — |
| B13 | UX: Empty States + Stale Data + Nav | 14 | `[ ]` | — |
| B14 | Performance | 6 | `[ ]` | — |
| B15 | P3 Polish | 15 | `[ ]` | — |

---

## How to Use This File
1. Find the first batch with status `[ ]`
2. Read the batch section — it tells you every file and every change
3. Make all changes in that batch
4. Mark each item `[x]` as you complete it
5. When all items in the batch are `[x]`, commit with the suggested message
6. Build APK
7. Update the Quick Status Dashboard above
8. Move to next batch

---

# BATCH 01 — Model Defensive Coding
**Status:** `[ ]`
**Risk:** Low — pure guard additions, no logic changes
**Goal:** Eliminate all crash-on-load from enum out-of-bounds and DateTime.parse failures
**MASTER_PLAN IDs:** ENUM-01→09, CAST-01→05, DIV-01→02, DATE-01→02

### Files to touch (9 files)

#### 1. `lib/models/cryptocurrency_model.dart`
- [ ] Line 78: `CryptoTransactionType.values[map['type'] as int]`
  → Replace with: `CryptoTransactionType.values[((map['type'] as num?)?.toInt() ?? 0).clamp(0, CryptoTransactionType.values.length - 1)]`
- [ ] Line 225: `CryptoWalletType.values[map['walletType'] as int]`
  → Same pattern with `CryptoWalletType`
- [ ] Line 228: `CryptoExchange.values[map['exchange'] as int]`
  → Same pattern with `CryptoExchange`

#### 2. `lib/logic/fixed_deposit_model.dart`
- [ ] Line 262: `FDCompoundingFrequency.values[map['compoundingFrequency'] as int]`
  → Clamp pattern with `FDCompoundingFrequency`
- [ ] Line 263: `FDPayoutFrequency.values[map['payoutFrequency'] as int]`
  → Clamp pattern with `FDPayoutFrequency`
- [ ] Line 603: `DateTime(newYear, newMonth + 1, 0).day` — month overflow when newMonth = 12
  → Replace with: `newMonth == 12 ? 31 : DateTime(newYear, newMonth + 1, 0).day`

#### 3. `lib/logic/recurring_deposit_model.dart`
- [ ] Line 235: `RDStatus.values[map['status'] as int]`
  → Clamp pattern with `RDStatus`

#### 4. `lib/logic/bond_cashflow_model.dart`
- [ ] Line 152: `BondType.values[map['type'] as int]`
  → Clamp pattern with `BondType`

#### 5. `lib/logic/pension_model.dart`
- [ ] Line 78: `PensionSchemeType.values[map['type'] as int]`
  → Clamp pattern with `PensionSchemeType`

#### 6. `lib/logic/goal_model.dart`
- [ ] Line 138: In `fromMap()`, wherever GoalType.values[n] is accessed
  → Clamp pattern with `GoalType`
- [ ] Lines 65-72: `recommendedMonthlySavings` getter
  → Add before division: `if (monthsRemaining <= 0) return remainingAmount;`
- [ ] Line 159: `DateTime.parse(map['targetDate'])`
  → `DateTime.tryParse(map['targetDate']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 365))`

#### 7. `lib/logic/tag_model.dart`
- [ ] Line 30: `DateTime.parse(map['createdDate'])`
  → `DateTime.tryParse(map['createdDate']?.toString() ?? '') ?? DateTime.now()`

#### 8. `lib/logic/category_model.dart`
- [ ] Line 51: `DateTime.parse(...)`
  → Same `tryParse` pattern with `DateTime.now()` fallback

#### 9. `lib/logic/contact_model.dart`
- [ ] Line 28: `DateTime.parse(...)`
  → Same `tryParse` pattern

#### 10. `lib/logic/budget_model.dart`
- [ ] Line 173: `DateTime.parse(...)`
  → Same `tryParse` pattern
- [ ] Line 131: `DateTime(endDate.year, endDate.month, endDate.day + 1)` in `getNextPeriodStart()`
  → Replace with: `endDate.add(const Duration(days: 1))`

#### 11. `lib/logic/loan_model.dart`
- [ ] Line 78-80: `totalPaid / principalAmount` in `progressPercent` getter
  → `principalAmount > 0 ? (totalPaid / principalAmount).clamp(0.0, 1.0) : 0.0`

### Test criteria
- [ ] Create an FD with invalid compounding frequency in stored JSON → should load with default, not crash
- [ ] Load goals with past target date → `recommendedMonthlySavings` returns a number, not Infinity
- [ ] Corrupt a contact's `createdDate` in SharedPreferences → app loads without crash

### Commit message
```
fix(models): enum bounds clamping, safe DateTime.parse, division guards

- Clamp all EnumType.values[n] accesses in crypto, FD, RD, bond, pension, goal models
- Replace DateTime.parse() with tryParse() + fallback in tag, category, contact, budget, goal models
- Guard monthsRemaining division in GoalModel
- Fix progressPercent division in LoanModel
- Fix budget getNextPeriodStart() month overflow (Jan 31 + 1 day)
- Fix FD _addMonths() month=12 overflow
```

---

# BATCH 02 — Controller Saves + Concurrency
**Status:** `[ ]`
**Risk:** Low-Medium — adding `await` and `async` to existing methods
**Goal:** Eliminate all fire-and-forget saves; add mutex to budget spending update
**MASTER_PLAN IDs:** SAVE-01→08, CONC-01

### Files to touch (4 files)

#### 1. `lib/logic/contacts_controller.dart`
- [ ] Line 42: `addContact()` — make `async`, change `_saveContacts()` to `await _saveContacts()`
- [ ] Line 65: `removeContact()` — make `async`, add `await _saveContacts()`
- [ ] Line 74: `updateContact()` — make `async`, add `await _saveContacts()`
- [ ] Verify `notifyListeners()` is called AFTER the await in all three

#### 2. `lib/logic/lending_borrowing_controller.dart`
- [ ] Line 111: `removeRecord()` — make `async`, change to `await _saveRecords()`
- [ ] While in this file: check `addRecord()` and `updateRecord()` too — await any fire-and-forget saves

#### 3. `lib/logic/recurring_templates_controller.dart`
- [ ] Line 71: `markUsed()` → `await _save()`
- [ ] Line 79: `updateTemplate()` → `await _save()`
- [ ] Line 88: `markBillAsPaid()` → `await _save()`
- [ ] Line 130: `unmarkBillAsPaid()` → `await _save()`
- [ ] For all four: verify `notifyListeners()` comes AFTER the await

#### 4. `lib/logic/budgets_controller.dart`
- [ ] Lines 116-124: `updateBudgetSpending()`
  → Import `async_mutex.dart` (already at `utils/async_mutex.dart`)
  → Wrap the read-modify-write block: `await _mutex.protect(() async { ... })`
  → Add `final _mutex = AsyncMutex();` field at top of class

### Test criteria
- [ ] Force-kill app immediately after reordering contacts → on relaunch, order preserved
- [ ] Force-kill app immediately after marking a bill paid → on relaunch, bill shows as paid
- [ ] Simulate two concurrent SMS scans updating budget → no lost update

### Commit message
```
fix(controllers): await all saves, add mutex to budget spending update

- contacts_controller: await _saveContacts() in add/remove/update
- lending_borrowing_controller: await _saveRecords() in removeRecord
- recurring_templates_controller: await _save() in markUsed/updateTemplate/markBillAsPaid/unmarkBillAsPaid
- budgets_controller: wrap updateBudgetSpending in AsyncMutex to prevent concurrent write race
```

---

# BATCH 03 — HTTP Timeouts + Export Security
**Status:** `[ ]`
**Risk:** Low — pure additions, no behavioural change for happy path
**Goal:** Prevent app freeze on slow network; prevent CSV formula injection
**MASTER_PLAN IDs:** HTTP-01→04, SEC-08, CAST-08

### Files to touch (4 files)

#### 1. `lib/services/amfi_data_service.dart`
- [ ] Line 11: Add `.timeout(const Duration(seconds: 30))` to `http.get(Uri.parse(amfiUrl))`
- [ ] Wrap entire fetch in try-catch including `TimeoutException`; return empty list on failure

#### 2. `lib/services/stock_api_service.dart`
- [ ] Line 38: Add `.timeout(const Duration(seconds: 15))` to search http.get
- [ ] Line 69: Add `.timeout(const Duration(seconds: 15))` to price http.get
- [ ] Both: catch `TimeoutException` and return null/empty; don't rethrow

#### 3. `lib/services/nav_service.dart`
- [ ] Line 51: Change fallback timeout from 12s to 10s (standardize)
- [ ] Verify line 39 primary timeout is 10s — leave as is if correct

#### 4. `lib/services/transaction_export_service.dart`
- [ ] Line 136: Tags exported raw — add formula injection escape
  ```dart
  String _safeCsvCell(String value) {
    if (value.startsWith(RegExp(r'^[=+@\-]'))) return "'$value";
    return value;
  }
  ```
  Apply `_safeCsvCell()` to all user-entered string fields: tags, merchant, description, category name
- [ ] Line 560: `meta['tags'] as List` — replace with null-safe cast:
  `(meta?['tags'] as List<dynamic>?)?.map((t) => t.toString()).join(', ') ?? ''`
- [ ] Check all other `meta['x'] as Type` casts in this file — add null-safe versions

### Test criteria
- [ ] Disable network, open MF search → no freeze, shows "Search unavailable" within 30s
- [ ] Disable network, open stock search → fails gracefully within 15s
- [ ] Export CSV with a transaction tagged `=SUM(A1:A10)` → open in Excel, value shows as text not formula

### Commit message
```
fix(network,export): add HTTP timeouts, prevent CSV formula injection

- amfi_data_service: 30s timeout + graceful error return
- stock_api_service: 15s timeout on search + price endpoints
- nav_service: standardize fallback timeout to 10s
- transaction_export_service: escape formula-injection chars in CSV cells
- transaction_export_service: null-safe metadata field extraction
```

---

# BATCH 04 — Async / Mounted Checks
**Status:** `[ ]`
**Risk:** Medium — touching async flow in wizard screens; test all affected flows
**Goal:** Eliminate all setState/Navigator calls on unmounted widgets
**MASTER_PLAN IDs:** ASYNC-01→08, MEM-04

### Files to touch (6 files)

#### 1. `lib/ui/manage/fd/fd_wizard_screen.dart`
- [ ] Line 138: Check that `if (mounted)` is BEFORE `Navigator.pop()`, not after
  → Pattern: `if (!mounted) return; Navigator.pop(context);`
- [ ] Line 142: In finally block: `if (mounted) setState(() => _isSubmitting = false);`

#### 2. `lib/ui/manage/rd/rd_wizard_screen.dart`
- [ ] Line 141: In finally block: `if (mounted) setState(() => _isSubmitting = false);`

#### 3. `lib/ui/manage/mf/mf_wizard.dart`
- [ ] Line 107: Change `mounted` to `context.mounted` (correct API for non-State widget context)

#### 4. `lib/ui/manage/stocks/stocks_wizard.dart`
- [ ] Lines 44-45: Merge `isSubmitting` state change into single `notifyListeners()` call

#### 5. `lib/ui/pin_recovery_screen.dart`
- [ ] Lines 78-91: In Timer callback, after every `await`, add `if (!mounted) return;` before setState
- [ ] Lines 188-191: In `dispose()`, add `_countdownTimer?.cancel();`
- [ ] Scan entire file: add `if (!mounted) return;` after every `await` before any context/setState use

#### 6. `lib/ui/dashboard/transaction_wizard.dart`
- [ ] Line 101: Add `if (!mounted) return;` before `Navigator.of(context).push()` in `_selectBranch()`

#### 7. `lib/ui/dashboard/widgets/insights_widget.dart`
- [ ] Lines 494-512: `SpendNarrativeCarouselState` — add `WidgetsBinding.instance.addObserver(this)` in `initState()` and implement `didChangeAppLifecycleState()`:
  ```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed && mounted) {
      _startTimer();
    }
  }
  ```
  Remove observer in `dispose()`

### Test criteria
- [ ] Open FD wizard → go to last step → background app during save → no crash on return
- [ ] Open RD wizard → tap submit → force-close during animation → no crash on relaunch
- [ ] Open pin recovery → wait for countdown → switch app mid-countdown → no crash

### Commit message
```
fix(async): add mounted checks and lifecycle timer management

- fd_wizard_screen: mounted check before Navigator.pop and setState in finally
- rd_wizard_screen: mounted check in finally block
- mf_wizard: fix mounted → context.mounted
- stocks_wizard: merge duplicate notifyListeners calls
- pin_recovery_screen: mounted checks after all awaits; cancel timer in dispose
- transaction_wizard: mounted check before Navigator.push
- insights_widget: cancel/restart narrative carousel timer on app lifecycle pause/resume
```

---

# BATCH 05 — Transactional Integrity
**Status:** `[ ]`
**Risk:** High — financial data flows; test every investment type's create and delete
**Goal:** Account balance always reflects reality — debit after save, credit on delete
**MASTER_PLAN IDs:** TXN-01→04

### Files to touch (3 files)

#### 1. `lib/ui/manage/fd/fd_wizard_screen.dart`
- [ ] Lines 94-136: Account debit currently happens before `addInvestment()`. Fix order:
  1. Call `addInvestment()` first — get result
  2. Only if successful, call account debit
  3. If debit fails: call `removeInvestment(newFd.id)` to rollback
  Pattern:
  ```dart
  final saved = await investmentsController.addInvestment(fd);
  if (!saved) { showError('Failed to save FD'); return; }
  final debited = await accountsController.debitAccount(accountId, amount);
  if (!debited) {
    await investmentsController.removeInvestment(fd.id);
    showError('Failed to debit account'); return;
  }
  ```

#### 2. `lib/ui/manage/rd/rd_wizard_screen.dart`
- [ ] Lines 98-107: Same pattern — save RD first, then debit first installment

#### 3. `lib/logic/investments_controller.dart`
- [ ] Lines 79-88: `removeInvestment()` and `deleteInvestment()`
  → Before removing, read `investment.metadata['linkedAccountId']` and `investment.metadata['linkedAmount']`
  → If both exist, call `accountsController.creditAccount(accountId, amount)` to reverse the debit
  → Inject `AccountsController` reference into `InvestmentsController` via constructor (or use Provider.of in the UI layer before calling delete)

#### Also check:
- [ ] `ui/manage/stocks/stocks_wizard.dart` line 52: `newBalance = account.balance - amount`. Add check:
  `if (newBalance < (account.creditLimit ?? 0)) { showError('Insufficient balance'); return; }`

### Test criteria
- [ ] Create FD → check account balance decreased → delete FD → check balance restored
- [ ] Create RD → check first installment deducted → delete RD → check balance restored
- [ ] Create FD → simulate addInvestment() failure → verify account balance NOT changed

### Commit message
```
fix(investments): save before debit; reverse debit on delete

- fd_wizard: save investment before debiting account; rollback on save failure
- rd_wizard: same transactional ordering
- investments_controller: credit account balance when investment is deleted
- stocks_wizard: block deduction if account would go below credit limit
```

---

# BATCH 06 — Wizard Controller Fixes
**Status:** `[ ]`
**Risk:** Medium — calculations and validations across many investment types
**Goal:** Fix all division-by-zero, wrong formulas, and missing validations in wizard controllers
**MASTER_PLAN IDs:** DIV-03→07, DATE-04→05, INV-01→10, CALC-03, IMPL-01→02

### Files to touch (10 files + 1 new file)

#### 1. `lib/ui/manage/digital_gold/digital_gold_wizard_controller.dart`
- [ ] Lines 31-38: `weightInGrams = actualAmount / investmentRate`
  → Guard: `investmentRate > 0 ? actualAmount / investmentRate : 0`
- [ ] Lines 75-84: `updateWeight()` guard at top:
  `if (investmentRate <= 0) { notifyListeners(); return; }`

#### 2. `lib/ui/manage/fo/fo_wizard_controller.dart`
- [ ] Lines 26-28: `gainLossPercent` divide by `totalCost`
  → `if (totalCost <= 0) return 0;`
- [ ] Lines 31-52: `canProceed()` for step 1: add `&& entryDate.isBefore(expiryDate)` check

#### 3. `lib/ui/manage/commodities/commodities_wizard_controller.dart`
- [ ] Line 23: `gainLossPercent` divide by `totalCost`
  → `if (totalCost <= 0) return 0;`
- [ ] Lines 28-54: `canProceed()` step 1: add `&& selectedType != null`

#### 4. `lib/ui/manage/mf/mf_wizard.dart`
- [ ] Lines 56-62: `units = investmentAmount / averageNAV`
  → `(averageNAV > 0) ? investmentAmount / averageNAV : 0`
- [ ] Lines 146-149: validate both `currentUnits >= 0` and `currentAmount >= 0` before clamp

#### 5. `lib/ui/manage/mf/mf_wizard_controller.dart`
- [ ] Lines 88-95: Add `&& averageNAV > 0` to `canProceed()` condition

#### 6. `lib/ui/manage/nps/nps_wizard_controller.dart`
- [ ] Lines 43-44: `gainLossPercent` — guard division:
  `totalContributed == null || totalContributed! <= 0 ? 0.0 : ((currentValue ?? 0) - totalContributed!) / totalContributed! * 100`

#### 7. `lib/ui/manage/pension/pension_wizard_controller.dart`
- [ ] Lines 15-19: null-safe arithmetic:
  `double get gainLoss => (currentValue ?? 0) - (principalContributed ?? 0);`

#### 8. `lib/ui/manage/bonds/bonds_wizard.dart` + `bonds_wizard_controller_v2.dart`
- [ ] Confirm v2 is the one used in `bonds_wizard.dart` line 22
- [ ] Delete `lib/ui/manage/bonds/bonds_wizard_controller.dart` (v1) — dead code
- [ ] bonds_wizard_controller_v2.dart line 95-100: change maturity date check to:
  `maturityDate.isAfter(DateTime.now().add(const Duration(days: 1)))`
- [ ] bonds_wizard.dart: change payout frequency storage from `.toString().split('.').last` to explicit string map

#### 9. `lib/ui/manage/rd/rd_wizard_controller.dart`
- [ ] Line 153: maturity date calc — change `(totalInstallments - 1)` to `totalInstallments`
- [ ] Line 169: verify `RDCalculator` class exists and is imported; add null fallback if missing

#### 10. `lib/ui/manage/loans/loan_wizard.dart`
- [ ] Lines 127-142: Add validation: `if (outstanding > principal) { showError('Outstanding cannot exceed principal'); return false; }`

#### 11. NEW FILE: `lib/logic/bond_calculator.dart`
- [ ] Create with Newton-Raphson YTM implementation:
  ```dart
  class BondCalculator {
    static double calculateYieldToMaturity({
      required double faceValue,
      required double couponRate,
      required double marketPrice,
      required double yearsToMaturity,
      int paymentsPerYear = 1,
    }) {
      if (yearsToMaturity <= 0 || marketPrice <= 0) return couponRate;
      final coupon = faceValue * couponRate / paymentsPerYear;
      final n = (yearsToMaturity * paymentsPerYear).round();
      // Newton-Raphson iteration
      double ytm = couponRate;
      for (int i = 0; i < 100; i++) {
        final r = ytm / paymentsPerYear;
        double pv = 0;
        double dpv = 0;
        for (int t = 1; t <= n; t++) {
          final disc = pow(1 + r, t);
          pv += coupon / disc;
          dpv -= t * coupon / (disc * (1 + r));
        }
        pv += faceValue / pow(1 + r, n);
        dpv -= n * faceValue / (pow(1 + r, n) * (1 + r));
        pv -= marketPrice;
        if (dpv.abs() < 1e-10) break;
        ytm -= pv / dpv / paymentsPerYear;
        if (ytm < 0) ytm = 0.001;
      }
      return ytm;
    }
  }
  ```
  Add `import 'dart:math';` at top.

### Test criteria
- [ ] Digital gold wizard: enter 0 for rate → no crash, shows 0 weight
- [ ] F&O wizard: try to set entry date after expiry → blocked at that step
- [ ] Bonds wizard: delete v1 controller file → app still compiles and bonds wizard opens
- [ ] Loans wizard: enter outstanding > principal → error shown, cannot proceed
- [ ] NPS wizard: enter 0 contributions → gain shows 0%, not Infinity

### Commit message
```
fix(wizards): division guards, validation fixes, YTM implementation

- digital_gold: guard division by investmentRate
- fo: guard gainLossPercent; enforce entry < expiry date
- commodities: guard division; require explicit type selection
- mf: guard NAV division; validate units/amount non-negative
- nps: guard gainLossPercent for zero contributions
- pension: null-safe gain/loss arithmetic
- bonds: delete dead v1 controller; fix maturity date validation
- rd: fix maturity date calculation (totalInstallments not -1)
- loans: block outstanding > principal
- Add BondCalculator.calculateYieldToMaturity (Newton-Raphson)
```

---

# BATCH 07 — Security Layer
**Status:** `[ ]`
**Risk:** High — security-critical; test PIN and backup flows end-to-end after
**Goal:** Harden PIN, recovery code, clipboard, and backup key
**MASTER_PLAN IDs:** SEC-01→07

### Files to touch (4 files)

#### 1. `lib/logic/backup_restore_service.dart`
- [ ] Lines 125-151: `_masterSecretSeed` hardcoded. Add comment documenting this is legacy-only.
  Force migration: if a user has a v1 backup, prompt them to re-backup using v2.
  Add method: `bool get hasLegacyBackup => ...` (check stored version flag).
  Show migration banner in settings if `hasLegacyBackup`.

#### 2. `lib/logic/settings_controller.dart`
- [ ] Line 242: The hardcoded fallback salt `'vittara_pin_salt_$pin'`.
  Add assertion: if `_storedSalt == null` for an existing user, generate and store a new salt, then re-hash.
  Ensure NO new PIN ever uses the hardcoded fallback.
  Add `_migrateLegacySalt()` called in `loadSettings()`.

#### 3. `lib/logic/pin_recovery_controller.dart`
- [ ] Line 75: `_storage.delete(key: _keyRecoveryHash)` — verify deletion:
  ```dart
  await _storage.delete(key: _keyRecoveryHash);
  final verify = await _storage.read(key: _keyRecoveryHash);
  if (verify != null) {
    logger.error('Recovery code deletion failed — security risk');
    // Mark as used with a separate flag as fallback
    await _storage.write(key: '${_keyRecoveryHash}_used', value: 'true');
  }
  ```

#### 4. `lib/ui/recovery_code_save_screen.dart`
- [ ] Lines 45-48: Add button "I've saved it securely" that clears clipboard immediately on tap
  Do NOT wait for the 60s timer or app pause for user-confirmed dismissal
- [ ] Keep the existing 60s timer and app-pause clear as additional safety nets

#### 5. `lib/ui/pin_recovery_screen.dart`
- [ ] Lines 158-171: Move `generateAndStoreRecoveryCode()` call behind `_isGenerating` flag:
  ```dart
  if (_isGenerating) return;
  setState(() => _isGenerating = true);
  try {
    await controller.generateAndStoreRecoveryCode();
  } finally {
    if (mounted) setState(() => _isGenerating = false);
  }
  ```
- [ ] Lines 99-163: Move recovery code invalidation to BEFORE PIN entry screen is shown

### Test criteria
- [ ] Set PIN → backup → wipe → restore backup → PIN still works
- [ ] Generate recovery code → tap "I've saved it" → check clipboard is cleared immediately
- [ ] Rapidly tap "Generate Code" 10 times → only one code generated, not multiple
- [ ] Verify recovery code — then navigate away before completing reset — verify code cannot be reused

### Commit message
```
fix(security): harden PIN salt, recovery code single-use, clipboard clear

- backup_restore: document legacy key, add migration banner flag
- settings_controller: migrate legacy hardcoded salt; never use hardcoded salt for new PINs
- pin_recovery_controller: verify recovery code deletion succeeded; add fallback used-flag
- recovery_code_save_screen: add immediate clipboard clear on user confirmation
- pin_recovery_screen: add _isGenerating guard; invalidate code before PIN entry
```

---

# BATCH 08 — CRUD Cascade + Delete Safety
**Status:** `[ ]`
**Risk:** Medium — data integrity; test delete flows for contacts and categories
**Goal:** No orphaned records after any delete operation
**MASTER_PLAN IDs:** CASCADE-01→04

### Files to touch (4 files)

#### 1. `lib/logic/contacts_controller.dart`
- [ ] Lines 47-60: `addOrGetContact()` — fix duplicate detection:
  Change `.contains(existing)` to `.any((c) => c.name.toLowerCase() == name.toLowerCase())`
- [ ] `removeContact(String id)` — add cascade:
  After removing contact, call `lendingBorrowingController.removeAllRecordsForContact(contactName)`
  (Inject `LendingBorrowingController` reference or handle in UI layer)

#### 2. `lib/ui/manage/contacts_screen.dart`
- [ ] Line 774: Before calling `controller.removeContact()`:
  Check if any lending records exist for this contact.
  Show confirmation dialog: "This contact has X active lending records. Delete contact and all records?"
  Only proceed if user confirms.

#### 3. `lib/ui/manage/categories_screen.dart`
- [ ] Before category delete: check if any transactions reference this category.
  Show: "X transactions use this category. Reassign to 'Other' before deleting?"
  Offer two options: Reassign all → then delete, or Cancel.

#### 4. `lib/ui/manage/accounts_screen.dart`
- [ ] Before account delete: check if any transactions reference this account.
  Show: "X transactions are linked to this account. Delete account and all linked transactions?"
  This is destructive — require extra confirmation (type account name or tap confirm twice).

### Test criteria
- [ ] Add contact with lending record → delete contact → verify lending record also gone
- [ ] Add same contact name twice via `addOrGetContact()` → only one contact created
- [ ] Delete category with transactions → transactions reassigned to "Other" → no orphaned transactions
- [ ] Delete account → all linked transactions gone

### Commit message
```
fix(crud): cascade deletes for contacts, categories, accounts

- contacts_controller: fix duplicate detection to use name comparison not object identity
- contacts_screen: show confirmation with lending record count before delete; cascade to lending records
- categories_screen: reassign transactions to 'Other' category before delete
- accounts_screen: confirmation + cascade delete transactions on account delete
```

---

# BATCH 09 — Memory & Resource Leaks
**Status:** `[ ]`
**Risk:** Low — dispose fixes and initialization guards
**Goal:** No animation controllers, scroll controllers, or timers leaked
**MASTER_PLAN IDs:** MEM-01→05, INIT-03

### Files to touch (5 files)

#### 1. `lib/ui/financial_calendar_screen.dart`
- [ ] Line 163: Add `_eventsScrollCtrl.dispose();` to the `dispose()` method

#### 2. `lib/ui/widgets/liquid_fab.dart`
- [ ] Line 325: Before `_pulseController.repeat()`, add check:
  `if (!_pulseController.isCompleted && !_pulseController.isDismissed) return;`
- [ ] In `dispose()`: add `_pulseController.stop();` before `_pulseController.dispose()`

#### 3. `lib/utils/alert_service.dart`
- [ ] Lines 365-376: In `_ToastNotificationState.dispose()`:
  Add `_controller.stop();` before `_controller.dispose();`

#### 4. `lib/services/database_helper.dart`
- [ ] Lines 15-19: Replace the null-check singleton with a Completer-based gate:
  ```dart
  static Completer<Database>? _initCompleter;
  static Future<Database> get database async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<Database>();
    try {
      final db = await _initDatabase();
      _initCompleter!.complete(db);
    } catch (e) {
      _initCompleter = null; // allow retry
      rethrow;
    }
    return _initCompleter!.future;
  }
  ```

#### 5. `lib/dashboard/widgets/net_worth_widget.dart`
- [ ] Verify carousel auto-advance timer is cancelled in `didChangeAppLifecycleState(paused)`.
  If not: add `WidgetsBinding.instance.addObserver(this)` in `initState()` and cancel on pause.

### Test criteria
- [ ] Open financial calendar → navigate away → no "A ScrollController was used after being disposed" error
- [ ] Open net worth widget → background app → foreground → carousel resumes from correct position
- [ ] Open multiple toast notifications rapidly → no assertion errors in console

### Commit message
```
fix(memory): dispose scroll/animation controllers, guard DB init race

- financial_calendar_screen: dispose _eventsScrollCtrl
- liquid_fab: stop pulse controller before dispose
- alert_service: stop animation controller before dispose
- database_helper: Completer-based singleton to prevent concurrent DB open
- net_worth_widget: cancel carousel timer on lifecycle pause
```

---

# BATCH 10 — Services + SMS
**Status:** `[ ]`
**Risk:** Medium — affects SMS parsing and data import flows
**Goal:** Stable fingerprints, no balance-SMS false transactions, cleanup methods
**MASTER_PLAN IDs:** SMS-01→04, SVC-02→07

### Files to touch (6 files)

#### 1. `lib/services/sms_auto_scan_service.dart`
- [ ] Lines 312-319: Rebuild fingerprint WITHOUT sender string:
  New fingerprint: `'${amount.toStringAsFixed(2)}_${date.year}${date.month}${date.day}_${last4digits}'`
  Where `last4digits` = last 4 chars of account number if extractable, else empty string
- [ ] Lines 170-176: Increase dedup tolerance from `± 1.0` to `± 2.0`

#### 2. `lib/services/sms_parser.dart`
- [ ] Lines 524-550: Add balance-context detection BEFORE transaction extraction.
  If SMS contains balance keywords (`Avl Bal`, `Available Balance`, `A/c Bal`) AND no explicit debit/credit verb, route to `_extractBalanceUpdate()` not `_extractTransaction()`
- [ ] Line 537: Replace complex lookbehind regex with pre-check split approach (Dart may not support all lookbehind patterns)

#### 3. `lib/utils/id_generator.dart`
- [ ] Line 7: Persist sequence counter to SharedPreferences on each increment.
  On startup, load last sequence value before starting.
  Or simpler: switch to UUID: add `uuid: ^4.0.0` to pubspec.yaml and use `const Uuid().v4()`

#### 4. `lib/services/integrity_check_service.dart`
- [ ] Add public method:
  ```dart
  Future<int> cleanupOrphanedRecords() async {
    final orphaned = await findOrphanedTransactions();
    for (final tx in orphaned) {
      await transactionsController.deleteTransaction(tx.id);
    }
    return orphaned.length;
  }
  ```
- [ ] Expose via Settings screen: "Data Integrity" section with "Run Check" and "Clean Up" buttons

#### 5. `lib/services/anomaly_detector.dart`
- [ ] Lines 8-33: Replace all-time average baseline with 90-day rolling window.
  For December and January, use 3σ instead of 2σ to reduce seasonal false positives.

#### 6. `lib/services/mf_database_service.dart`
- [ ] Lines 50-51: Store `_lastRefreshError` on failure.
  Expose `String? get lastRefreshError`.
  Add retry with exponential backoff (max 3 retries).

### Test criteria
- [ ] Receive same SMS twice → only one transaction created (fingerprint stable)
- [ ] SMS "Avl Bal Rs 5000 in your account" → no transaction created, only balance updated
- [ ] Run app twice in quick succession → no ID collisions
- [ ] Settings → Data Integrity → Run Check → shows orphan count → Clean Up → count goes to 0

### Commit message
```
fix(services,sms): stable fingerprints, balance SMS routing, cleanup methods

- sms_auto_scan: fingerprint uses amount+date+last4 instead of sender hashCode
- sms_auto_scan: increase dedup tolerance to ±2.0
- sms_parser: route balance-only SMS to balance update path, not transaction
- id_generator: persist sequence or switch to UUID v4
- integrity_check: add cleanupOrphanedRecords() + Settings UI
- anomaly_detector: 90-day rolling baseline; 3σ in Dec/Jan
- mf_database_service: expose lastRefreshError; add retry with backoff
```

---

# BATCH 11 — Calculation Correctness
**Status:** `[ ]`
**Risk:** Medium — financial calculation changes; verify with known good values
**Goal:** XIRR correct, FY display correct, percent formatting correct
**MASTER_PLAN IDs:** CALC-01→07

### Files to touch (5 files)

#### 1. `lib/services/nav_service.dart`
- [ ] Lines 180-200: Replace simple ratio XIRR with Newton-Raphson implementation.
  Use the same pattern as `BondCalculator` (created in B06).
  Correct XIRR takes dates and cashflows, not just start/end NAV.
  If SIP cashflows are stored: use actual SIP dates and amounts.

#### 2. `lib/logic/fd_calculations.dart`
- [ ] Line 23: When `daysDifference == 0`, return `null` (not 0.0).
  In all UI that calls `calculateCAGR()`, handle `null` → show "Too early to calculate".

#### 3. `lib/utils/percent_formatter.dart`
- [ ] Line 20: Near-zero formatting:
  ```dart
  if (value != 0 && value.abs() < 0.01) {
    return value > 0 ? '< 0.01%' : '> -0.01%';
  }
  if (value == 0 || value.isNaN) return '0%';
  ```

#### 4. `lib/utils/date_formatter.dart`
- [ ] Lines 202-204: Fix FY suffix:
  `'FY ${year}-${(year + 1).toString().substring(2)}'`
  Example: `'FY 2024-25'` ✓ (not `'FY 2024-24'`)

#### 5. `lib/utils/merchant_normalizer.dart`
- [ ] Line 31: After `.split(RegExp(r'[\s\-–]+'))`, add `.where((w) => w.isNotEmpty).toList()`
  before `map((w) => w.capitalize()).join(' ')`

### Test criteria
- [ ] MF with 3 SIP investments over 6 months → XIRR shows correct annualized return (verify manually)
- [ ] FD created today → CAGR shows "Too early to calculate" not "0%"
- [ ] Format 0.001% → shows "< 0.01%"
- [ ] Format -0.005% → shows "> -0.01%"
- [ ] Financial year 2024 → shows "FY 2024-25" not "FY 2024-24"
- [ ] Merchant "McDonald's" → shows "Mcdonald's" (no double space)

### Commit message
```
fix(calculations): XIRR Newton-Raphson, FY display, percent formatting

- nav_service: implement proper Newton-Raphson XIRR for SIP returns
- fd_calculations: return null CAGR for same-day investments; update all call sites
- percent_formatter: show '< 0.01%' / '> -0.01%' for near-zero values
- date_formatter: fix FY suffix off-by-one (2024-25 not 2024-24)
- merchant_normalizer: filter empty tokens from split to prevent double-space
```

---

# BATCH 12 — Startup, Lock Screen, App Lifecycle
**Status:** `[ ]`
**Risk:** High — touches main.dart; test cold start, lock, and resume thoroughly
**Goal:** Graceful startup failure, real lock screen coverage, lifecycle-aware lock
**MASTER_PLAN IDs:** INIT-01→02, LOCK-01→03

### Files to touch (1 file — main.dart)

#### `lib/main.dart`
- [ ] Lines 81-143: Wrap each provider creation in try-catch:
  ```dart
  ChangeNotifierProvider(
    create: (_) {
      try {
        return AccountsController()..loadAccounts();
      } catch (e) {
        logger.error('AccountsController failed to init', error: e);
        return AccountsController(); // empty/safe fallback
      }
    },
  ),
  ```
  Add a `StartupErrorController` that collects errors from failed inits.
  If any P0 controller fails, show a recovery screen instead of blank white screen.

- [ ] Lines 596-626: Remove hardcoded 3.5s splash timer.
  Replace with a `FutureBuilder` or `ValueListenableBuilder` on `DashboardController.isInitialized`.
  Show progress indicator until all controllers report ready.

- [ ] Lines 285-286: Lock screen is `Positioned.fill()` — change to use `showDialog()` approach:
  When lock is triggered, call:
  ```dart
  showCupertinoDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const LockScreenWidget(),
  );
  ```
  This ensures it covers ALL overlays including sheets and FABs.

- [ ] Lines 172-179: In `didChangeAppLifecycleState()`, add:
  ```dart
  case AppLifecycleState.resumed:
    if (settings.lockOnBackground && !settings.isAuthenticated) {
      _showLockScreen(context);
    }
    break;
  ```

- [ ] iOS swipe-bypass: Wrap lock screen widget in `GestureDetector(onHorizontalDragUpdate: (_) {})` to absorb swipe gestures.

### Test criteria
- [ ] Corrupt SharedPreferences for one controller → app starts, shows warning, other features work
- [ ] Cold start → spinner shows until all data loaded → no flash of empty state
- [ ] Lock enabled → open sheet → background app → foreground → sheet dismissed, lock screen visible over everything
- [ ] Lock screen → swipe from edge → lock stays (iOS swipe not bypassed)
- [ ] Lock screen → background → foreground → lock re-shown even if already unlocked once

### Commit message
```
fix(startup,lock): graceful init failure, real lock overlay, lifecycle lock

- main: wrap all provider inits in try-catch; show recovery screen on critical failure
- main: replace hardcoded splash timer with DashboardController.isInitialized listener
- main: lock screen via showCupertinoDialog to cover all overlays and sheets
- main: show lock screen on AppLifecycleState.resumed if lockOnBackground enabled
- main: absorb swipe gestures during lock to prevent iOS edge-swipe bypass
```

---

# BATCH 13 — UX: Empty States, Stale Data, Navigation
**Status:** `[ ]`
**Risk:** Low-Medium — UI additions; no logic changes
**Goal:** Every screen has an empty state; data refreshes when child changes it; navigation is consistent
**MASTER_PLAN IDs:** EMPTY-01→04, STALE-01→04, NAV-01→06

### Files to touch (10 files)

#### Empty States
- [ ] `ui/notifications_page.dart`: When all notification lists empty → show centered icon + "You're all caught up"
- [ ] `ui/dashboard/widgets/budget_widget.dart`: Empty state needs CTA button → "Create your first budget"
- [ ] `ui/manage/goals/goal_details_screen.dart`: Goal not found state → add `CupertinoNavigationBar` with back button
- [ ] `ui/widgets/common_widgets.dart`: `SkeletonLoader` → add `maxDuration` (30s) + timeout error state with retry

#### Stale Data
- [ ] `ui/manage/goals/goals_screen.dart`: After add/edit modal closes → call controller refresh or check modal result
- [ ] `ui/manage/budgets/budget_details_screen.dart`: Add `Consumer<TransactionsController>` to listen for new transactions
- [ ] `ui/manage/contacts_screen.dart`: On person sheet open → reload from controller (not cached value)
- [ ] `ui/manage/accounts_screen.dart`: Clear `_filterSortCache` when `AccountsController` notifies listeners

#### Navigation
- [ ] `ui/manage/categories_screen.dart`: Category card `onTap` → open edit modal (not just `log()`)
- [ ] `ui/manage/goals/goals_screen.dart`: "Expiring soon" banner → scroll to first expiring goal
- [ ] `ui/dashboard/dashboard_action_sheet.dart`: Use `Navigator.popAndPushNamed()` to prevent race
- [ ] `ui/dashboard/transaction_wizard.dart`: Add bounds check to `_navigateToStep()`

### Commit message
```
feat(ux): empty states, stale data refresh, navigation fixes

- notifications: add 'all caught up' empty state
- budget_widget: add CTA to empty state
- goal_details: back button in not-found state
- skeleton_loader: add timeout + retry
- goals_screen: refresh on modal close
- budget_details: listen to TransactionsController
- contacts_screen: reload on sheet open
- accounts_screen: clear cache on controller notify
- categories_screen: tap card to open edit modal
- goals_screen: 'expiring soon' banner scrolls to item
- dashboard_action_sheet: prevent navigation race
- transaction_wizard: bounds-check _navigateToStep
```

---

# BATCH 14 — Performance
**Status:** `[ ]`
**Risk:** Low — optimizations, no behaviour changes
**Goal:** 60fps on all screens, no main-thread freezes, no timer leaks
**MASTER_PLAN IDs:** PERF-01→06

### Files to touch (5 files)

#### 1. `lib/ui/widgets/liquid_progress_indicators.dart`
- [ ] Wave path currently recalculated every frame. Cache the path:
  Store `_cachedPath` and `_cachedSize`. Only recalculate in `shouldRepaint()` when size changes.

#### 2. `lib/ui/dashboard/widgets/health_score_widget.dart`
- [ ] Score animation re-runs on every rebuild. Add a `_hasAnimated` flag:
  Only run animation once; use `ValueKey(score)` to trigger new animation only when score actually changes.

#### 3. `lib/ui/manage/reports_analysis_screen.dart`
- [ ] Move heavy aggregation into `compute()` isolate:
  ```dart
  final result = await compute(_aggregateReportData, reportParams);
  ```
  Create a top-level (non-closure) function `_aggregateReportData` that takes a simple data class.

#### 4. `lib/ui/spending_insights_screen.dart`
- [ ] Split `Consumer2<TransactionsController, BudgetsController>` into separate consumers per section.
  Or use `Selector<TransactionsController, List<Transaction>>` to limit rebuild trigger.

#### 5. `lib/ui/widgets/global_search_overlay.dart`
- [ ] Increase result limits from 5/3/5/3/3 to 10 per category.
- [ ] Add "Show more" button per category instead of hard cap.

### Commit message
```
perf: cache wave path, isolate report aggregation, reduce rebuilds

- liquid_progress: cache wave path; only recalculate on size change
- health_score_widget: animate once; only re-trigger when score changes
- reports_screen: move aggregation to compute() isolate
- spending_insights: split Consumer2 into selective consumers
- global_search: increase result limits, add 'show more'
```

---

# BATCH 15 — P3 Polish
**Status:** `[ ]`
**Risk:** Low — visual and interaction improvements
**Goal:** Haptic feedback, delete confirmations, animation quality, accessibility
**MASTER_PLAN IDs:** UX-01→06, DEL-01→03, ANIM-01→03, FMT-01→04, STATE-01→03

### Files to touch (~12 files)

#### Delete Confirmations
- [ ] `ui/manage/goals/goals_screen.dart`: Show `showCupertinoDialog` before swipe-delete; undo toast for 5s
- [ ] `ui/manage/budgets/budgets_screen.dart`: Same
- [ ] `ui/manage/tags_screen.dart`: Same

#### Haptic Feedback
- [ ] `ui/dashboard/dashboard_settings_modal.dart`: `HapticFeedback.selectionClick()` on `CupertinoSwitch` toggle
- [ ] `ui/onboarding_screen.dart`: `HapticFeedback.lightImpact()` on Next / Get Started buttons
- [ ] `ui/dashboard/widgets/transaction_history_widget.dart`: Tap feedback on transaction items

#### Dashboard Interactivity
- [ ] `ui/dashboard/widgets/budget_widget.dart`: Budget bars tappable → navigate to budget detail
- [ ] `ui/transaction_history_screen.dart`: Highlight active type filter chip with `isSelected: true`

#### Animation Quality
- [ ] `ui/dashboard/widgets/health_score_widget.dart`: `ValueKey(score)` to control re-animation
- [ ] `ui/widgets/card_deck_view.dart`: Wait for promotion animation before resetting swipe controller
- [ ] `ui/widgets/animated_counter.dart` line 575: Fix particle direction bias using `(random.nextDouble() - 0.5) * 2`

#### Formatting & Accessibility
- [ ] `ui/widgets/card_deck_view.dart`: Add `semanticLabel: 'Card ${index + 1} of $total'`
- [ ] `utils/pref_keys.dart`: Add `@deprecated` comments above legacy keys

#### State Persistence
- [ ] `ui/manage/goals/goals_screen.dart`: Save search query to `PageStorage`
- [ ] `ui/manage/budgets/budgets_screen.dart`: Save filter period to `PageStorage`

### Commit message
```
polish: delete confirmations, haptics, animation fixes, accessibility

- goals/budgets/tags: confirmation dialogs before delete with undo toast
- dashboard_settings: haptic on switch toggle
- onboarding: haptic on CTA buttons
- budget_widget: budget bars navigate to detail
- transaction_history: active filter chip highlighted
- health_score: ValueKey prevents spurious re-animation
- card_deck_view: await promotion before swipe reset; add semantic labels
- animated_counter: fix particle direction bias
- pref_keys: add @deprecated on legacy keys
- goals/budgets: persist search/filter state via PageStorage
```

---

# Appendix: Dependency Map
Some batches depend on others. Do not reorder:

```
B01 (models) ──────────────────────────────────┐
B02 (saves) ──────────────────────────────────┐ │
B03 (http + export) ── independent            │ │
B04 (async/mounted) ─────────────────────────┐│ │
B05 (transactional integrity) ← needs B04   ││ │
B06 (wizard controllers) ← needs B01        ││ │
B07 (security) ── mostly independent        ││ │
B08 (cascade deletes) ← needs B02           ││ │
B09 (memory) ── independent                 ││ │
B10 (services/sms) ── independent           ││ │
B11 (calculations) ← needs B06             ││ │
B12 (startup/lock) ── independent           ││ │
B13 (ux) ← benefits from B01,B02           │└─┘
B14 (perf) ── independent                  │
B15 (polish) ← benefits from all           └──
```

**Recommended order if splitting across multiple days:**
- Day 1: B01 → B02 → B03 (all low-risk, high safety impact)
- Day 2: B04 → B05 (async and transactional, medium risk)
- Day 3: B06 → B07 (wizard fixes and security)
- Day 4: B08 → B09 → B10 (data integrity and services)
- Day 5: B11 → B12 (calculations and startup)
- Day 6+: B13 → B14 → B15 (UX improvements)
