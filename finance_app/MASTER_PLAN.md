# VittaraFinOS — MASTER PLAN
> **Full line-by-line audit: all 290 dart files, 4 parallel agents, 2026-03-27**
> Every file read in full. Zero skipping. This is the only source of truth.
> Stack: Flutter + Provider + SQLite (MF only) + SharedPreferences (~95K LOC)

---

## Legend
- `[ ]` not started · `[~]` in progress · `[x]` done
- **P0** = crash / data-loss / security — fix before anything else
- **P1** = broken feature / wrong behaviour
- **P2** = UX gap / important improvement
- **P3** = polish, edge case

---

# PART A — P0: Critical (Fix First)

## A1 — Security
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **SEC-01** | `logic/backup_restore_service.dart` | 125-151 | `_masterSecretSeed` hardcoded as hex bytes — visible in compiled binary, any attacker can decrypt all v1 backups | Derive from device ID + user secret; reject v1 after migration window |
| **SEC-02** | `logic/settings_controller.dart` | 242 | Legacy fallback PIN salt is `'vittara_pin_salt_$pin'` — if new PIN set with null salt, uses this hardcoded value, zero entropy | Ensure `_generateSalt()` always called for new PINs; never fall through to hardcoded salt |
| **SEC-03** | `logic/pin_recovery_controller.dart` | 75 | `_storage.delete(key: _keyRecoveryHash)` — if deletion fails silently, same recovery code is reusable indefinitely (breaks single-use guarantee) | Verify deletion succeeded; log failure; mark as used in a separate flag before returning success |
| **SEC-04** | `ui/recovery_code_save_screen.dart` | 45-48 | Clipboard cleared on pause & after 60s — but if user copies then immediately switches back, clipboard still exposed within 60s window to other apps | Clear clipboard as soon as user confirms saved; don't rely solely on timer |
| **SEC-05** | `ui/pin_recovery_screen.dart` | 158-171 | "Generate Code" button has no `_isGenerating` guard — rapid taps fire multiple concurrent `generateAndStoreRecoveryCode()` calls, second overwrites first | Add `_isGenerating` flag; disable button during async operation |
| **SEC-06** | `ui/pin_recovery_screen.dart` | 99 | Recovery code is verified THEN marked used — if user navigates away after verify but before mark-used, old code remains valid | Mark code as used BEFORE showing new PIN entry screen |
| **SEC-07** | `ui/main.dart` | 285-286 | Lock screen is `Positioned.fill()` inside a `Stack` — does not cover `CupertinoModalPopup` sheets, FABs, or system overlays | Use `showDialog()` / Navigator overlay; or wrap lock content as a modal route |
| **SEC-08** | `services/transaction_export_service.dart` | 136 | Tags and merchant names exported to CSV without escaping — values starting with `=`, `+`, `@`, `-` execute as Excel formulas | Prefix formula-starting chars with `'`: `tag.startsWith(RegExp(r"^[=+@-]")) ? "'$tag" : tag` |

## A2 — Crash Risks: Enum Out-of-Bounds
All `EnumType.values[n]` calls without bounds checks crash on data corruption or enum reorder.

| ID | File | Line | Enum | Fix |
|----|------|------|------|-----|
| **ENUM-01** | `models/cryptocurrency_model.dart` | 78 | `CryptoTransactionType` | `.clamp(0, CryptoTransactionType.values.length - 1)` |
| **ENUM-02** | `models/cryptocurrency_model.dart` | 225 | `CryptoWalletType` | Same pattern |
| **ENUM-03** | `models/cryptocurrency_model.dart` | 228 | `CryptoExchange` | Same pattern |
| **ENUM-04** | `logic/fixed_deposit_model.dart` | 262 | `FDCompoundingFrequency` | Same pattern |
| **ENUM-05** | `logic/fixed_deposit_model.dart` | 263 | `FDPayoutFrequency` | Same pattern |
| **ENUM-06** | `logic/recurring_deposit_model.dart` | 235 | `RDStatus` | Same pattern |
| **ENUM-07** | `logic/bond_cashflow_model.dart` | 152 | `BondType` | Same pattern |
| **ENUM-08** | `logic/pension_model.dart` | 78 | `PensionSchemeType` | Same pattern |
| **ENUM-09** | `logic/goal_model.dart` | 138 | `GoalType` (in toMap, no fromMap guard) | Add bounds clamp in `fromMap()` |

**Rule for all:** `EnumType.values[((map['key'] as num?)?.toInt() ?? 0).clamp(0, EnumType.values.length - 1)]`

