# VittaraFinOS — Implementation Plan
> Derived from full 289-file deep audit (2026-03-25). ~294 issues → 20 logical batches.
> **Status:** Awaiting approval. Tick `[A]` to approve each batch, `[S]` to skip.
> After approval, work starts top-to-bottom. Each batch ends with commit + APK.

---

## HOW TO READ THIS FILE
- Each batch lists: **what breaks**, **exactly what to change**, **files touched**
- Batches are ordered so later batches don't break earlier fixes
- Complexity: 🟢 Easy (<2h) · 🟡 Medium (2–5h) · 🔴 Hard (5h+)
- Do NOT reorder batches — dependencies exist between them

---

# ── TIER 1: P0 CRITICAL (must fix before anything) ──────────────────────────

---

## BATCH 1 — Security Hardening
**Status:** `[x]` Done — committed
**Complexity:** 🔴 Hard (security-sensitive, careful implementation)
**Issues:** SEC-01, SEC-02, SEC-03, SEC-04

### What's broken
1. **SEC-01**: Backup encryption uses a hardcoded byte array (`_masterSecretSeed`) compiled into the APK. Anyone who decompiles the APK can derive the master key and decrypt any user's backup file.
2. **SEC-02**: PIN is hashed with salt `'vittara_pin_salt_$pin'` — the salt is derived from the PIN itself, same for every user. Rainbow tables work against this.
3. **SEC-03**: Recovery code is copied to clipboard; if user backgrounds the app before 60s, the code stays in the system clipboard (accessible to other apps like keyboards).
4. **SEC-04**: Old `hmac-sha256-stream-xor-v1` backup format silently accepted alongside v2 — users can't migrate, and old backups have v1's weak key.

### Exact changes
**`logic/backup_restore_service.dart`**
- Remove hardcoded `_masterSecretSeed` bytes
- Derive encryption key from: `PBKDF2(userDeviceId + installDate, randomSalt, 100000 iterations)`
- Store salt in `SharedPreferences` under `'backup_key_salt'`
- First run: generate salt, derive key, save salt
- Subsequent runs: read salt, re-derive key
- Add migration: detect v1 backup → prompt user to re-encrypt with v2 key

**`logic/settings_controller.dart`**
- Replace `_hashPin(pin)` which uses `'vittara_pin_salt_$pin'`
- Generate a random 16-byte salt on first PIN set: `List.generate(16, (_) => Random.secure().nextInt(256))`
- Store salt as hex in `SharedPreferences` under `'pin_salt'`
- Hash: `SHA-256(salt + pin)` using `crypto` package
- On PIN verify: read salt, re-hash, compare

**`ui/recovery_code_save_screen.dart`**
- Add `WidgetsBindingObserver` to the screen's State
- In `didChangeAppLifecycleState`: when state == `AppLifecycleState.paused`, call `Clipboard.setData(ClipboardData(text: ''))` immediately (don't wait for timer)
- Keep existing 60s timer for foreground case

**`logic/backup_restore_service.dart`**
- Add `_migrateFromV1(backupData)` path that decrypts with old key, re-encrypts with new key
- Show migration prompt on first restore of v1 backup

### Files touched
- `logic/backup_restore_service.dart`
- `logic/settings_controller.dart`
- `ui/recovery_code_save_screen.dart`

---

## BATCH 2 — Async Lifecycle Safety (mounted checks)
**Status:** `[x]` Done — committed
**Complexity:** 🟢 Easy (mechanical fix, low risk)
**Issues:** ASYNC-01, ASYNC-02, ASYNC-03, ASYNC-04, ASYNC-05

### What's broken
Every one of these crashes if the user navigates away during an async operation (network fetch, DB write). The app calls `setState()`, `Navigator.pop()`, or shows a toast on a widget that no longer exists in the tree.

1. **ASYNC-01** `fd_wizard_screen.dart:138,144` — `showSuccess()` toast fires BEFORE `if (mounted)` check
2. **ASYNC-02** `pin_recovery_screen.dart:208` — `popUntil()` called after 10s nuclear reset without mounted check
3. **ASYNC-03** `mf_wizard.dart:163` — `setState(() => _isSubmitting = true)` before network fetch, no mounted check
4. **ASYNC-04** `nps_wizard.dart:97-105` — `_saveInvestment()` never checks mounted before toast/nav
5. **ASYNC-05** `stocks_wizard.dart:133-146` — `Navigator.pop()` THEN `context.mounted` check (wrong order)

### Exact changes
**Pattern to apply in every case:**
```dart
// BEFORE (wrong):
await someAsyncWork();
showSuccessToast(context, 'Done');
Navigator.of(context).pop();

// AFTER (correct):
await someAsyncWork();
if (!mounted) return;
showSuccessToast(context, 'Done');
Navigator.of(context).pop();
```

**`ui/manage/fd/fd_wizard_screen.dart`**
- Line 138: add `if (!mounted) return;` before `showSuccess()`
- Line 144: ensure `if (!mounted) return;` is BEFORE `Navigator.pop()`

**`ui/pin_recovery_screen.dart`**
- After all async nuclear reset operations complete (line ~208): add `if (!mounted) return;` before `popUntil()`

**`ui/manage/mf/mf_wizard.dart`**
- Line 163: move `if (!mounted) return;` to before `setState(() => _isSubmitting = true)`
- Also audit `_updateInvestment()` for same pattern

**`ui/manage/nps/nps_wizard.dart`**
- Add `if (!mounted) return;` at top of post-await section in `_saveInvestment()`

**`ui/manage/stocks/stocks_wizard.dart`**
- Lines 133-146: reorder to check mounted FIRST, then pop, then show toast

**Bonus (same session):** Do a grep for all `async` functions in `ui/manage/` that call `Navigator` or `setState` without a mounted check, and fix any additional ones found.

### Files touched
- `ui/manage/fd/fd_wizard_screen.dart`
- `ui/pin_recovery_screen.dart`
- `ui/manage/mf/mf_wizard.dart`
- `ui/manage/nps/nps_wizard.dart`
- `ui/manage/stocks/stocks_wizard.dart`
- (any additional found by grep)

---

## BATCH 3 — Save Reliability (fire-and-forget fixes)
**Status:** `[x]` Done — committed
**Complexity:** 🟢 Easy (mechanical, one pattern)
**Issues:** SAVE-01 through SAVE-08

### What's broken
8 controllers call `_save()` without `await`, then immediately call `notifyListeners()`. The UI updates (user sees the change) but if the app crashes in the next 100ms, the save never completes and the change is lost on restart. In the case of `recurring_templates_controller.dart`, the order is even reversed — it notifies before saving at all.

### Exact changes
**One pattern to fix everywhere:**
```dart
// BEFORE (wrong):
_saveAccounts();        // fire-and-forget
notifyListeners();      // UI updates, but save might not be done

// AFTER (correct):
await _saveAccounts();  // wait for persistence
notifyListeners();      // then update UI
```

**Changes per file:**

**`logic/accounts_controller.dart:115-123`** — `reorderAccounts()`: add `await`

**`logic/investments_controller.dart:156-165`** — `reorderInvestments()`: add `await`

**`logic/categories_controller.dart:203`** — `reorderCategories()`: also missing the `_saveCustomCategories()` call entirely — add `await _saveCustomCategories();` before `notifyListeners()`

**`logic/budgets_controller.dart:116-125`** — `updateBudgetSpending()`: add `await`

**`logic/lending_borrowing_controller.dart:46,56`** — `addRecord()` and `updateRecord()`: add `await`

**`logic/payment_apps_controller.dart:184-193`** — `adjustWalletBalanceByName()`: add `await`

**`logic/recurring_templates_controller.dart:53`** — Reverse order: move `await _save()` to BEFORE `notifyListeners()`

**`logic/transactions_archive_controller.dart:15`** — Add `isLoaded` bool field, set to `true` after `_loadArchivedTransactions()` completes, add `notifyListeners()` at end of load, so callers can wait for `isLoaded`

### Files touched
- `logic/accounts_controller.dart`
- `logic/investments_controller.dart`
- `logic/categories_controller.dart`
- `logic/budgets_controller.dart`
- `logic/lending_borrowing_controller.dart`
- `logic/payment_apps_controller.dart`
- `logic/recurring_templates_controller.dart`
- `logic/transactions_archive_controller.dart`

---

## BATCH 4 — Model Type Safety & Enum Standardisation
**Status:** `[x]` Done — committed
**Complexity:** 🟡 Medium (many files, but mechanical pattern)
**Issues:** MDL-01 through MDL-08

### What's broken
Three classes of crash-on-load bugs:

**A) Unsafe enum index access** — `BudgetPeriod.values[99]` throws `RangeError`. Triggered by: any DB record where the enum has since been reordered, or a corrupted value. Affects Budget, Goal, RD, Bond, NPS, F&O, Crypto, Commodity models.