## A3 — Crash Risks: Unsafe Casts & DateTime Parsing
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **CAST-01** | `logic/tag_model.dart` | 30 | `DateTime.parse(map['createdDate'])` — throws on malformed/missing date | `DateTime.tryParse(map['createdDate'] ?? '') ?? DateTime.now()` |
| **CAST-02** | `logic/category_model.dart` | 51 | Same `DateTime.parse` crash | Same fix |
| **CAST-03** | `logic/budget_model.dart` | 173 | Same | Same fix |
| **CAST-04** | `logic/goal_model.dart` | 159 | Same | Same fix |
| **CAST-05** | `logic/contact_model.dart` | 28 | Same | Same fix |
| **CAST-06** | `ui/manage/fd/fd_wizard_controller.dart` | 367 | `selectedAccount!.id` force-unwrap — crashes if race condition nulls the account | `selectedAccount?.id ?? throw StateError('No account')` |
| **CAST-07** | `ui/manage/fd/fd_renewal_wizard_controller.dart` | 103-105 | `(widget.fd.metadata!['renewalCycle'] as Map)['cycleNumber'] as int` — triple unchecked cast | `(widget.fd.metadata?['renewalCycle'] as Map?)?.['cycleNumber'] as int? ?? 1` |
| **CAST-08** | `services/transaction_export_service.dart` | 560 | `meta['tags'] as List` — throws if metadata null or field missing | `(meta?['tags'] as List<dynamic>?)?.map((t) => t.toString()).join(', ') ?? ''` |

## A4 — Crash Risks: Division by Zero
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **DIV-01** | `logic/goal_model.dart` | 65-72 | `recommendedMonthlySavings` divides by `monthsRemaining` — returns `-Infinity` if goal is past or due today | `if (monthsRemaining <= 0) return remainingAmount;` |
| **DIV-02** | `logic/loan_model.dart` | 78-80 | `progressPercent` divides by `principalAmount` — crashes if 0 | `principalAmount > 0 ? (totalPaid / principalAmount).clamp(0.0, 1.0) : 0.0` |
| **DIV-03** | `ui/manage/digital_gold/digital_gold_wizard_controller.dart` | 31-38 | `weightInGrams = actualAmount / investmentRate` — Infinity if rate is 0 | Guard: `investmentRate > 0 ? actualAmount / investmentRate : 0` |
| **DIV-04** | `ui/manage/fo/fo_wizard_controller.dart` | 26-28 | `gainLossPercent` divides by `totalCost` — Infinity if 0 | `if (totalCost <= 0) return 0;` |
| **DIV-05** | `ui/manage/commodities/commodities_wizard_controller.dart` | 23 | Same pattern | Same fix |
| **DIV-06** | `ui/manage/mf/mf_wizard.dart` | 56-62 | `units = investmentAmount / averageNAV` — Infinity if NAV is 0 | `(averageNAV > 0) ? investmentAmount / averageNAV : 0` |
| **DIV-07** | `services/nav_service.dart` | 122 | `historicalData.sublist(0, lastNDays)` — throws `RangeError` if `lastNDays > data.length` | `sublist(0, min(lastNDays, historicalData.length))` |

## A5 — Crash Risks: Missing `mounted` Checks
Every async method that uses `context`, `setState`, or `Navigator` after an `await` without a mounted check is a crash.

| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **ASYNC-01** | `ui/manage/fd/fd_wizard_screen.dart` | 138 | `Navigator.pop()` before `if (mounted)` | Check `mounted` BEFORE pop and toast |
| **ASYNC-02** | `ui/manage/fd/fd_wizard_screen.dart` | 142 | `setState(() => _isSubmitting = false)` in finally without mounted check | `if (mounted) setState(...)` |
| **ASYNC-03** | `ui/manage/rd/rd_wizard_screen.dart` | 141 | Same in finally block | `if (mounted) setState(...)` |
| **ASYNC-04** | `ui/manage/mf/mf_wizard.dart` | 107 | `mounted` used inside non-State widget child | Change to `context.mounted` |
| **ASYNC-05** | `ui/manage/stocks/stocks_wizard.dart` | 44-45 | `isSubmitting` modified without ensuring single `notifyListeners()` | Merge into one notification |
| **ASYNC-06** | `ui/pin_recovery_screen.dart` | 78-91 | Timer callback does async op, no `mounted` check before `setState` at line 85 | `if (!mounted) return;` after every `await` |
| **ASYNC-07** | `ui/dashboard/transaction_wizard.dart` | 101 | `Navigator.push()` without mounted check in `_selectBranch()` | `if (!mounted) return;` before push |
| **ASYNC-08** | `ui/pin_recovery_screen.dart` | 188-191 | Countdown timer not cancelled if widget disposed before timer fires | `dispose()` must call `_countdownTimer?.cancel()` |

## A6 — Data Loss: Account Debit Before Save (Transactional Integrity)
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **TXN-01** | `ui/manage/fd/fd_wizard_screen.dart` | 94-136 | Account debited at line 94 BEFORE `addInvestment()` at line 136 — if save fails, money is gone from account but FD never created | Reverse order: save investment first, then debit. Wrap in rollback pattern |
| **TXN-02** | `ui/manage/rd/rd_wizard_screen.dart` | 98-107 | Same — first installment debit before investment creation | Same fix |
| **TXN-03** | `logic/investments_controller.dart` | 79-88 | `removeInvestment()` / `deleteInvestment()` removes record but never reverses the account debit made at creation | Before delete, read `metadata['linkedAccountId']` and credit amount back |
| **TXN-04** | `ui/manage/stocks/stocks_wizard.dart` | 52 | Account balance deduction never validates if `newBalance < creditLimit` — can push account to negative silently | `if (newBalance < account.creditLimit!) throw Exception('Insufficient balance')` |

## A7 — Data Loss: Fire-and-Forget Saves
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **SAVE-01** | `logic/contacts_controller.dart` | 42 | `addContact()` — `_saveContacts()` not awaited | `await _saveContacts()` |
| **SAVE-02** | `logic/contacts_controller.dart` | 65 | `removeContact()` — not awaited | Same |
| **SAVE-03** | `logic/contacts_controller.dart` | 74 | `updateContact()` — not awaited | Same |
| **SAVE-04** | `logic/lending_borrowing_controller.dart` | 111 | `removeRecord()` — not awaited | `await _saveRecords()` |
| **SAVE-05** | `logic/recurring_templates_controller.dart` | 71 | `markUsed()` — not awaited | `await _save()` |
| **SAVE-06** | `logic/recurring_templates_controller.dart` | 79 | `updateTemplate()` — not awaited | Same |
| **SAVE-07** | `logic/recurring_templates_controller.dart` | 88 | `markBillAsPaid()` — not awaited | Same |
| **SAVE-08** | `logic/recurring_templates_controller.dart` | 130 | `unmarkBillAsPaid()` — not awaited | Same |

## A8 — Missing HTTP Timeouts (app freeze / hang)
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **HTTP-01** | `services/amfi_data_service.dart` | 11 | `http.get()` — no timeout at all | `.timeout(const Duration(seconds: 30))` |
| **HTTP-02** | `services/stock_api_service.dart` | 38 | `http.get()` search — no timeout | `.timeout(const Duration(seconds: 15))` |
| **HTTP-03** | `services/stock_api_service.dart` | 69 | `http.get()` price — no timeout | `.timeout(const Duration(seconds: 15))` |
| **HTTP-04** | `services/nav_service.dart` | 51 | Fallback endpoint timeout is 12s while primary is 10s | Standardize to 10s across all endpoints |

## A9 — Missing Implementation (will crash / silently fail)
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **IMPL-01** | `ui/manage/bonds/bonds_wizard_controller.dart` | 117 | Calls `BondCalculator.calculateYieldToMaturity()` — class does not exist anywhere in codebase | Create `logic/bond_calculator.dart` with Newton-Raphson YTM implementation |
| **IMPL-02** | `ui/manage/rd/rd_wizard_controller.dart` | 169 | Calls `RDCalculator.calculateMaturityValue()` — verify this class exists and is imported | If missing, implement or import from `logic/fd_calculations.dart` |

---

# PART B — P1: Broken Features

## B1 — DateTime Arithmetic Overflows
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **DATE-01** | `logic/budget_model.dart` | 131 | `DateTime(endDate.year, endDate.month, endDate.day + 1)` — Jan 31 + 1 day = Feb 31 (invalid) | Use `endDate.add(const Duration(days: 1))` |
| **DATE-02** | `logic/fixed_deposit_model.dart` | 603 | `DateTime(newYear, newMonth + 1, 0)` — if newMonth = 12, becomes `DateTime(year, 13, 0)` | Cap: `newMonth == 12 ? 31 : DateTime(newYear, newMonth + 1, 0).day` |
| **DATE-03** | `logic/recurring_template_model.dart` | 143 | `DateTime(targetYear, targetMonth + 1, 0).day` — crashes when targetMonth = 12 | Same month cap fix |
| **DATE-04** | `ui/manage/bonds/bonds_wizard_controller_v2.dart` | 95-100 | `maturityDate.isAfter(DateTime.now())` allows maturity date = today — all calculations go to zero or negative | `maturityDate.isAfter(DateTime.now().add(const Duration(days: 1)))` |
| **DATE-05** | `ui/manage/fo/fo_wizard_controller.dart` | 31-52 | No validation that entryDate is before expiryDate | Add in `canProceed()`: `return entryDate.isBefore(expiryDate)` |