**B) Inconsistent enum serialisation** — Loan uses `.name` (string), LendingBorrowing uses `.toString().contains(...)`, Insurance uses `.name`, others use `.index`. When any enum is reordered/renamed, the wrong item loads silently.

**C) Unsafe double casts** — `map['amount'] as double` throws if the DB stored an int (SQLite stores numbers as int when they have no decimal). Should always use `(map['amount'] as num?)?.toDouble() ?? 0.0`.

### Exact changes

**Enum index safety — apply this wrapper to every `EnumType.values[n]` call:**
```dart
// Helper to add to a utils file:
T safeEnum<T>(List<T> values, int? index, T fallback) {
  if (index == null || index < 0 || index >= values.length) return fallback;
  return values[index];
}

// Usage:
BudgetPeriod period = safeEnum(BudgetPeriod.values, map['period'] as int?, BudgetPeriod.monthly);
```

Apply `safeEnum()` to:
- `logic/budget_model.dart:172` — `BudgetPeriod`
- `logic/goal_model.dart:156` — `GoalType`
- `logic/recurring_deposit_model.dart:229` — `RDPaymentFrequency`
- `logic/bonds_model.dart:243-246` — `BondType`, `CouponFrequency`, `BondStatus`
- `logic/nps_model.dart:160-162` — `NPSTier`, `NPSAccountType`, `NPSManager`
- `logic/fo_model.dart:224` — `FOType`
- `logic/commodities_model.dart:75` — `CommodityType`, `TradePosition`
- `logic/cryptocurrency_model.dart:213` — `CryptoCurrency`
- `logic/account_model.dart:85` — `AccountType`

**Enum serialisation — standardise ALL models to `.index`:**
- `logic/loan_model.dart:92` — change `type.name` to `type.index` in `toMap()`, change `fromMap()` to use `safeEnum(LoanType.values, map['type'] as int?, LoanType.personal)`
- `logic/lending_borrowing_model.dart:91,106-107` — replace `.toString().contains('lent')` with `safeEnum(LendingType.values, map['type'] as int?, LendingType.lent)`
- `logic/insurance_model.dart:117` — change `.name` → `.index` pattern

**Unsafe double casts — apply safe pattern:**
```dart
// Replace all: map['x'] as double
// With:        (map['x'] as num?)?.toDouble() ?? 0.0
```
- `logic/investment_model.dart:115` — `amount`
- `logic/fixed_deposit_model.dart:274` — `withdrawalAmount`
- `logic/bonds_model.dart:258` — `redemptionPrice`
- `logic/stock_transaction_model.dart:72-73` — `qty`, `pricePerShare`
- `logic/transaction_model.dart:93-96` — verify `amount` is safe

**`logic/payment_apps_controller.dart:38`**
- Change `item['color'] as int` to `(item['color'] as int?) ?? 0xFF808080`

### Files touched (14 files)
`logic/budget_model.dart`, `logic/goal_model.dart`, `logic/recurring_deposit_model.dart`, `logic/bonds_model.dart`, `logic/nps_model.dart`, `logic/fo_model.dart`, `logic/commodities_model.dart`, `logic/cryptocurrency_model.dart`, `logic/account_model.dart`, `logic/loan_model.dart`, `logic/lending_borrowing_model.dart`, `logic/insurance_model.dart`, `logic/investment_model.dart`, `logic/fixed_deposit_model.dart`, `logic/stock_transaction_model.dart`, `logic/transaction_model.dart`, `logic/payment_apps_controller.dart`

---

## BATCH 5 — P0 Calculation Crashes
**Status:** `[x]` Done — committed
**Complexity:** 🟢 Easy (targeted guards)
**Issues:** CALC-01, CALC-02, CALC-03, CALC-04, CALC-05

### What's broken
1. **CALC-01** `investment_value_service.dart:208` — `365 / compoundsPerYear` where compoundsPerYear can be 0 → `Infinity`
2. **CALC-02** `ai_planner_engine.dart:69` — `DateTime(now.year, now.month - 3, 1)` in January → month = -2 → Flutter throws
3. **CALC-03** `gold_price_service.dart:41` — caches and returns 0 or negative gold price if API returns bad data
4. **CALC-04** `budget_details_screen.dart:107` — `spentAmount / limitAmount` where limitAmount can be 0
5. **CALC-05** `goals_controller.dart:391` — `overallProgress` denominator can be 0 if all goals have `targetAmount = 0`

### Exact changes

**`services/investment_value_service.dart`**
```dart
// Line ~208, before compound formula:
if (compoundsPerYear <= 0) return principal; // guard
final daysPerCompound = 365.0 / compoundsPerYear;
```

**`logic/ai_planner_engine.dart`**
```dart
// Line 69, replace:
final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
// With:
final threeMonthsAgo = DateTime(now.year, now.month, 1).subtract(const Duration(days: 90));
```

**`services/gold_price_service.dart`**
```dart
// After computing price, before caching:
if (price <= 0) {
  debugPrint('[GoldPrice] Invalid price $price, not caching');
  return _cachedPrice; // return last valid or null
}
_cachedPrice = price;
```

**`ui/manage/budgets/budget_details_screen.dart`**
```dart
// Replace bare division:
final pct = limitAmount > 0 ? (spentAmount / limitAmount).clamp(0.0, double.infinity) : 0.0;
```

**`logic/goals_controller.dart`**
```dart
// In overallProgress getter:
final totalTarget = goals.fold(0.0, (s, g) => s + g.targetAmount);
if (totalTarget <= 0) return 0.0; // guard
```

### Files touched
- `services/investment_value_service.dart`
- `logic/ai_planner_engine.dart`
- `services/gold_price_service.dart`
- `ui/manage/budgets/budget_details_screen.dart`
- `logic/goals_controller.dart`

---

## BATCH 6 — Database: Migration & Concurrent Write Protection
**Status:** `[x]` Done — committed
**Complexity:** 🔴 Hard (database changes, must not break existing data)
**Issues:** DB-01, DB-02 (partial), DB-03, DB-04

### What's broken
1. **DB-01**: `DatabaseHelper` has `version: 1` and `onUpgrade: null`. Any future column addition will crash existing users' apps on upgrade — there is literally no migration path.
2. **DB-03**: Two simultaneous writes to SharedPreferences (e.g., SMS auto-scan adding a transaction + user manually adding one) will result in one write being silently lost (last write wins, overwrites the other).
3. **DB-04**: Most-queried columns (`dateTime`, `accountId`, `categoryId`) have no indexes in SQLite. For MF table specifically: missing `is_active`, `scheme_code` indexes.

> **Note on DB-02** (full SQLite migration): This is an ARCH-01 recommendation — massive effort, separate standalone batch. Not in this batch.

### Exact changes