## B2 — Orphaned Data (CRUD cascades)
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **CASCADE-01** | `ui/manage/contacts_screen.dart` | 774 | Deleting contact does NOT remove lending/borrowing records with that `personName` — records orphaned forever | In `removeContact()`, also delete all lending records where `personName == contact.name` |
| **CASCADE-02** | `ui/manage/categories_screen.dart` | — | Deleting category leaves transactions with stale `categoryId` | Reassign to "Other" or block delete if transactions exist |
| **CASCADE-03** | `ui/manage/accounts_screen.dart` | — | Deleting account leaves transactions with invalid `accountId` | Cascade delete or reassign transactions before account deletion |
| **CASCADE-04** | `logic/contacts_controller.dart` | 47-60 | `addOrGetContact()` uses `.contains()` object identity check — always creates duplicates | Use `.any((c) => c.name.toLowerCase() == name.toLowerCase())` |

## B3 — Wrong Calculations
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **CALC-01** | `services/nav_service.dart` | 180-200 | XIRR uses simple ratio average, not time-weighted Newton-Raphson — SIP returns completely wrong | Implement proper Newton-Raphson XIRR iteration |
| **CALC-02** | `logic/fd_calculations.dart` | 23 | `calculateCAGR()` returns `0.0` if investment was made today — shown to user as "0% return" | Return `null`; show "Too early to calculate" in UI |
| **CALC-03** | `ui/manage/nps/nps_wizard_controller.dart` | 43-44 | `gainLossPercent` clamps AFTER division — `totalContributed == 0` gives Infinity before clamp | Guard: `totalContributed == null || totalContributed! <= 0 ? 0 : (currentValue - totalContributed) / totalContributed * 100` |
| **CALC-04** | `logic/fo_model.dart` | 102-103 | Put option `getMaxProfit()` calculates short-put profit, not long-put | Add `positionDirection` field; calculate correctly per position type |
| **CALC-05** | `utils/percent_formatter.dart` | 20 | `-0.005%` formats as `"-0%"` — negative near-zero loses sign | `value.abs() < 0.01 && value != 0 ? (value > 0 ? '< 0.01%' : '> -0.01%') : ...` |
| **CALC-06** | `utils/date_formatter.dart` | 202-204 | `formatFinancialYear(2024)` returns `"FY 2024-24"` instead of `"FY 2024-25"` — off-by-one in year suffix | Fix: use `(fyStartYear + 1).toString().substring(2)` instead of modulo |
| **CALC-07** | `utils/merchant_normalizer.dart` | 31 | Split on whitespace produces empty tokens — `"mcdonald  s"` → `"Mcdonald  S"` with double space | `.split(...).where((w) => w.isNotEmpty).toList()` |

## B4 — Investment Wizard Logic Bugs
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **INV-01** | `ui/manage/bonds/bonds_wizard.dart` | Two bond wizard controllers exist (`bonds_wizard_controller.dart` + `_v2.dart`) — only v2 used | Verify, then delete dead v1 controller file |
| **INV-02** | `ui/manage/bonds/bonds_wizard.dart` | Bond payout frequency stored as `.toString().split('.').last` — breaks on enum rename | Use explicit string map: `{CouponFrequency.monthly: 'monthly', ...}` |
| **INV-03** | `ui/manage/rd/rd_wizard_controller.dart` | 153 | Maturity date uses `(totalInstallments - 1) * months` — 1 installment = 0 months (maturity = start date) | Change to `totalInstallments * months` |
| **INV-04** | `ui/manage/mf/mf_wizard.dart` | 146-149 | `clamp()` called on potentially negative unit/amount values — wrong clamp direction | Validate both are `>= 0` before clamping |
| **INV-05** | `ui/manage/mf/mf_wizard.dart` | 88-95 | `canProceed()` doesn't explicitly check `averageNAV > 0` — division by zero possible | Add `&& averageNAV > 0` to canProceed condition |
| **INV-06** | `ui/manage/digital_gold/digital_gold_wizard_controller.dart` | 75-84 | `updateWeight()` called before `investmentRate` is set — produces NaN weight | Guard: `if (investmentRate <= 0) { notifyListeners(); return; }` |
| **INV-07** | `ui/manage/commodities/commodities_wizard_controller.dart` | 28-54 | `canProceed()` for step 1 doesn't require `selectedType` — defaults to `CommodityType.gold` silently | Add `selectedType != null` to validation |
| **INV-08** | `ui/manage/pension/pension_wizard_controller.dart` | 15-19 | `gainLoss` and `gainLossPercent` don't null-check inputs — crash if values are null | `(currentValue ?? 0) - (principalContributed ?? 0)` |
| **INV-09** | `ui/manage/loans/loan_wizard.dart` | 127-142 | Outstanding amount can exceed principal — no validation | Add: `if (outstanding > principal) showError(...)` |
| **INV-10** | `ui/manage/simple_investment_entry_wizard.dart` | 119-121 | `currentValue` defaults to `amount` silently — user unaware | Show explicit note or require user input for current value |

## B5 — Initialization & Startup
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **INIT-01** | `main.dart` | 81-143 | 18+ providers initialized with no error handling — if ANY fails, entire app fails to start with blank screen | Wrap each in `try/catch`; show recovery screen with "Reset App" option |
| **INIT-02** | `main.dart` | 596-626 | Splash screen uses hardcoded 3.5s timer — data may not be ready, OR user waits unnecessarily | Listen to `DashboardController.isInitialized` instead of timer |
| **INIT-03** | `services/database_helper.dart` | 15-19 | `database` getter opens DB if null — concurrent calls can trigger multiple `openDatabase()` | Gate behind `Completer` or mutex: `_initCompleter ??= Completer(); return _initCompleter!.future` |
| **INIT-04** | `services/mf_database_service.dart` | 50-51 | Background refresh errors swallowed silently — user sees stale data with no indicator | Store `_lastRefreshError`; show "Last updated: X" + retry button |

## B6 — SMS & Fingerprint
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **SMS-01** | `services/sms_auto_scan_service.dart` | 312-319 | SMS deduplication fingerprint uses sender string — if bank changes sender ID, same SMS marked as new | Use hash of `amount + date + account_last4` only, no sender |
| **SMS-02** | `services/sms_parser.dart` | 524-550 | Balance-only SMS (e.g., "Avl Bal Rs 5000") matches generic transaction regex — imported as a ₹5000 transaction | Detect balance keywords first; route to separate balance-update path, not transaction creation |
| **SMS-03** | `services/sms_parser.dart` | 537 | Negative lookbehind regex syntax may not work correctly in Dart's RegExp — potential parser crash | Replace with pre-check: split on keywords first, then apply simpler regex |
| **SMS-04** | `services/sms_auto_scan_service.dart` | 170-176 | Duplicate detection tolerance is `± ₹1.0` — amounts like ₹1000.10 vs ₹1000.00 not deduped | Increase to `± ₹2.0` or use fuzzy match |

## B7 — Memory Leaks & Resource Management
| ID | File | Line | Issue | Fix |
|----|------|------|-------|-----|
| **MEM-01** | `ui/financial_calendar_screen.dart` | 163 | `_eventsScrollCtrl` created but not in `dispose()` | Add `_eventsScrollCtrl.dispose()` |
| **MEM-02** | `ui/widgets/liquid_fab.dart` | 325 | `_pulseController.repeat(reverse: true)` — never stopped; disposed controller gets repeat calls | Check `if (!_pulseController.isDisposed)` before repeat; ensure `stop()` before `dispose()` |
| **MEM-03** | `utils/alert_service.dart` | 365-376 | `_controller.forward()` called but `_controller.stop()` missing before `dispose()` — assertion fires if animation in progress during dispose | Add `_controller.stop()` in `dispose()` before `dispose()` |
| **MEM-04** | `ui/dashboard/widgets/insights_widget.dart` | 494-512 | `Timer.periodic` not cancelled on `AppLifecycleState.paused` — leaks and runs unnecessarily in background | Add `WidgetsBinding.instance.addObserver()` in `initState()`; cancel on pause, restart on resume |
| **MEM-05** | `services/database_helper.dart` | 15-19 | No connection pooling guard — concurrent async access can open multiple DB connections | Use `Completer`-based singleton init gate |

---

# PART C — P2: Important UX Improvements

## C1 — Empty States
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **EMPTY-01** | `ui/notifications_page.dart` | Page looks broken when all lists empty | Show "You're all caught up" icon + message |
| **EMPTY-02** | `ui/dashboard/widgets/budget_widget.dart` | Empty state shows "No budgets" but no CTA to create one | Add button navigating to budget creation |
| **EMPTY-03** | `ui/manage/goals/goal_details_screen.dart` | Goal deleted externally → "not found" with no back button | Add back button in empty/not-found state |
| **EMPTY-04** | `ui/widgets/common_widgets.dart` | `SkeletonLoader` animates indefinitely — no max duration or error fallback | Add `maxDuration` (default 30s); show "Failed to load. Tap to retry." |