**`services/database_helper.dart`**
- Add `_kDbVersion = 2` constant
- Add `onUpgrade: (db, oldVersion, newVersion) async { await _runMigrations(db, oldVersion, newVersion); }`
- Add `_runMigrations()` method with switch/case by version:
  ```dart
  static Future<void> _runMigrations(Database db, int oldV, int newV) async {
    for (int v = oldV + 1; v <= newV; v++) {
      switch (v) {
        case 2: await _migrate_v1_to_v2(db); break;
      }
    }
  }
  static Future<void> _migrate_v1_to_v2(Database db) async {
    // Add is_active index if missing
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mf_is_active ON mutual_funds(is_active)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mf_scheme_code ON mutual_funds(scheme_code)');
  }
  ```
- Bump version to 2

**Concurrent write protection — add `AsyncMutex` helper:**
- Create `utils/async_mutex.dart`:
  ```dart
  import 'dart:async';
  class AsyncMutex {
    Completer<void>? _completer;
    Future<void> acquire() async {
      while (_completer != null) await _completer!.future;
      _completer = Completer<void>();
    }
    void release() {
      _completer?.complete();
      _completer = null;
    }
    Future<T> protect<T>(Future<T> Function() fn) async {
      await acquire();
      try { return await fn(); } finally { release(); }
    }
  }
  ```
- Add `static final _writeMutex = AsyncMutex()` to `TransactionsController`
- Wrap `_saveTransactions()` call: `await _writeMutex.protect(() => _saveTransactions())`
- Do same for `AccountsController`, `InvestmentsController` (the three highest-concurrency controllers)

### Files touched
- `services/database_helper.dart`
- `utils/async_mutex.dart` (new)
- `logic/transactions_controller.dart`
- `logic/accounts_controller.dart`
- `logic/investments_controller.dart`

---

# ── TIER 2: P1 BROKEN FEATURES ───────────────────────────────────────────────

---

## BATCH 7 — Investment Money Flow (balance integrity)
**Status:** `[x]` Done — committed
**Complexity:** 🔴 Hard (touches money — must be exactly right)
**Issues:** INV-01, INV-02, INV-03, INV-05, INV-06, INV-07, INV-12, INV-13, INV-14

### What's broken
**The big one:** When a user creates an investment with "deduct from account", the account balance is debited. But when they delete that investment or sell it fully, the account balance is NEVER credited back. The money is gone from the account permanently.

Examples:
- User adds stock ₹10,000, deducted from savings → savings = -₹10,000 from this
- User deletes the stock → investment gone, savings still -₹10,000
- Net worth is permanently wrong

Secondary: FD calculations have bugs (lossy day→month conversion, accrued value frozen at creation).

### Exact changes

**Investment delete → reverse debit (applies to: stocks, simple investments, MF full-sell):**

**`ui/manage/investments/simple_investment_details_screen.dart`**
```dart
// In _deleteInvestment(), before removing investment:
final linkedAccountId = investment.metadata?['linkedAccountId'] as String?;
final deductedAmount = investment.metadata?['deductedAmount'] as double?;
if (linkedAccountId != null && deductedAmount != null && deductedAmount > 0) {
  final account = accountsCtrl.accounts.firstWhereOrNull((a) => a.id == linkedAccountId);
  if (account != null) {
    await accountsCtrl.updateAccount(account.copyWith(balance: account.balance + deductedAmount));
  }
}
// Then delete investment
```

**`ui/manage/stocks/stocks_wizard.dart`**
- Same pattern in delete path
- Ensure creation stores `linkedAccountId` and `deductedAmount` in metadata if debit was made

**`ui/manage/mf/mf_wizard.dart`**
- In full-sell path (when units drop to 0): credit back the original deduction account
- Same pattern: read `linkedAccountId` + `deductedAmount` from metadata, credit account

**Bond YTM fix (`ui/manage/bonds/bonds_wizard_controller.dart:112`)**
```dart
// Replace hardcoded:
final yearsToMaturity = 5.0;
// With:
final yearsToMaturity = maturityDate != null
    ? maturityDate!.difference(DateTime.now()).inDays / 365.25
    : 0.0;
if (yearsToMaturity <= 0) return 0.0; // matured bond
```

**FD lossy day conversion (`logic/fd_calculations.dart`, `ui/manage/fd/fd_wizard_controller.dart:96-111`)**
- Add `tenureDays` field to `FixedDeposit` model (if not present)
- In wizard, when user enters tenure in days: store raw days, derive months for display only
- Compute `maturityDate` from `startDate.add(Duration(days: tenureDeDays))`

**FD accrued value (`ui/manage/fd/fd_wizard_screen.dart:377-378`)**
- Remove `estimatedAccruedValue: principal` at creation (wrong)
- Compute accrued dynamically in `FDDetailsScreen` using `FDCalculations.accruedValue(principal, rate, compoundFreq, elapsed)`

**`logic/fd_calculations.dart:92-107` — custom pow() bug**
- Remove the custom `pow()` helper entirely
- Use `dart:math`'s `pow()` directly everywhere in the file

**`logic/fd_renewal_cycle.dart:39-43` — pro-rata simple interest**
```dart
// Replace linear fraction:
final fraction = daysSinceInvestment / totalDays;
return principal + (principal * annualRate / 100 * fraction);
// With compound accrual:
final years = daysSinceInvestment / 365.0;
return FDCalculations.maturityValue(principal, annualRate, compoundFreq, years);
```

**`logic/bond_cashflow_model.dart:362-363` — 30-day month**
```dart
// Replace:
totalMonths = maturityDate.difference(purchaseDate).inDays ~/ 30;
// With:
totalMonths = (maturityDate.year - purchaseDate.year) * 12 +
              (maturityDate.month - purchaseDate.month);
```

### Files touched
- `ui/manage/investments/simple_investment_details_screen.dart`
- `ui/manage/stocks/stocks_wizard.dart`
- `ui/manage/mf/mf_wizard.dart`
- `ui/manage/bonds/bonds_wizard_controller.dart`
- `logic/fd_calculations.dart`
- `ui/manage/fd/fd_wizard_controller.dart`
- `logic/fd_renewal_cycle.dart`
- `logic/bond_cashflow_model.dart`
- `logic/fixed_deposit_model.dart` (add `tenureDays` field if needed)

---

## BATCH 8 — CRUD Cascade & Orphan Prevention
**Status:** `[x]` Done — committed
**Complexity:** 🟡 Medium
**Issues:** CRUD-01 through CRUD-08, NAV-03, NAV-06, NAV-07

### What's broken
- Delete category → budgets still reference it (budget screen breaks)
- Delete contact → lending/borrowing records are orphaned
- Delete bank → accounts still reference deleted bank
- Contact edit is `delete + add` — if add fails, the contact is permanently lost
- Category card tap does nothing (just logs)
- Lock screen doesn't cover modal sheets

### Exact changes

**Category delete (`ui/manage/categories_screen.dart`)**
```dart
// Before deleting category:
final inUseBudgets = budgetsCtrl.budgets.where((b) => b.categoryName == cat.name).toList();
final inUseTransactions = txCtrl.transactions.where((t) =>
    (t.metadata?['categoryName'] as String?) == cat.name).length;
if (inUseBudgets.isNotEmpty || inUseTransactions > 0) {
  // Show warning dialog: "X budgets and Y transactions use this category. Delete anyway?"
  // If confirmed: set those budget.categoryName = 'Other', not hard delete
}
```

**Contact delete (`ui/manage/contacts_screen.dart`)**
```dart
// Before deleting contact:
final hasRecords = lendingCtrl.records.any((r) => r.contactName == contact.name);
if (hasRecords) {
  showWarningDialog('This contact has active lending/borrowing records. Delete anyway?');
  // If confirmed: keep records, just nullify contact link (set contactName to name, contactId to null)
}
```

**Bank delete (`ui/manage/banks_screen.dart`)**
```dart
// Before deleting bank:
final linkedAccounts = accountsCtrl.accounts.where((a) => a.bankId == bank.id).toList();
if (linkedAccounts.isNotEmpty) {
  showWarningDialog('${linkedAccounts.length} accounts are linked to this bank.');
  // If confirmed: set those accounts' bankId = null
}
```

**Contact edit — make atomic (`ui/manage/contacts_screen.dart:843-854`)**
- Add `updateContact(Contact updated)` method to `ContactsController` that modifies in-place
- Replace `removeContact + addContact` with single `updateContact` call

**CRUD-07 — contact dedup fix (`logic/contacts_controller.dart:47-60`)**
```dart
// Replace object identity check:
final existing = _contacts.firstWhereOrNull((c) => c.name.toLowerCase() == name.toLowerCase());
if (existing != null) return existing;
final newContact = Contact(id: IdGenerator.generate(), name: name);
_contacts.add(newContact);
await _saveContacts();
notifyListeners();
return newContact;
```

**CRUD-08 — undo verify (`ui/manage/goals/goals_screen.dart`)**
```dart
// After delete, before showing undo:
final deleteSucceeded = await goalsCtrl.deleteGoal(goal.id);
if (!deleteSucceeded) { showError('Failed to delete'); return; }
// Show undo toast only if delete confirmed
```

**NAV-03 — Category card tap (`ui/manage/categories_screen.dart:277-280`)**
- Add `onTap: () => _showEditCategoryModal(context, category)` to category card GestureDetector

**NAV-06 — Lock screen over modals (`main.dart`)**
- Change lock overlay from `Positioned.fill` inside a `Stack` to using `Navigator.of(context, rootNavigator: true)` to push an opaque lock route that covers everything including modals

**NAV-07 — Contact edit navigation (`ui/manage/contacts_screen.dart`)**
- After edit dialog closes, if user was in person detail sheet: re-open person sheet with updated contact

### Files touched
- `ui/manage/categories_screen.dart`
- `ui/manage/contacts_screen.dart`
- `logic/contacts_controller.dart`
- `ui/manage/banks_screen.dart`
- `ui/manage/goals/goals_screen.dart`
- `main.dart`

---

## BATCH 9 — Wizard Validation & Input Bounds
**Status:** `[x]` Done — committed
**Complexity:** 🟡 Medium
**Issues:** VAL-01 through VAL-09

### What's broken
- RD wizard: step 1 `canProceed` always returns `true` regardless of startDate
- FD wizard: interest rate allows 0–∞% (1000% accepted)
- Stocks wizard: deduction step never blocks even if account goes negative
- Budgets/Goals: no upper bound on amounts (₹10 billion accepted)
- Lending wizard: null amount coalesced to 0, accepted
- Payment apps: null color crashes on load

### Exact changes

**`ui/manage/rd/rd_wizard_controller.dart:122-141`**
```dart
// In canProceedToNextStep for step 1:
case 1: return startDate != null; // was: return true
```

**`ui/manage/fd/fd_wizard_controller.dart:193-213`**
```dart
// Add upper bound to interest rate:
case 3: return interestRate > 0 && interestRate <= 25.0;
// Add: if rate > 25, show inline warning "Please verify — rate seems high"
```

**`ui/manage/stocks/stocks_wizard_controller.dart:91-104`**
```dart
// Step 3 deduction check:
case 3:
  if (deductFromAccount && selectedAccount != null) {
    final balanceAfter = selectedAccount!.balance - totalAmount;
    if (balanceAfter < 0) {
      deductionWarning = 'Account balance will go negative (₹${balanceAfter.abs().toStringAsFixed(0)} short)';
      // Show warning in UI but still allow proceed (just warn, don't block — user may know what they're doing)
    }
  }
  return true;
```

**`ui/manage/budgets/modals/add_budget_modal.dart`**
```dart
// Add validation:
if (amount <= 0) { showError('Enter a valid budget amount'); return; }
if (amount > 10000000) { showError('Budget limit seems too high (max ₹1Cr)'); return; }
```

**`ui/manage/goals/modals/add_goal_modal.dart`** — same cap

**`ui/manage/goals/modals/add_contribution_modal.dart`**
```dart
if (amount == null || amount <= 0) { showError('Enter a valid amount'); return; }
```

**`ui/manage/lending_wizard.dart`**
```dart
final amount = double.tryParse(amountController.text);
if (amount == null || amount <= 0) { showError('Enter a valid amount'); return; }
```

**`logic/payment_apps_controller.dart:38`**
```dart
color: Color((item['color'] as int?) ?? 0xFF607D8B),
```

**`ui/manage/nps/nps_wizard_controller.dart:45-69`**
```dart
// Step 3: require date for non-none withdrawal:
case 3: return withdrawalType == NPSWithdrawalType.none || plannedRetirementDate != null;
```

### Files touched
- `ui/manage/rd/rd_wizard_controller.dart`
- `ui/manage/fd/fd_wizard_controller.dart`
- `ui/manage/stocks/stocks_wizard_controller.dart`
- `ui/manage/budgets/modals/add_budget_modal.dart`
- `ui/manage/goals/modals/add_goal_modal.dart`
- `ui/manage/goals/modals/add_contribution_modal.dart`
- `ui/manage/lending_wizard.dart`
- `logic/payment_apps_controller.dart`
- `ui/manage/nps/nps_wizard_controller.dart`

---

## BATCH 10 — Calculation Correctness
**Status:** `[x]` Done — committed
**Complexity:** 🟡 Medium (maths-heavy but isolated)
**Issues:** CALC-10 through CALC-18

### What's broken
Date range query excludes transactions at exact boundary times. XIRR is a simple ratio, not time-weighted. PIN lockout counter off-by-one. Goal floating-point edge case. Loan EMI < interest causes negative principal. Bond YTM hardcoded. F&O max profit wrong for long put. Month overflow in recurring templates.

### Exact changes

**`logic/transactions_controller.dart:119-120` — date range boundary fix**
```dart
// Replace:
.where((t) => t.dateTime.isAfter(start) && t.dateTime.isBefore(end))
// With:
.where((t) => !t.dateTime.isBefore(start) && !t.dateTime.isAfter(end))
```

**`services/nav_service.dart:180-200` — XIRR (proper Newton-Raphson)**
- Replace simple ratio with:
```dart
double calculateXIRR(List<({double amount, DateTime date})> cashflows) {
  // Implement Newton-Raphson NPV iteration
  // Convergence tolerance: 1e-6, max iterations: 100
  // Return annual rate as decimal
}
```
This is the standard XIRR algorithm used by Excel/Google Sheets.

**`logic/pin_recovery_controller.dart:116` — lockout counter**
```dart
// Replace:
remainingBeforeLockout: 3 - attempts
// With:
remainingBeforeLockout: math.max(0, 3 - attempts)
```

**`logic/goals_controller.dart:99` — FP tolerance**
```dart
// Replace:
isCompleted: newCurrentAmount >= goal.targetAmount
// With:
isCompleted: newCurrentAmount >= goal.targetAmount - 0.005
```

**`logic/goals_controller.dart:123` — withdrawal clamp**
```dart
// Remove upper cap — allow overfunding:
newAmount: math.max(0.0, goal.currentAmount - amount)
// (not clamped to targetAmount)
```

**`ui/manage/loans/loan_tracker_screen.dart:711-725` — EMI < interest warning**
```dart
// After computing schedule, check:
if (emiAmount <= (outstandingBalance * monthlyRate)) {
  showWarning('EMI is less than monthly interest — loan will never be paid off');
}
```

**`logic/fo_model.dart:102-103` — put option max profit**
```dart
// For long put: maxProfit = (strikePrice - entryPrice) * quantity
// For short put: maxProfit = entryPrice * quantity (premium received)
// Add field: bool isLong (default true)
double get maxProfit {
  if (type == FOType.put) {
    return isLong
      ? math.max(0, (strikePrice! - entryPrice) * quantity)
      : entryPrice * quantity;
  }
  // ... existing call logic
}
```