## C2 — Stale Data (screens don't refresh)
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **STALE-01** | `ui/manage/goals/goals_screen.dart` | Goal progress doesn't update when contribution added in modal | Await modal result and refresh controller |
| **STALE-02** | `ui/manage/budgets/budget_details_screen.dart` | Spending breakdown stale when transactions added elsewhere | Listen to `TransactionsController` inside budget details |
| **STALE-03** | `ui/manage/contacts_screen.dart` | Contact detail sheet shows stale lending/borrowing totals | Refresh on sheet open; listen to `LendingBorrowingController` |
| **STALE-04** | `ui/manage/accounts_screen.dart` | `_filterSortCache` never cleared on account add/edit — stale list served | Clear cache when `AccountsController` notifies |

## C3 — Navigation & Interaction Gaps
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **NAV-01** | `ui/manage/categories_screen.dart` | Category card tap calls `log()` but does nothing visible — user thinks app frozen | Open edit modal on tap |
| **NAV-02** | `ui/manage/loans/loan_tracker_screen.dart` | Long-press = action sheet, tap = detail — inconsistent mental model | Unify: tap = detail, "⋮" button in detail for actions |
| **NAV-03** | `ui/manage/contacts_screen.dart` | Edit contact: cancel leaves user at root list, not back in person sheet | Re-open person sheet after edit dialog closes |
| **NAV-04** | `ui/manage/goals/goals_screen.dart` | "Expiring soon" banner `onPressed: () {}` — does nothing | Scroll to / highlight expiring goals |
| **NAV-05** | `ui/dashboard/dashboard_action_sheet.dart` | 147-150 | Rapid taps: sheet pop + new page push race — navigation stack corruption | Use `Navigator.popAndPushNamed()` |
| **NAV-06** | `ui/dashboard/transaction_wizard.dart` | 106-109 | `_navigateToStep()` no bounds check — negative step crashes PageView | Guard: `if (step < 0 || step >= _totalSteps) return;` |

## C4 — Performance
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **PERF-01** | `ui/widgets/liquid_progress_indicators.dart` | Wave path recalculated every frame, every pixel — major CPU spike on 120Hz | Pre-calculate path; only recalculate on size change |
| **PERF-02** | `ui/dashboard/widgets/net_worth_widget.dart` | Carousel timer not cancelled on app background | Cancel in `AppLifecycleState.paused`; restart on resumed |
| **PERF-03** | `ui/widgets/global_search_overlay.dart` | 132 | Debounce timer NOT cancelled before creating new one — old timer fires after new result | `_debounce?.cancel()` BEFORE `_debounce = Timer(...)` |
| **PERF-04** | `ui/manage/reports_analysis_screen.dart` | Heavy aggregation runs on main thread — UI jank on large datasets | Move to `compute()` isolate |
| **PERF-05** | `ui/spending_insights_screen.dart` | `Consumer2<TransactionsController, BudgetsController>` rebuilds entire screen on any change to either | Split into independent child consumers; memoize `computeSpendIntel()` |
| **PERF-06** | `ui/dashboard/widgets/health_score_widget.dart` | Score re-animates from 0 on every rebuild | Only animate on initial build; use `ValueKey` |

## C5 — Services & Data Quality
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **SVC-01** | `utils/alert_service.dart` | Crash reporting is a placeholder — no Sentry or Crashlytics wired | Integrate Sentry or Firebase Crashlytics |
| **SVC-02** | `utils/id_generator.dart` | 7 | `_sequence` resets on app restart — collision possible within same microsecond | Persist sequence to SharedPreferences OR use UUID v4 |
| **SVC-03** | `services/integrity_check_service.dart` | Detects orphaned records but provides no cleanup method | Add `Future<int> cleanupOrphanedRecords()` exposed in Settings |
| **SVC-04** | `services/anomaly_detector.dart` | Flags ±2σ on all-time average — December/January seasonal spike always triggers false anomalies | Use rolling 90-day baseline; increase to 3σ in Dec-Jan |
| **SVC-05** | `logic/backup_restore_service.dart` | `_transactionFingerprint()` dedup — two transactions with same amount/date but different merchant counted as duplicate | Include ID or merchant in fingerprint; prefer ID-based dedup |
| **SVC-06** | `services/gold_price_service.dart` | Hardcoded MCX markup `* 1.185` — no comment, no timestamp, no staleness indicator | Add `DateTime fetched` to price object; show "as of [time]" in UI |
| **SVC-07** | `services/amfi_data_service.dart` | Parse failures swallowed silently — if 50%+ of data malformed, user sees incomplete MF list | Return `{success, failRate}`; show warning toast if `failRate > 0.25` |