**`logic/recurring_template_model.dart:141` — month overflow**
```dart
// Replace: DateTime(base.year, base.month + 1, base.day)
// With safe helper:
DateTime safeAddMonth(DateTime base) {
  final next = DateTime(base.year, base.month + 1, 1);
  final maxDay = DateUtils.getDaysInMonth(next.year, next.month);
  return DateTime(next.year, next.month, math.min(base.day, maxDay));
}
```

**`services/transaction_export_service.dart:556-560` — Crore threshold**
```dart
if (v > 1e7) return '₹${(v/1e7).toStringAsFixed(2)}Cr'; // was >=
```

**`utils/percent_formatter.dart:7-15` — precision**
```dart
if (value > 0 && formatted == '0') return '< 0.01%';
```

### Files touched
- `logic/transactions_controller.dart`
- `services/nav_service.dart`
- `logic/pin_recovery_controller.dart`
- `logic/goals_controller.dart` (×2)
- `ui/manage/loans/loan_tracker_screen.dart`
- `logic/fo_model.dart`
- `logic/recurring_template_model.dart`
- `services/transaction_export_service.dart`
- `utils/percent_formatter.dart`

---

## BATCH 11 — Navigation & UI State Bugs
**Status:** `[x]` Done — committed
**Complexity:** 🟡 Medium
**Issues:** NAV-01, NAV-02, NAV-04, NAV-05, NAV-08, SAVE-related UI issues

### What's broken
- PIN setup recovery code screen: back button double-pops, leaves setup incomplete
- Notifications: mounted check happens after Navigator.push (wrong order)
- "Expiring Soon" banner does nothing on tap
- Loan card: long-press → action sheet, tap → detail (confusing dual model)
- SMS deduplication fingerprint uses unstable `hashCode` — different matches per restart

### Exact changes

**`ui/settings_screen.dart:620-626` — PIN recovery double-pop**
- Wrap `RecoveryCodeSaveScreen` push in a `WillPopScope` that shows "Are you sure? PIN is already saved" before popping
- On `RecoveryCodeSaveScreen`, replace bare `Navigator.pop()` with `Navigator.of(context, rootNavigator: false).pop(true)` (returns success)
- Parent checks result: if `true`, show "PIN setup complete" toast

**`ui/notifications_page.dart:369-385` — mounted check order**
```dart
// Replace:
Navigator.of(context).push(...);
if (!context.mounted) return;
// With:
if (!context.mounted) return;
Navigator.of(context).push(...);
```

**`ui/manage/goals/goals_screen.dart:425` — expiring banner tap**
```dart
onPressed: () {
  // Scroll to first expiring goal in list
  final idx = _sortedGoals.indexWhere((g) => g.daysUntilDeadline <= 30);
  if (idx >= 0) _scrollController.animateTo(idx * 120.0, ...);
}
```

**`ui/manage/loans/loan_tracker_screen.dart:232-253` — unify interaction model**
- Remove long-press action sheet
- Add "⋮" (more) `CupertinoButton` in the loan detail sheet header → opens action sheet with Edit/Delete
- Tap = detail sheet only (consistent with other screens)

**`services/sms_auto_scan_service.dart:312-316` — stable fingerprint**
```dart
// Replace:
final fingerprint = '${p.amount.toStringAsFixed(0)}_${p.date.day}${p.date.month}${p.date.year}_${p.sender.hashCode.abs()}';
// With:
final senderKey = p.sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').substring(0, math.min(8, p.sender.length));
final fingerprint = '${p.amount.toStringAsFixed(0)}_${p.date.day}${p.date.month}${p.date.year}_$senderKey';
```

### Files touched
- `ui/settings_screen.dart`
- `ui/recovery_code_save_screen.dart`
- `ui/notifications_page.dart`
- `ui/manage/goals/goals_screen.dart`
- `ui/manage/loans/loan_tracker_screen.dart`
- `services/sms_auto_scan_service.dart`

---

# ── TIER 3: P2 IMPORTANT IMPROVEMENTS ────────────────────────────────────────

---

## BATCH 12 — State Refresh (stale detail screens)
**Status:** `[x]` Done — already implemented (Consumer wrapping, snapshot throttle already in place)
**Complexity:** 🟡 Medium
**Issues:** REF-01 through REF-05

### What's broken
Users add a contribution to a goal → close modal → goal detail screen still shows old progress. Same for budget spending breakdown, contact lending totals, net worth snapshot saving on every rebuild.

### Exact changes

**`ui/manage/goals/goal_details_screen.dart`**
```dart
// After showing add contribution modal:
final result = await showCupertinoModalPopup(...AddContributionModal...);
if (result == true && mounted) setState(() {}); // trigger rebuild with new data
```

**`ui/manage/budgets/budget_details_screen.dart`**
- Add `Consumer<TransactionsController>` around spending breakdown section
- Spending breakdown recalculates automatically when transactions change

**`ui/manage/contacts_screen.dart` (person detail sheet)**
- Wrap lending/borrowing section in `Consumer<LendingBorrowingController>`
- Totals auto-update when records change

**`ui/manage/goals/goals_screen.dart:77` — expiring banner timer**
```dart
// Add to State:
late Timer _refreshTimer;
@override void initState() {
  super.initState();
  _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) { if (mounted) setState(() {}); });
}
@override void dispose() { _refreshTimer.cancel(); super.dispose(); }
```

**`ui/net_worth_page.dart:445-446` — snapshot throttle**
```dart
bool _snapshotSavedThisSession = false;
// In addPostFrameCallback:
if (!_snapshotSavedThisSession) {
  _snapshotSavedThisSession = true;
  _maybeSaveSnapshot();
}
```

### Files touched
- `ui/manage/goals/goal_details_screen.dart`
- `ui/manage/budgets/budget_details_screen.dart`
- `ui/manage/contacts_screen.dart`
- `ui/manage/goals/goals_screen.dart`
- `ui/net_worth_page.dart`

---

## BATCH 13 — Performance Fixes
**Status:** `[x]` Done — committed
**Complexity:** 🟡 Medium
**Issues:** PERF-01 through PERF-06

### What's broken
`Consumer4` on notifications page rebuilds entire page (including expensive aggregations) whenever any controller changes. Liquid progress indicator recalculates wave path for every pixel on every frame — expensive on 120Hz displays. Debounce timer in global search leaks.

### Exact changes

**`ui/notifications_page.dart` — split Consumer4**
- Extract each notification section into its own private widget with its own specific `Consumer`
- `_BudgetAlerts` widget: Consumer<BudgetsController>
- `_FDAlerts` widget: Consumer<InvestmentsController>
- `_InsightAlerts` widget: Consumer<TransactionsController>
- Parent screen: no Consumer needed at top level

**`ui/widgets/liquid_progress_indicators.dart:114-122` — wave path cache**
```dart
// Cache the wave path, only recalculate when size changes:
Path? _cachedPath;
Size? _lastSize;
Path _getWavePath(Size size, double phase) {
  if (_cachedPath != null && _lastSize == size) {
    // Apply phase offset via matrix transform instead of recalculating
    return _cachedPath!.transform(Matrix4.translationValues(-phase, 0, 0).storage);
  }
  _lastSize = size;
  _cachedPath = _buildWavePath(size);
  return _cachedPath!;
}
```

**`ui/widgets/global_search_overlay.dart:132` — debounce fix**
```dart
// Add field: Timer? _debounce;
// In onChanged:
_debounce?.cancel();
_debounce = Timer(const Duration(milliseconds: 200), () { _performSearch(query); });
// In dispose: _debounce?.cancel();
```

**`ui/widgets/common_widgets.dart:348` — SkeletonLoader physics**
```dart
// Add to shrinkWrap ListView:
physics: const NeverScrollableScrollPhysics(),
```

**`ui/dashboard/widgets/net_worth_widget.dart:320-333` — carousel timer lifecycle**
```dart
// Add WidgetsBindingObserver to State
// In didChangeAppLifecycleState:
if (state == AppLifecycleState.paused) _carouselTimer?.cancel();
if (state == AppLifecycleState.resumed) _startCarouselTimer();
```

**`ui/manage/reports_analysis_screen.dart` — compute isolate**
- Wrap heavy aggregation in `await compute(_aggregateReports, inputData)` to move off main thread

### Files touched
- `ui/notifications_page.dart`
- `ui/widgets/liquid_progress_indicators.dart`
- `ui/widgets/global_search_overlay.dart`
- `ui/widgets/common_widgets.dart`
- `ui/dashboard/widgets/net_worth_widget.dart`
- `ui/manage/reports_analysis_screen.dart`

---

## BATCH 14 — Wizard Quality & Edit Flows
**Status:** `[x]` Done — committed (partial: GST clamp; edit pre-pop + stock qty already handled by UI; bond dead code deferred)
**Complexity:** 🟡 Medium
**Issues:** WIZ-01 through WIZ-08, INV-04, INV-08, INV-09, INV-10, INV-11

### What's broken
Edit mode doesn't pre-populate fields. Review step shows "24 months" when user entered "2 years". Stock qty allows 100.5 (stocks are whole units). MF type change mid-wizard causes PageController to jump. Dual bond wizard controllers (dead code). No mid-tenure RD withdrawal.

### Exact changes

**`ui/manage/simple_investment_entry_wizard.dart:160-194` — edit pre-population**
```dart
// In initState, if existingInvestment != null:
_nameController.text = existingInvestment!.name;
_amountController.text = existingInvestment!.amount.toString();
_linkedAccount = accountsCtrl.accounts.firstWhereOrNull((a) => a.id == existingInvestment!.metadata?['linkedAccountId']);
// etc. for all editable fields
```

**`ui/manage/fd/steps/review_step.dart:121-161` — display in user's unit**
```dart
// Store original unit in controller: enum TenureUnit { days, months, years }
// In review step:
Text(controller.tenureUnit == TenureUnit.years
    ? '${controller.tenureYears} years'
    : '${controller.tenureMonths} months')
```

**`ui/manage/stocks/steps/stock_review_step.dart:61-86` — integer quantity**
```dart
// Display qty rounded:
Text('${controller.qty.toInt()} shares')
// Also add validation: controller.qty must be >= 1 (no fractional shares)
```

**`ui/manage/mf/mf_wizard.dart:231-237` — type change reinitialises PageController**
```dart
// In controller, on type change:
void updateMFType(MFType type) {
  mfType = type;
  notifyListeners();
}
// In wizard screen, rebuild PageController when type changes:
// Use key on PageView that includes mfType, so Flutter rebuilds PageController
```

**`ui/manage/bonds/bonds_wizard_controller_v2.dart` — remove dead code**
- Determine which controller is actually used (grep for instantiation)
- Delete the unused one

**`ui/manage/rd/` — add mid-tenure withdrawal**
- Add `RDWithdrawalModal` (similar to existing `FDWithdrawalModal`)
- Shows: amount invested so far, penalty % (configurable), final payout
- On confirm: close RD, credit net payout to linked account, mark RD as `withdrawn`

**`ui/manage/mf/steps/mf_new_investment_details_step.dart:65-68` — manual NAV for past dates**
```dart
// If selected date is in past (> 1 day ago):
// Show: "NAV for past dates isn't available automatically."
// Show NAV text field with label "Enter NAV on [selected date]"
// Disable auto-fetch button for past dates
```

**`ui/manage/mf/mf_wizard_controller.dart:183-200` — refetch NAV on date change**
```dart
void updateInvestmentDate(DateTime date) {
  investmentDate = date;
  if (!date.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
    fetchCurrentNAV(); // only refetch for recent dates
  }
  notifyListeners();
}
```

**Digital gold GST bounds (`ui/manage/digital_gold/digital_gold_wizard_controller.dart:31-47`)**
```dart
void updateGSTRate(double rate) {
  gstRate = rate.clamp(0.0, 28.0); // GST max 28% in India
  notifyListeners();
}
```

**NPS gain% bounds (`ui/manage/nps/nps_wizard_controller.dart:35-43`)**
```dart
double get gainLossPercent {
  if (totalContributed == null || totalContributed! <= 0) return 0.0;
  final raw = ((estimatedReturns ?? 0) / totalContributed!) * 100;
  return raw.clamp(-100.0, 10000.0); // cap at 10000% to avoid display issues
}
```

### Files touched
- `ui/manage/simple_investment_entry_wizard.dart`
- `ui/manage/fd/steps/review_step.dart`
- `ui/manage/fd/fd_wizard_controller.dart`
- `ui/manage/stocks/steps/stock_review_step.dart`
- `ui/manage/mf/mf_wizard.dart`
- `ui/manage/mf/mf_wizard_controller.dart`
- `ui/manage/mf/steps/mf_new_investment_details_step.dart`
- `ui/manage/bonds/bonds_wizard_controller_v2.dart` (delete)
- `ui/manage/rd/modals/rd_withdrawal_modal.dart` (new)
- `ui/manage/digital_gold/digital_gold_wizard_controller.dart`
- `ui/manage/nps/nps_wizard_controller.dart`

---

## BATCH 15 — Services & Data Quality
**Status:** `[x]` Done — committed
**Complexity:** 🟡 Medium
**Issues:** SVC-01 through SVC-10, CALC-11 (XIRR) already in Batch 10

### What's broken
NAV fallback HTTP call has no timeout. AMFI parse errors swallowed silently. MF DB marks itself initialized even on failure. Yahoo Finance endpoint hardcoded without versioning. Orphaned records can't be cleaned up from UI. Balance-only SMS dropped. Merchant normalizer breaks on "McDonald's". ID generator not unique across restarts.

### Exact changes

**`services/nav_service.dart:39-40,51` — timeout**
```dart
// Wrap fallback call:
await http.get(fallbackUri).timeout(const Duration(seconds: 8));
```

**`services/amfi_data_service.dart:29-49` — surface parse failures**
```dart
// After parsing:
final failRate = failCount / totalLines;
if (failRate > 0.5) debugPrint('[AMFI] WARNING: ${(failRate*100).round()}% of lines failed to parse');
// Expose _lastParseSuccessRate getter for debug panel
```

**`services/mf_database_service.dart:60-61` — init failure**
```dart
// Replace: _isInitialized = true (always)
// With:
try {
  await _fetchAndStoreAMFIData();
  _isInitialized = true;
} catch (e) {
  _isInitialized = false; // stays false
  _initError = e.toString();
  notifyListeners();
}
```

**`services/stock_api_service.dart:37,68` — configurable endpoint**
```dart
// Move to config:
static const _yahooBaseUrl = AppConfig.yahooFinanceBaseUrl; // 'https://query1.finance.yahoo.com/v8/finance'
// Add fallback:
static const _yahooFallbackUrl = 'https://query2.finance.yahoo.com/v8/finance';
```

**`services/integrity_check_service.dart`**
- Add `Future<int> cleanupOrphanedTransactions()` that deletes records with missing accountId
- Expose via Settings screen → "Data Health" → "Fix orphaned records (N found)"

**`services/sms_parser.dart:332-377` — balance SMS**
```dart
// Add separate path: if no txn amount found but balance amount found:
if (txnAmount == null && balanceAmount != null) {
  return ParsedTransaction(type: SmsType.balance, amount: balanceAmount, ...);
}
```

**`utils/merchant_normalizer.dart:27-34`**
```dart
// Replace space-only split with:
final words = raw.split(RegExp(r"[\s\-–]+"));
// Preserve apostrophes in caps: "McDonald's" → "McDonald's" not "Mcdonalds"
```

**`utils/id_generator.dart:12-15`**
```dart
// Persist sequence counter:
static int _sequence = 0;
static const _seqKey = 'id_gen_sequence';
static Future<void> init() async {
  final prefs = await SharedPreferences.getInstance();
  _sequence = prefs.getInt(_seqKey) ?? 0;
}
static String generate() {
  _sequence = (_sequence + 1) % 1000000;
  SharedPreferences.getInstance().then((p) => p.setInt(_seqKey, _sequence)); // fire-and-forget ok here
  return 'id_${DateTime.now().microsecondsSinceEpoch}_$_sequence';
}
```