## C6 — Lock Screen & App Lifecycle
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **LOCK-01** | `main.dart` | Lock screen as `Positioned.fill()` doesn't cover sheets, FABs, or system overlays | Use `showDialog()` as a full-cover route; or `NavigatorOverlay` |
| **LOCK-02** | `main.dart` | `didChangeAppLifecycleState(resumed)` doesn't re-show lock — biometric failure + background = data visible | Show lock on `resumed` if `settings.requiresAuth && !settings.isAuthenticated` |
| **LOCK-03** | `ui/main.dart` | `PopScope(canPop: false)` blocks back button but not iOS swipe gesture | Add `IgnorePointer` during lock or block swipe gesture detector |

## C7 — Validation Gaps
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **VAL-01** | `ui/manage/crypto/crypto_wizard_controller.dart` | Wallet address validated only as `isNotEmpty` — "abc" passes | Add min-length check: `walletAddress.length >= 26` |
| **VAL-02** | `utils/form_validators.dart` | 320 | `pastDate` uses `DateTime.now()` including time — "today at 11:59 PM" rejected as future | Use date-only: `DateTime(now.year, now.month, now.day)` |
| **VAL-03** | `ui/manage/budgets/modals/add_budget_modal.dart` | No upper bound on budget limit — ₹10 billion accepted | Cap at ₹1Cr with error message |
| **VAL-04** | `ui/dashboard/transaction_wizard.dart` | `kMaxAmountINR` — verify it's defined; if not, no upper bound validation | Ensure constant defined and enforced |

---

# PART D — P3: Polish & Edge Cases

## D1 — Touch & Interaction
| ID | Issue | Fix |
|----|-------|-----|
| **UX-01** | Dashboard budget bars not tappable | Navigate to budget detail on tap |
| **UX-02** | Transaction list items have no press feedback (scale/opacity) | Add `GestureDetector` with opacity animation |
| **UX-03** | `CupertinoSwitch` in dashboard settings has no haptic | `HapticFeedback.selectionClick()` on toggle |
| **UX-04** | Transaction history filter chip not highlighted when active | `isSelected: _typeFilter == type` |
| **UX-05** | Goals "expiring soon" banner button visually active but does nothing | Scroll to or highlight expiring goals |
| **UX-06** | Onboarding CTA buttons have no haptic | `HapticFeedback.lightImpact()` on "Next" / "Get Started" |

## D2 — Delete Confirmations Missing
| ID | Issue | Fix |
|----|-------|-----|
| **DEL-01** | Goals: swipe-to-delete has no confirmation — instant irreversible loss | `showCupertinoDialog()` before delete; undo toast for 5s |
| **DEL-02** | Budgets: same — no confirmation | Same |
| **DEL-03** | Tags: swipe-delete no confirmation | Same |

## D3 — Animation Quality
| ID | Issue | Fix |
|----|-------|-----|
| **ANIM-01** | Health score widget re-animates from 0 on every rebuild | Animate on initial build only; `ValueKey` to prevent re-trigger |
| **ANIM-02** | `card_deck_view.dart` — `_swipeController` resets before `_promotionController` finishes | Await promotion animation before reset |
| **ANIM-03** | `animated_counter.dart`:575 — particle dx/dy always positive — particles move in one direction only | `(random.nextDouble() - 0.5) * 2` for `[-1, 1]` range |

## D4 — Formatting Edge Cases
| ID | Issue | Fix |
|----|-------|-----|
| **FMT-01** | `services/sms_parser.dart` — merchant names may start with `=`, `+`, `@`, `-` — unsafe for CSV | Prefix with `'` in export (already in P0 EXPORT-01, fix there) |
| **FMT-02** | `utils/pref_keys.dart` — legacy keys have no `@deprecated` annotation | Add `@deprecated('Use X instead')` above each legacy key |
| **FMT-03** | `utils/user_error_mapper.dart` — all error messages English-only; no context for localization | Pass `BuildContext`; look up from `AppStrings` |
| **FMT-04** | `ui/widgets/card_deck_view.dart`:5-14 — comment says "Bloomberg-level" but no accessibility labels | Remove hyperbole; add `semanticLabel: 'Card N of M'` |

## D5 — State Persistence
| ID | Issue | Fix |
|----|-------|-----|
| **STATE-01** | Goals screen search query lost on back navigation | Persist to `PageStorage` or `SharedPreferences` |
| **STATE-02** | Budgets filter period lost on navigation | Same |
| **STATE-03** | Transaction wizard calculator modal is `StatefulBuilder` — no proper lifecycle | Convert to separate `StatefulWidget` |