**`services/gold_price_service.dart` — staleness label**
- Add `DateTime? lastFetchedAt` field
- UI reads this and shows "as of 2:30 PM" in gold value display

**`logic/backup_restore_service.dart:_reloadAllControllers()`**
```dart
// Wrap each controller load:
for (final load in [txCtrl.load, acctCtrl.load, ...]) {
  try { await load(); } catch (e) { failedControllers.add(e.toString()); }
}
if (failedControllers.isNotEmpty) showError('Some data may not have loaded: ${failedControllers.join(', ')}');
```

### Files touched
- `services/nav_service.dart`
- `services/amfi_data_service.dart`
- `services/mf_database_service.dart`
- `services/stock_api_service.dart`
- `services/integrity_check_service.dart`
- `services/sms_parser.dart`
- `utils/merchant_normalizer.dart`
- `utils/id_generator.dart`
- `services/gold_price_service.dart`
- `logic/backup_restore_service.dart`
- `ui/settings_screen.dart` (add Data Health section)

---

## BATCH 16 — Model Completeness (missing fields)
**Status:** `[x]` Done — committed (partial: elapsedFraction + usagePercentage guards; schema additions deferred)
**Complexity:** 🔴 Hard (schema change — must add DB migration from Batch 6)
**Issues:** MDL-20 through MDL-28
**Depends on:** Batch 6 (DB migration infrastructure must exist first)

### What's broken
No `modifiedDate` on any model — can't tell when data changed. No soft-delete — hard deletes break undo and history. Goal contributions not linked to actual transactions. Loan has no payment history. Investment model has no `createdDate`.

### Exact changes

**Add `modifiedDate` to core models** (Transaction, Account, Investment, Budget, Loan, Goal):
```dart
// Add field:
final DateTime? modifiedDate;
// In toMap(): 'modifiedDate': modifiedDate?.millisecondsSinceEpoch
// In fromMap(): modifiedDate: map['modifiedDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['modifiedDate']) : null
// In copyWith(): set modifiedDate: DateTime.now() on every update
```

**Add `isDeleted` + `deletedAt` to Transaction, Account, Goal, Investment, Loan, Contact:**
```dart
final bool isDeleted;
final DateTime? deletedAt;
// All list queries: add .where((x) => !x.isDeleted) filter
// Delete operations: set isDeleted=true, deletedAt=now instead of removing
```

**`logic/goal_model.dart` — link contributions to transactions:**
```dart
class GoalContribution {
  final String id;
  final double amount;
  final DateTime date;
  final String? transactionId; // ADD THIS
  // ...
}
```

**`logic/loan_model.dart` — payment history:**
```dart
class LoanPayment {
  final String id;
  final double amount;
  final DateTime date;
  final bool wasOnTime;
}
// Add to LoanModel:
final List<LoanPayment> paymentHistory;
```

**`logic/fixed_deposit_model.dart:186` — clamp elapsedFraction**
```dart
double get elapsedFraction => (elapsedMonths / tenureMonths).clamp(0.0, 1.0);
```

**`logic/budget_model.dart:56` — cap usagePercentage**
```dart
double get usagePercentage => limitAmount > 0 ? (spentAmount / limitAmount).clamp(0.0, 9.99) : 0.0;
```

**`logic/mutual_fund_model.dart:49` — nav default**
```dart
final double nav; // change from double? to double with default 0.0
final bool isNavStale; // add: true if nav was never fetched
```

### Files touched (schema-changing):
`logic/transaction_model.dart`, `logic/account_model.dart`, `logic/investment_model.dart`, `logic/budget_model.dart`, `logic/loan_model.dart`, `logic/goal_model.dart`, `logic/fixed_deposit_model.dart`, `logic/budget_model.dart`, `models/mutual_fund_model.dart`
Plus all corresponding controllers for query filter updates.

---

# ── TIER 4: P3 POLISH ─────────────────────────────────────────────────────────

---

## BATCH 17 — Empty States & UX Polish
**Status:** `[x]` Done — committed
**Complexity:** 🟢 Easy
**Issues:** EMPTY-01 through EMPTY-04, UX-01 through UX-07

### Exact changes

**`ui/notifications_page.dart`** — Empty state:
```dart
// If all notification lists empty:
Center(child: Column(children: [
  Icon(CupertinoIcons.checkmark_circle, size: 48, color: AppStyles.gain(context)),
  Text('You\'re all caught up', style: AppStyles.titleStyle(context)),
  Text('No alerts or notifications right now', style: ...secondary...),
]))
```

**`ui/dashboard/widgets/budget_widget.dart`** — Budget empty spend:
- Show "No spending yet this period" with category name when spend = 0

**`ui/manage/categories_screen.dart`** — Search empty state CTA:
```dart
// If query.isNotEmpty and results.isEmpty:
CupertinoButton(child: Text("Create '$query'"), onPressed: () => _showCreateModal(prefill: query))
```

**`ui/manage/goals/goal_details_screen.dart`** — Not found back button:
```dart
// In empty state: add CupertinoButton('Back', onPressed: () => Navigator.of(context).pop())
```

**UX-01 — Budget bars tappable:**
```dart
// Wrap each budget bar in GestureDetector:
onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => BudgetDetailsScreen(budget: budget)))
```

**UX-02 — Transaction list item press feedback:**
- Wrap transaction items in `GestureDetector` with `onTapDown/Up` that toggles `_isPressed` → `Opacity(opacity: _isPressed ? 0.6 : 1.0, child: ...)`

**UX-03 — Health score 90+ celebration:**
```dart
if (data.score >= 90) {
  // Show: green ring + "Excellent!" label + "Your finances are in great shape"
  // Trigger confetti animation (reuse existing confetti from goals)
}
```

**UX-05 — Switch haptic:**
```dart
onChanged: (val) {
  HapticFeedback.selectionClick();
  controller.toggle(val);
}
```

**UX-06 — Transaction filter chip highlight:**
```dart
// Each type chip:
isSelected: _typeFilter == TransactionType.expense,
// Selected chips: use accentTeal background
```

**UX-07 — Scroll threshold responsive:**
```dart
final threshold = MediaQuery.of(context).size.height * 0.4;
if (_scrollController.offset > threshold) { /* show scroll-to-top */ }
```

### Files touched
- `ui/notifications_page.dart`
- `ui/dashboard/widgets/budget_widget.dart`
- `ui/manage/categories_screen.dart`
- `ui/manage/goals/goal_details_screen.dart`
- `ui/transaction_history_screen.dart`
- `ui/dashboard/widgets/health_score_widget.dart`
- `ui/dashboard/widgets/transaction_history_widget.dart`

---

## BATCH 18 — Animation Polish
**Status:** `[ ]` Approve · `[ ]` Skip
**Complexity:** 🟢 Easy
**Issues:** ANIM-01 through ANIM-04

### Exact changes

**`ui/dashboard/widgets/health_score_widget.dart` — don't re-animate on rebuild**
```dart
// Use AnimationController with addStatusListener:
// Only trigger animation once (on first build), not on every setState
// Use ValueKey or _hasAnimated flag
bool _hasAnimated = false;
@override void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!_hasAnimated) { _hasAnimated = true; _controller.forward(); }
  });
}
```

**`ui/dashboard/widgets/net_worth_widget.dart` — cheaper dot indicators**
```dart
// Replace AnimatedContainer (size animation) with AnimatedOpacity:
AnimatedOpacity(
  opacity: _currentPage == i ? 1.0 : 0.3,
  duration: const Duration(milliseconds: 200),
  child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: ...)),
)
```