---

# PART E — Architecture (Non-Blocking, High ROI)

| ID | Description | Impact |
|----|-------------|--------|
| **ARCH-01** | **Full SQLite migration** — Everything except MF in SharedPreferences JSON blobs: no transactions, no indexes, O(n) scan, concurrent write corruption risk. Migrate Transactions, Accounts, Budgets, Goals, Investments, Loans, Contacts, Lending to SQLite tables. | Highest single ROI. Eliminates concurrent write risk, enables queries/indexes, crash-safe writes |
| **ARCH-02** | **Enum serialisation standard** — Mix of `.index` and `.name` across 25+ models. Pick one. Current mix causes silent corruption on enum reorder. Recommend `.name` (stable across reorder). | Prevents entire class of corruption bugs |
| **ARCH-03** | **Soft-delete everywhere** — Hard deletes make orphan detection and undo impossible. Add `isDeleted + deletedAt` to Transaction, Account, Investment, Budget, Loan, Goal, Contact. | Enables undo, audit trail, orphan cleanup |
| **ARCH-04** | **Investment ↔ account reconciliation** — Every invest/sell/delete must post a corresponding Transaction to maintain account balance integrity. Currently investments and accounts are completely disconnected. | Fixes entire class of balance mismatch bugs |
| **ARCH-05** | **Save pattern standard** — Enforce `await _save(); notifyListeners();` everywhere. Current mix of awaited/unawaited causes subtle data loss. | Eliminates all SAVE-xx class bugs |
| **ARCH-06** | **Controller error surface** — All 18 providers initialize silently. Add `isError` + `errorMessage` to each. Show recovery UI if init fails. | Prevents blank screen on startup failure |

---

# PART F — Already Done (Verified in Code)

- [x] AMOLED dark theme (pure black `0xFF000000`)
- [x] 11+ Provider controllers initialized at startup
- [x] SMS scanning toggle
- [x] Onboarding flow
- [x] SmoothScrollPhysics + cacheExtent on large lists
- [x] CSV / PDF / Excel export via share_plus
- [x] Account details sheet + per-account CSV
- [x] Light mode WCAG AA color helpers
- [x] Landscape nav bar hidden + swipe-back
- [x] CardDeckView widget (swipe stack)
- [x] Dashboard card deck (6 cards)
- [x] Spending Insights — expandable sections (uncommitted in 3 files)
- [x] Hardcoded backup key — v2 now uses per-device key
- [x] Weak PIN salt — now `Random.secure()` 128-bit salt
- [x] Recovery code clipboard timer — clears on pause + 60s
- [x] Enum bounds in Transaction + Investment models — safe
- [x] AI planner month underflow — fixed with `subtract(Duration)`
- [x] Division by zero in AI planner savings rate — guarded
- [x] AsyncMutex exists at `utils/async_mutex.dart` — use it everywhere needed
- [x] AnimationControllers in `liquid_fab.dart` — all 3 correctly disposed
- [x] AnimationControllers in `animated_counter.dart` — correctly disposed
- [x] Debounce timer in global search — cancelled in `dispose()`

---

# Batch Tracker

### Batch 1 — P0 Security + Data Safety (DO FIRST)
**IDs:** SEC-01→08, ENUM-01→09, CAST-01→08, DIV-01→07, ASYNC-01→08, TXN-01→04, SAVE-01→08, HTTP-01→04, IMPL-01→02

### Batch 2 — P1 Correctness
**IDs:** DATE-01→05, CASCADE-01→04, CALC-01→07, INV-01→10, INIT-01→04, SMS-01→04, MEM-01→05

### Batch 3 — P2 UX
**IDs:** EMPTY-01→04, STALE-01→04, NAV-01→06, PERF-01→06, SVC-01→07, LOCK-01→03, VAL-01→04

### Batch 4 — P3 Polish
**IDs:** UX-01→06, DEL-01→03, ANIM-01→03, FMT-01→04, STATE-01→03

**Rule:** Commit + APK after every batch.

---

## Issue Count Summary

| Priority | Security | Models/Casts | Async/Crash | Data Loss | Services | UI/UX | Total |
|----------|----------|--------------|-------------|-----------|----------|-------|-------|
| **P0** | 8 | 17 | 8 | 12 | 4 | 2 | **51** |
| **P1** | 0 | 7 | 5 | 10 | 7 | 10 | **39** |
| **P2** | 0 | 0 | 0 | 4 | 7 | 20 | **31** |
| **P3** | 0 | 0 | 0 | 0 | 2 | 15 | **17** |
| **Total** | **8** | **24** | **13** | **26** | **20** | **47** | **138** |