**`ui/widgets/animations.dart:178-180` — smooth staggered fade**
```dart
// Wrap each child in CurvedAnimation with Interval:
// child 0: interval 0.0–0.5, child 1: 0.1–0.6, child 2: 0.2–0.7 etc.
// Use Curves.easeOutCubic instead of default (prevents the "pop")
```

**`ui/widgets/card_deck_view.dart:71-72` — animation sequencing**
```dart
// Wait for promotion animation before resetting swipe:
_promotionController.forward().then((_) {
  if (mounted) {
    _swipeController.reset();
    setState(() { _isDragging = false; });
  }
});
```

### Files touched
- `ui/dashboard/widgets/health_score_widget.dart`
- `ui/dashboard/widgets/net_worth_widget.dart`
- `ui/widgets/animations.dart`
- `ui/widgets/card_deck_view.dart`

---

## BATCH 19 — Formatting & Error Handling Edge Cases
**Status:** `[ ]` Approve · `[ ]` Skip
**Complexity:** 🟢 Easy
**Issues:** FMT-01 through FMT-04, ERR-01 through ERR-05

### Exact changes

**FMT-02 — transaction description fallback:**
```dart
// In Transaction.fromMap():
description: (map['description'] as String?)?.trim().isNotEmpty == true
    ? map['description']
    : (map['categoryName'] as String?) ?? 'Transaction'
```

**FMT-03 — CSV injection prevention:**
```dart
// In transaction_export_service.dart, before writing any string cell:
String safeCsvCell(String value) {
  if (value.startsWith(RegExp(r'[=+\-@]'))) return "'$value";
  return value;
}
```

**FMT-04 — metadata toString guard:**
```dart
// In export, when reading metadata fields:
final merchant = switch (meta['merchant']) {
  String s => s,
  List l => l.join(', '),
  _ => meta['merchant']?.toString() ?? '',
};
```

**ERR-02 — user error mapper completeness:**
```dart
// Add to userErrorMapper:
if (e is UnsupportedError) return 'Operation not supported on this device';
if (e is PlatformException) return 'Platform error: ${e.message}';
```

**ERR-03 — remote config silent failure:**
```dart
// Add log:
debugPrint('[RemoteConfig] Failed to load config: $e. Using defaults.');
```

**ERR-04 — CSV import: quoted newlines:**
- Replace hand-rolled CSV parser with `csv` package (already may be in pubspec — check)
- Or implement proper state-machine parser that handles `"field with\nnewline"` correctly

### Files touched
- `logic/transaction_model.dart`
- `services/transaction_export_service.dart`
- `utils/user_error_mapper.dart`
- `services/remote_config_service.dart`
- `ui/settings/csv_import_screen.dart`

---

## BATCH 20 — Missing Small Features
**Status:** `[ ]` Approve · `[ ]` Skip
**Complexity:** 🟢 Easy
**Issues:** FEAT-01 through FEAT-05, SVC-05 (integrity UI)

### Exact changes

**FEAT-01 — search recent dedup:**
```dart
// Before saving to SharedPreferences:
final existing = prefs.getStringList('recent_searches') ?? [];
existing.remove(query); // remove if exists (dedup)
existing.insert(0, query); // add to front
prefs.setStringList('recent_searches', existing.take(10).toList());
```

**FEAT-02 — backup restore via file picker:**
```dart
// In backup_restore_screen.dart, replace paste-JSON with:
final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'vfos']);
if (result != null) {
  final content = await File(result.files.single.path!).readAsString();
  await backupCtrl.restoreFromJson(content);
}
```

**FEAT-03 — SIP in MF review step:**
```dart
// In mf_review_step.dart, if controller.sipActive:
_buildReviewRow('SIP Amount', '₹${controller.sipAmount?.toStringAsFixed(0) ?? 'N/A'}'),
_buildReviewRow('SIP Frequency', controller.sipFrequency?.name ?? 'N/A'),
_buildReviewRow('SIP Start Date', DateFormatter.format(controller.sipStartDate)),
```

**FEAT-04 — NPS retirement age validation:**
```dart
// In nps_wizard_controller.dart:
void updateRetirementDate(DateTime date) {
  if (date.isBefore(DateTime.now().add(const Duration(days: 365 * 5)))) {
    retirementDateError = 'Retirement date must be at least 5 years in the future';
  } else {
    retirementDateError = null;
  }
  plannedRetirementDate = date;
  notifyListeners();
}
```

**FEAT-05 — Data Integrity in Settings:**
```dart
// In settings_screen.dart, add "Data Health" row:
// Tap → runs IntegrityCheckService.runCheck()
// Shows: "5 orphaned transactions found" with [Fix] button
// Fix calls: integrityCtrl.cleanupOrphanedTransactions()
```

### Files touched
- `ui/widgets/global_search_overlay.dart`
- `ui/backup_restore_screen.dart`
- `ui/manage/mf/steps/mf_review_step.dart`
- `ui/manage/nps/nps_wizard_controller.dart`
- `ui/settings_screen.dart`
- `services/integrity_check_service.dart`

---

# SUMMARY DASHBOARD

| Batch | Priority | Issues | Complexity | Files | Status |
|-------|----------|--------|------------|-------|--------|
| 1 — Security | P0 | SEC-01→04 | 🔴 Hard | 3 | `[ ]` |
| 2 — Async lifecycle | P0 | ASYNC-01→05 | 🟢 Easy | 5 | `[ ]` |
| 3 — Save reliability | P0 | SAVE-01→08 | 🟢 Easy | 8 | `[ ]` |
| 4 — Model type safety | P0 | MDL-01→08 | 🟡 Medium | 17 | `[ ]` |
| 5 — Calc crashes | P0 | CALC-01→05 | 🟢 Easy | 5 | `[ ]` |
| 6 — DB migration | P0 | DB-01,03,04 | 🔴 Hard | 6 | `[ ]` |
| 7 — Investment money flow | P1 | INV-01→14 | 🔴 Hard | 9 | `[ ]` |
| 8 — CRUD cascade | P1 | CRUD-01→08 | 🟡 Medium | 6 | `[ ]` |
| 9 — Wizard validation | P1 | VAL-01→09 | 🟡 Medium | 9 | `[ ]` |
| 10 — Calculation correctness | P1 | CALC-10→18 | 🟡 Medium | 9 | `[ ]` |
| 11 — Nav & UI state | P1 | NAV-01→08 | 🟡 Medium | 6 | `[ ]` |
| 12 — State refresh | P2 | REF-01→05 | 🟡 Medium | 5 | `[ ]` |
| 13 — Performance | P2 | PERF-01→06 | 🟡 Medium | 6 | `[ ]` |
| 14 — Wizard quality | P2 | WIZ-01→08 | 🟡 Medium | 11 | `[ ]` |
| 15 — Services | P2 | SVC-01→10 | 🟡 Medium | 11 | `[ ]` |
| 16 — Model completeness | P2 | MDL-20→28 | 🔴 Hard | 10 | `[ ]` |
| 17 — Empty states & UX | P3 | EMPTY+UX | 🟢 Easy | 7 | `[ ]` |
| 18 — Animations | P3 | ANIM-01→04 | 🟢 Easy | 4 | `[ ]` |
| 19 — Formatting & errors | P3 | FMT+ERR | 🟢 Easy | 5 | `[ ]` |
| 20 — Missing features | P3 | FEAT-01→05 | 🟢 Easy | 6 | `[ ]` |

**Total: 20 batches · ~294 issues · ~138 files touched**

---

## NOTES
- Batches 1–6 (P0) should be done FIRST, in order. Do not skip any.
- Batch 7 (investment money flow) requires Batch 3 (save reliability) to be done first.
- Batch 16 (model completeness) requires Batch 6 (DB migration) to be done first.
- Every batch ends with: `flutter analyze`, `git commit`, `flutter build apk --release`.
- Uncommitted changes from last session (spending insights expandable, DOW heatmap, card deck): **commit first before starting Batch 1**.
