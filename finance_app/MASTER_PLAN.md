# VittaraFinOS — Full App Audit & Master Plan
> Complete deep audit: 289 files, 7 domains, ~294 issues found.
> Created: 2026-03-25 | Update `[~]` (in progress), `[x]` (done) after every task.
> Stack: Flutter + Provider + SQLite/SharedPreferences (~95K LOC)

---

## Legend
- `[ ]` not started · `[~]` in progress · `[x]` done
- **P0** = crash / data-loss / security — fix before ANYTHING else
- **P1** = wrong behaviour, broken feature
- **P2** = important UX / correctness improvement
- **P3** = polish, edge-case, nice-to-have

---

# PART A — P0: Critical Bugs & Security

## A1 — Security
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **SEC-01** | `logic/backup_restore_service.dart:121-147` | Hardcoded `_masterSecretSeed` bytes — any attacker with APK can derive master key and decrypt all user backups | Derive key from device ID + user secret, store salt in Keychain |
| **SEC-02** | `logic/settings_controller.dart:235` | PIN salt is `'vittara_pin_salt_$pin'` — identical per PIN, enables rainbow table attack | Generate random per-user salt, store alongside hash |
| **SEC-03** | `ui/recovery_code_save_screen.dart:33-35` | Recovery code persists in system clipboard after app backgrounds — accessible to other apps even after 60s timer | Clear clipboard in `AppLifecycleState.paused` hook |
| **SEC-04** | `logic/backup_restore_service.dart:59,309` | Legacy v1 encryption path (`hmac-sha256-stream-xor-v1`) still silently accepted; users cannot migrate from v1 to v2 | Force migration prompt; reject v1 after migration window |

## A2 — Database Architecture
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **DB-01** | `services/database_helper.dart:23` | DB version hardcoded to 1, `onUpgrade` is null — any schema change destroys existing user data | Add version history + `onUpgrade` migration runner |
| **DB-02** | All controllers | Everything except MF uses SharedPreferences JSON blobs — no transactions, no indexes, O(n) scan for all queries, concurrent writes corrupt data | Migrate Transactions, Accounts, Budgets, Goals, Investments, Loans to SQLite tables |
| **DB-03** | `logic/transactions_controller.dart:18-53` | Two concurrent writes (SMS scan + manual add) → last write wins, earlier data lost | Wrap all SharedPreferences writes in async mutex |
| **DB-04** | `services/database_helper.dart:50-60` | Only 3 indexes on `mutual_funds` table; SharedPreferences models have zero indexes | Add indexes: `dateTime`, `accountId`, `categoryId`, `type` on transactions; `scheme_code`, `is_active` on MF |

## A3 — Data Model Type Safety (crashes from DB)
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **MDL-01** | `logic/loan_model.dart:92` | `type.name` used for serialisation; if enum is reordered, all loans load wrong type | Standardise to `.index` across ALL models |
| **MDL-02** | `logic/lending_borrowing_model.dart:91,106-107` | `type.toString().contains('lent')` — breaks if enum name ever changes | Use `.index` |
| **MDL-03** | `logic/insurance_model.dart:117` | `type.name` vs `type.index` — dual serialisation patterns across codebase | Standardise to `.index` |
| **MDL-04** | `logic/investment_model.dart:115` | `amount: map['amount']` — direct assign without `(map['amount'] as num).toDouble()` — crashes if stored as int | Fix all amount casts to `(map['x'] as num?)?.toDouble() ?? 0.0` |
| **MDL-05** | `logic/fixed_deposit_model.dart:274` | `withdrawalAmount as double?` — throws if key missing | Safe cast |
| **MDL-06** | `logic/bonds_model.dart:258` | `redemptionPrice as double?` — throws if missing | Safe cast |
| **MDL-07** | `logic/transaction_model.dart:93-96` | `double.tryParse(map['amount'])` with `?? 0.0` — silently zeroes corrupt amounts | Log + mark record as suspect instead of silent zero |
| **MDL-08** | All models with enum index access | `BudgetPeriod.values[map['period']]`, `GoalType.values[map['type']]`, `RDPaymentFrequency.values[...]`, `BondType/CouponFrequency/BondStatus/NPSTier/NPSManager/CryptoCurrency/FOType/CommodityType/TradePosition` — all crash on out-of-bounds index | Wrap every `EnumType.values[n]` with `n < EnumType.values.length ? EnumType.values[n] : EnumType.values.first` |

## A4 — Calculation Crashes (division by zero / month underflow)
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **CALC-01** | `services/investment_value_service.dart:208-213` | `daysPerCompound = 365 / compoundsPerYear` — division by zero if `compoundsPerYear == 0` | Guard: `if (compoundsPerYear == 0) return principal` |
| **CALC-02** | `logic/ai_planner_engine.dart:69` | `DateTime(now.year, now.month - 3, 1)` — month underflow crash in January (month-3 = -2) | Use `now.subtract(const Duration(days: 90))` |
| **CALC-03** | `services/gold_price_service.dart:41` | Price returned if exchange rate or spot price is 0/negative — invalid cache entry | Validate `result > 0` before caching |
| **CALC-04** | `ui/manage/budgets/budget_details_screen.dart:107-109` | `spentAmount / limitAmount` — division by zero if `limitAmount == 0` | Guard with `limitAmount > 0 ? ... : 0.0` |
| **CALC-05** | `logic/goals_controller.dart:391` | `overallProgress` — NaN if all target amounts are 0 | Guard denominator |

## A5 — Async Lifecycle (mounted check order)
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **ASYNC-01** | `ui/manage/fd/fd_wizard_screen.dart:138,144` | `showSuccess()` toast called BEFORE `if (mounted)` check — toasts on dead context | Check `mounted` first, THEN show toast/pop |
| **ASYNC-02** | `ui/pin_recovery_screen.dart:208` | `popUntil()` called after long async nuclear reset without `mounted` check | Add `if (!mounted) return` before every post-await navigation |
| **ASYNC-03** | `ui/manage/mf/mf_wizard.dart:163` | `setState(() => _isSubmitting = true)` without `mounted` check before network fetch | Add `if (!mounted) return` |
| **ASYNC-04** | `ui/manage/nps/nps_wizard.dart:97-105` | `_saveInvestment()` never checks `mounted` before toast/nav | Add mounted check |
| **ASYNC-05** | `ui/manage/stocks/stocks_wizard.dart:133-146` | `Navigator.pop()` THEN `context.mounted` check — wrong order, should check BEFORE using context | Reorder: check → pop → toast |

---

# PART B — P1: Broken Features & Wrong Behaviour

## B1 — Investment Flow Bugs (money not balanced)
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **INV-01** | `ui/manage/investments/simple_investment_details_screen.dart:144-153` | Deleting investment does NOT reverse the account balance debit that was made at creation | On delete: find linked transaction or reverse debit manually |
| **INV-02** | `ui/manage/stocks/stocks_wizard.dart:50-57` | Deleting stock after debit does NOT reverse account debit → account permanently short | Same: reverse debit on delete |
| **INV-03** | `ui/manage/mf/mf_wizard.dart:165-172` | MF full sell removes investment but does NOT credit account back | Credit deduction account on sell |
| **INV-04** | `ui/manage/mf/steps/mf_new_investment_details_step.dart:65-68` | Historical NAV fetch not implemented — silently uses current NAV for past-dated MF investments | Show manual NAV entry field when date is in past |
| **INV-05** | `ui/manage/bonds/bonds_wizard_controller.dart:112` | YTM hardcoded to `yearsToMaturity = 5.0` — every bond shows same YTM regardless of tenure | Calculate from `maturityDate - purchaseDate` |
| **INV-06** | `ui/manage/fd/fd_wizard_controller.dart:96-111` | FD tenure in days converted via `days * 12 / 365` — lossy, 100-day FD becomes 3 months | Store `tenureDays` separately; compute maturity date from actual days |
| **INV-07** | `ui/manage/fd/fd_wizard_screen.dart:377-378` | `estimatedAccruedValue` set to `principal` at creation and never updated — FD details screen always shows wrong accrued value | Compute accrued value dynamically from principal + interest formula |
| **INV-08** | `ui/manage/mf/mf_wizard_controller.dart:183-200` | NAV not re-fetched if user changes investment date after initial fetch — stale NAV used | Listen to date changes and refetch |
| **INV-09** | `ui/manage/digital_gold/digital_gold_wizard_controller.dart:31-47` | `gstRate` has no bounds validation — negative GST makes `actualAmount` negative | Validate GST in range [0, 28] |
| **INV-10** | `ui/manage/nps/nps_wizard_controller.dart:35-43` | `gainLossPercent` has no bounds — 0.0001 contribution + ₹100 current value = 999999% return | Clamp to reasonable bounds, add sanity check |
| **INV-11** | `ui/manage/bonds/bonds_wizard_controller_v2.dart` vs `bonds_wizard_controller.dart` | Two bond wizard controllers exist — which is live? Dead code or dual logic? | Identify active one, delete the other |
| **INV-12** | `logic/fd_calculations.dart:92-107` | Custom `pow()` helper drops integer part for non-integer exponents | Replace with `dart:math pow()` directly |
| **INV-13** | `logic/fd_renewal_cycle.dart:39-43` | `getAccruedValue()` uses linear pro-rata but FD compounds — underestimates real accrued value | Use compound interest formula |
| **INV-14** | `logic/bond_cashflow_model.dart:362-363` | `totalMonths = diff.inDays ~/ 30` — wrong, use actual calendar months | Use `DateTime` month arithmetic |

## B2 — Persistence Bugs (saves not awaited)
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **SAVE-01** | `logic/accounts_controller.dart:115-123` | `reorderAccounts()` — `_saveAccounts()` not awaited; reorder lost on crash | `await _saveAccounts()` before `notifyListeners()` |
| **SAVE-02** | `logic/investments_controller.dart:156-165` | `reorderInvestments()` — same pattern | `await _saveInvestments()` |
| **SAVE-03** | `logic/categories_controller.dart:203` | `reorderCategories()` — never calls `_saveCustomCategories()` at all | Add save call |
| **SAVE-04** | `logic/budgets_controller.dart:116-125` | `updateBudgetSpending()` — fire-and-forget save | Await |
| **SAVE-05** | `logic/lending_borrowing_controller.dart:46,56` | `addRecord()` / `updateRecord()` — not awaited | Await all saves |
| **SAVE-06** | `logic/payment_apps_controller.dart:184-193` | `adjustWalletBalanceByName()` — not awaited | Await |
| **SAVE-07** | `logic/recurring_templates_controller.dart:53` | `notifyListeners()` called BEFORE `_save()` — UI updates before data is persisted | Reverse order: save then notify |
| **SAVE-08** | `logic/transactions_archive_controller.dart:15` | Constructor loads async data without signalling when ready — first access may see empty list | Add `isLoaded` flag + notify on load complete |

## B3 — CRUD Cascade & Orphan Bugs
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **CRUD-01** | `ui/manage/categories_screen.dart:59-73` | Deleting category leaves budgets referencing it — orphaned budgets | Check `budgetsController.budgets.any((b) => b.categoryName == cat.name)` before delete; show warning |
| **CRUD-02** | `ui/manage/contacts_screen.dart:615-627` | Deleting contact leaves lending/borrowing records with stale contact name | Show warning / block delete if active records exist |
| **CRUD-03** | `ui/manage/banks_screen.dart:35-69` | Deleting bank doesn't cascade to accounts tagged with that bank | Show warning / handle orphaned accounts |
| **CRUD-04** | `ui/manage/contacts_screen.dart:843-854` | Contact edit = delete + add — non-atomic; if add fails, contact is lost | Use `updateContact()` atomic operation |
| **CRUD-05** | `ui/manage/goals/modals/edit_goal_modal.dart:48-75` | `updateGoal()` called without await, Navigator.pop() immediate — data may not be saved if update fails | Await + show error if fails |
| **CRUD-06** | `ui/manage/tags_screen.dart:492-498` | Delete tag has no confirmation dialog; swipe can delete accidentally | Add confirmation |
| **CRUD-07** | `logic/contacts_controller.dart:47-60` | `addOrGetContact()` uses object identity `!_contacts.contains(existing)` on newly-created object — always adds duplicates | Use `.any((c) => c.name == name)` check |
| **CRUD-08** | `ui/manage/goals/goals_screen.dart:497-530` | Undo after delete calls `addGoal(goal)` without checking if delete actually succeeded — could create duplicate | Verify delete success before showing undo |

## B4 — Validation Gaps in Wizards
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **VAL-01** | `ui/manage/rd/rd_wizard_controller.dart:122-141` | Step 1 `canProceed` returns `true` unconditionally — no startDate validation | Add `startDate != null` check |
| **VAL-02** | `ui/manage/fd/fd_wizard_controller.dart:193-213` | Interest rate has no upper bound (1000% accepted) | Validate `0 < rate <= 25` |
| **VAL-03** | `ui/manage/stocks/stocks_wizard_controller.dart:91-104` | Step 3 (deduction) always returns `true` — allows negative account balance silently | Block proceed if account balance < 0 after deduct, or at minimum show error |
| **VAL-04** | `ui/manage/budgets/modals/add_budget_modal.dart:42-46` | No upper bound on budget limit (₹10 billion accepted) | Cap at ₹1Cr with error message |
| **VAL-05** | `ui/manage/goals/modals/add_goal_modal.dart:44-48` | No upper bound on goal target amount | Same cap |
| **VAL-06** | `ui/manage/goals/modals/add_contribution_modal.dart:34-38` | Negative contribution not explicitly rejected | `if (amount <= 0) return` |
| **VAL-07** | `ui/manage/lending_wizard.dart:816` | `double.tryParse()` can return null, coalesced to 0, accepted | Explicit `if (amount == null || amount <= 0)` guard |
| **VAL-08** | `logic/payment_apps_controller.dart:38` | `item['color'] as int` crashes if null | `(item['color'] as int?) ?? 0xFF000000` |
| **VAL-09** | `ui/manage/nps/nps_wizard_controller.dart:45-69` | Step 3 allows null `plannedRetirementDate` | Make date required for non-`none` withdrawal types |

## B5 — State / Navigation Bugs
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **NAV-01** | `ui/settings_screen.dart:620-626` | After PIN setup, RecoveryCodeSaveScreen back button pops twice — leaves PIN setup in inconsistent state | Use `WillPopScope` or custom back logic on recovery screen |
| **NAV-02** | `ui/notifications_page.dart:369-385` | `if (!context.mounted)` check after `Navigator.push` — should be before | Reorder |
| **NAV-03** | `ui/manage/categories_screen.dart:277-280` | Category card tap calls `log()` but does nothing visible — user thinks app is broken | Open edit modal on tap |
| **NAV-04** | `ui/manage/goals/goals_screen.dart:425` | "Expiring Soon" banner `onPressed: () {}` — does nothing | Scroll to/highlight expiring goals |
| **NAV-05** | `ui/manage/loans/loan_tracker_screen.dart:232-253` | Long-press → action sheet, tap → detail: inconsistent mental model for same card | Unify: tap = detail, action sheet accessible via "⋮" button in detail header |
| **NAV-06** | `main.dart:285-286` | Lock screen overlay (`Positioned.fill`) doesn't cover `CupertinoModalPopup` sheets — user can see data behind lock | Use `Navigator.overlay` or route-level lock guard |
| **NAV-07** | `ui/manage/contacts_screen.dart:344-349` | Edit contact pops detail sheet → edit dialog; cancel leaves user at root contacts list, not back in person sheet | Re-open person sheet after edit dialog closes |
| **NAV-08** | `services/sms_auto_scan_service.dart:312-316` | Transaction fingerprint uses `sender.hashCode` which is NOT stable across app restarts — inconsistent deduplication | Build fingerprint from `amount_day_month_year_senderString` (no hashCode) |

## B6 — Calculation Bugs (wrong results)
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **CALC-10** | `logic/transactions_controller.dart:119-120` | `getTransactionsInDateRange()` excludes transactions at exact boundary times (uses strict `isAfter`/`isBefore`) | Use `!isBefore(start) && !isAfter(end)` |
| **CALC-11** | `services/nav_service.dart:180-200` | XIRR is a simple ratio average, not time-weighted — SIP returns completely wrong | Implement proper Newton-Raphson XIRR iteration |
| **CALC-12** | `logic/pin_recovery_controller.dart:116` | Remaining attempts counter off-by-one: shows 0 remaining before lockout triggers | Fix: `remainingBeforeLockout: max(0, 3 - attempts)` |
| **CALC-13** | `logic/goals_controller.dart:99` | Floating-point: contribution of ₹999.9999999 on ₹1000 goal doesn't trigger completion | Use `>= target - 0.005` tolerance check |
| **CALC-14** | `logic/goals_controller.dart:123` | `withdrawFromGoal()` clamps currentAmount to targetAmount — prevents overfunding | Clamp to `max(0, ...)` only, no upper cap |
| **CALC-15** | `logic/fo_model.dart:102-103` | `getMaxProfit()` for put option calculates short-put profit, not long-put | Add `positionDirection` field and calculate correctly per direction |
| **CALC-16** | `services/transaction_export_service.dart:556-560` | `>= 1e7` threshold for Crore display — ₹1,00,00,001 shows as "₹1.00Cr" | Use `> 1e7` |
| **CALC-17** | `utils/percent_formatter.dart:7-15` | 0.001 formatted as "0%" — loses precision | Show "< 0.01%" for very small values |
| **CALC-18** | `logic/recurring_template_model.dart:141` | `DateTime(base.year, base.month + 1, base.day)` — Jan 31 + 1 month = Feb 31 (invalid) | Use safe month-add helper |

---

# PART C — P2: Important Improvements

## C1 — UX: Data Refresh (stale screens)
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **REF-01** | `ui/manage/goals/goal_details_screen.dart:121-122` | Contribution added in child modal — parent goal progress % doesn't update until re-open | Check modal result and refresh on pop |
| **REF-02** | `ui/manage/budgets/budget_details_screen.dart:293-407` | Spending breakdown not refreshed when transactions added elsewhere | Listen to `TransactionsController` in budget details |
| **REF-03** | `ui/manage/contacts_screen.dart:234-501` | Contact detail sheet shows stale lending/borrowing totals | Refresh on sheet open; listen to `LendingBorrowingController` |
| **REF-04** | `ui/manage/goals/goals_screen.dart:77` | "Expiring soon" banner computed once per build — doesn't update if date crosses while screen is open | Use `Timer.periodic` or `ValueListenableBuilder` |
| **REF-05** | `ui/net_worth_page.dart:445-446` | `_maybeSaveSnapshot()` called via `addPostFrameCallback` on EVERY rebuild, not just first | Add `_snapshotSavedThisSession` flag |

## C2 — UX: Empty & Error States
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **EMPTY-01** | `ui/notifications_page.dart:162-240` | No "all caught up" message when all notification lists empty — page looks broken | Show icon + "You're all caught up" |
| **EMPTY-02** | `ui/dashboard/widgets/budget_widget.dart:169-221` | No empty state when budgets have 0 spend — section renders blank | Show "No spending recorded yet" |
| **EMPTY-03** | `ui/manage/categories_screen.dart:141-154` | Search "no results" state has no action — user stuck | Add "Create '[query]' category" CTA |
| **EMPTY-04** | `ui/manage/goals/goal_details_screen.dart:29-30` | Goal deleted externally → "not found" with no back button | Add back button in empty state |

## C3 — Performance
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **PERF-01** | `ui/notifications_page.dart:55-58` | `Consumer4` — any controller change rebuilds entire page including expensive spending calculations | Separate into child widgets, each with own Consumer |
| **PERF-02** | `ui/widgets/liquid_progress_indicators.dart:114-122` | Wave path recalculated for every pixel every frame — CPU spike on 120Hz displays | Pre-calculate path, only recalculate on size change |
| **PERF-03** | `ui/widgets/common_widgets.dart:348` | `SkeletonLoader` uses `shrinkWrap: true` without `NeverScrollableScrollPhysics` | Add `physics: const NeverScrollableScrollPhysics()` |
| **PERF-04** | `ui/dashboard/widgets/net_worth_widget.dart:320-333` | Carousel auto-advance timer not cancelled when app goes to background | Cancel in `AppLifecycleState.paused`, restart on `resumed` |
| **PERF-05** | `ui/widgets/global_search_overlay.dart:132` | Debounce timer not cancelled before creating new one — timer leak on rapid typing | `_debounce?.cancel()` before creating new |
| **PERF-06** | `ui/manage/reports_analysis_screen.dart` | Heavy aggregation computed synchronously on main thread — UI freezes on large datasets | Move to `compute()` isolate |

## C4 — Wizard & Edit Quality
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **WIZ-01** | `ui/manage/simple_investment_entry_wizard.dart:160-194` | Edit mode doesn't pre-populate all fields — user loses original values if they save without changing anything | Initialize all TextEditingControllers from `existingInvestment` |
| **WIZ-02** | `ui/manage/fd/steps/review_step.dart:121-161` | Review shows "24 months" when user entered "2 years" | Show in user's original unit |
| **WIZ-03** | `ui/manage/stocks/steps/stock_review_step.dart:61-86` | Quantity shows "100.5" — stocks are whole units | Round or validate integer-only for stocks |
| **WIZ-04** | `ui/manage/mf/mf_wizard.dart:111-190` | Edit mode assumes `metadata` always exists — crashes on old investments without metadata | Null-coalesce all metadata reads |
| **WIZ-05** | `ui/manage/bonds/bonds_wizard.dart:68` | Bond payout schedule frozen at creation — if maturity date was wrong, schedule is wrong forever | Allow regeneration on edit |
| **WIZ-06** | `ui/manage/rd/rd_wizard_screen.dart` | No mid-tenure withdrawal flow — user can't break RD early | Add partial/full withdrawal modal (like FD) |
| **WIZ-07** | `ui/manage/mf/mf_wizard.dart:231-237` | Changing MF type mid-wizard changes step count, causing page controller to jump to wrong step | Reinitialise PageController on type change |
| **WIZ-08** | `ui/manage/loans/loan_tracker_screen.dart:727-768` | Prepayment >= outstanding shows "no savings" same as zero prepayment — ambiguous | Show "Loan will be paid off" message for full prepayment |

## C5 — Services & Data Quality
| ID | File | Issue | Fix |
|----|------|-------|-----|
| **SVC-01** | `services/nav_service.dart:39-40,51` | Fallback NAV HTTP call has no timeout — can hang indefinitely | Wrap fallback in `.timeout(Duration(seconds: 8))` |
| **SVC-02** | `services/amfi_data_service.dart:29-49` | Parsing errors swallowed silently — if 90% of data is malformed, user sees incomplete MF list | Log count + surface warning if <50% parsed |
| **SVC-03** | `services/mf_database_service.dart:60-61` | Sets `_isInitialized = true` even on init failure — all subsequent queries silently fail | Set `false` on error; expose error state |
| **SVC-04** | `services/stock_api_service.dart:37,68` | Yahoo Finance v8 endpoint hardcoded — breaks silently if Yahoo changes API | Add version config + fallback endpoint |
| **SVC-05** | `services/integrity_check_service.dart:14-26` | Orphaned record check reports count but provides no cleanup method | Add `cleanupOrphanedRecords()` exposed to Settings screen |
| **SVC-06** | `services/sms_parser.dart:332-377` | Balance-only SMS (no transaction amount) scored as null — legitimate balance SMSes dropped | Separate balance-detection path from transaction-detection path |
| **SVC-07** | `utils/merchant_normalizer.dart:27-34` | Title-case splits on space only — "McDonald's" → "Mcdonalds" | Use `RegExp(r"[\s\-']+")` split |
| **SVC-08** | `utils/id_generator.dart:12-15` | Sequence resets to 0 on restart — ID collision possible within same microsecond | Add UUID v4 fallback or persist sequence to SharedPreferences |
| **SVC-09** | `logic/backup_restore_service.dart` | No error handling in `_reloadAllControllers()` after restore — partial reload leaves app in inconsistent state | Catch per-controller, report which failed, offer retry |
| **SVC-10** | `services/gold_price_service.dart:27-59` | No staleness warning — user may see hours-old gold price with no indicator | Show "as of [time]" label, highlight if >1h old |

## C6 — Model Completeness
| ID | Issue | Fix |
|----|-------|-----|
| **MDL-20** | All models missing `modifiedDate` — no audit trail for balance updates, loan payoffs | Add `modifiedDate` to Transaction, Account, Investment, Budget, Loan |
| **MDL-21** | No `isDeleted` / soft-delete flag — hard deletions lose history | Add `isDeleted` + `deletedAt` to all primary models |
| **MDL-22** | `goal_model.dart` — `contributions` list has no link to actual `Transaction` records — can't verify contribution amounts | Add `transactionId` field to `GoalContribution` |
| **MDL-23** | `loan_model.dart` — no payment history — can't show "paid on time for 24 months" | Add `PaymentRecord` list to loan model |
| **MDL-24** | `investment_metadata.dart:352-368` — `StockMetadata.fromMap()` no null checks on required fields | Add null guards with sensible fallbacks |
| **MDL-25** | `mutual_fund_model.dart:49` — `nav` nullable with no default — UI must handle everywhere | Default to 0.0 with `isNavStale` flag |
| **MDL-26** | `logic/budget_model.dart:56` — `usagePercentage` upper bound is `double.infinity` | Clamp to `[0, double.maxFinite]` and cap display at 999% |
| **MDL-27** | `logic/fixed_deposit_model.dart:186` — `elapsedFraction` can exceed 1.0 for matured FDs | Clamp to [0, 1] |
| **MDL-28** | `pension_model.dart:77-85` — contributions stored as inline JSON, no incremental append | Migrate to separate table / indexed list |

---

# PART D — P3: Polish & Edge Cases

## D1 — Touch & Interaction Polish
| ID | Issue | Fix |
|----|-------|-----|
| **UX-01** | `ui/dashboard/widgets/budget_widget.dart:178-221` — Budget bars not tappable; user can't drill into budget from dashboard | Make bars navigate to budget detail |
| **UX-02** | `ui/dashboard/widgets/transaction_history_widget.dart:292-378` — No press feedback (scale/opacity) on transaction list items | Wrap in `GestureDetector` with `InkWell` or `Opacity` feedback |
| **UX-03** | `ui/dashboard/widgets/health_score_widget.dart:696-730` — No congratulation state when score ≥ 90 | Show celebration message |
| **UX-04** | `ui/dashboard/widgets/net_worth_widget.dart:545-569` — Account name truncated with no tooltip | Add long-press tooltip |
| **UX-05** | `ui/dashboard/dashboard_settings_modal.dart:187-193` — CupertinoSwitch has no haptic | Add `HapticFeedback.selectionClick()` |
| **UX-06** | `ui/transaction_history_screen.dart:127-131` — Type filter visually active but chip not highlighted | Set `isSelected: _typeFilter == type` |
| **UX-07** | `ui/transaction_history_screen.dart:113-117` — Scroll-to-top threshold 400px hardcoded | Use `MediaQuery.of(context).size.height * 0.4` |

## D2 — Animation Polish
| ID | Issue | Fix |
|----|-------|-----|
| **ANIM-01** | `ui/dashboard/widgets/health_score_widget.dart:497-502` — Score re-animates from 0 on every rebuild | Only animate on initial build; use `ValueKey` |
| **ANIM-02** | `ui/dashboard/widgets/net_worth_widget.dart:597-610` — Dot indicator `AnimatedContainer` runs every 2.5s auto-advance — jank on low-end | Use `AnimatedOpacity` instead (cheaper) |
| **ANIM-03** | `ui/widgets/animations.dart:178-180` — Staggered `FadeInAnimation` has "pop" instead of smooth entrance | Use `CurvedAnimation` with `Interval` on each child |
| **ANIM-04** | `ui/widgets/card_deck_view.dart:71-72` | `_swipeController` resets before `_promotionController` finishes — back cards snap | Wait for promotion animation before resetting |

## D3 — Data Formatting Edge Cases
| ID | Issue | Fix |
|----|-------|-----|
| **FMT-01** | `utils/date_formatter.dart:203-204` — FY 1900 → "FY 1900-00" (ambiguous) | Use 4-digit year for end: "FY 1900-1901" |
| **FMT-02** | `logic/transaction_model.dart:113` — Description defaults to "Transaction" if empty | Default to category name, then merchant, then "Transaction" |
| **FMT-03** | `services/sms_parser.dart:406-452` — Merchant name may contain formula-injection characters — unsafe for CSV export | Sanitize: prefix `=`, `+`, `-`, `@` with single quote in CSV cells |
| **FMT-04** | `services/transaction_export_service.dart:102,130,149` — Metadata fields assumed String — may export "Instance of List" | Add `.toString()` guard with type check |

## D4 — Error Handling Completeness
| ID | Issue | Fix |
|----|-------|-----|
| **ERR-01** | `utils/alert_service.dart:263` — Crash reporting placeholder never implemented | Wire Sentry or Firebase Crashlytics |
| **ERR-02** | `utils/user_error_mapper.dart:24-42` — Missing: `UnsupportedError`, `PlatformException`, `DioException` | Add mappings |
| **ERR-03** | `services/remote_config_service.dart:13-20` — Malformed config JSON fails silently | Log warning + surface to settings debug panel |
| **ERR-04** | `ui/settings/csv_import_screen.dart:29-51` — CSV parser breaks on quoted newlines (multiline bank descriptions) | Use proper RFC 4180 CSV parser |
| **ERR-05** | `services/anomaly_detector.dart:8-33` — Flags seasonal spend as anomaly (summer vs winter shopping) | Use rolling 90-day baseline instead of all-time average |

## D5 — Missing Small Features
| ID | Issue | Fix |
|----|-------|-----|
| **FEAT-01** | `ui/global_search_overlay.dart:104-113` — Recent searches not deduplicated — same query saved 100 times | Deduplicate on save, keep last 10 unique |
| **FEAT-02** | `ui/backup_restore_screen.dart:187-215` — Paste-JSON restore truncates large backups in TextEditingController | Use file picker for restore instead of paste |
| **FEAT-03** | `ui/manage/stocks/steps/stock_review_step.dart` — SIP details not shown on MF review step before confirmation | Add SIP summary row to review if `sipActive = true` |
| **FEAT-04** | `logic/nps_model.dart:126` — No validation that retirement date is after 60th birthday | Add age-based date validation |
| **FEAT-05** | `services/integrity_check_service.dart` | No UI to run / view integrity check — only computed internally | Add "Data Integrity" section in Settings |

---

# PART E — Architecture Recommendations (non-blocking)

| ID | Description |
|----|-------------|
| **ARCH-01** | **Full SQLite migration** — Move all SharedPreferences JSON blobs to SQLite tables. Highest ROI of any single change: enables queries, transactions, indexes, foreign keys, and eliminates the concurrent-write data loss risk. |
| **ARCH-02** | **Enum serialisation standard** — Pick ONE: `.index` (fast, compact) OR `.name` (readable, stable across reorder). Apply across all 25+ models. Current mix causes silent corruption on enum reorder. |
| **ARCH-03** | **Soft-delete everywhere** — Add `isDeleted + deletedAt` to all entities. Hard-deletes make orphan detection and undo impossible. |
| **ARCH-04** | **Investment account reconciliation** — Every investment creation/deletion/sell should post a corresponding Transaction to maintain account balance integrity. Currently these are disconnected. |
| **ARCH-05** | **Controller save pattern** — Standardise: `await _save(); notifyListeners();` everywhere. Current mix of awaited/unawaited breaks in subtle ways. |

---

# PART F — Already Done (Previous Sessions)

- [x] AMOLED dark theme (pure black)
- [x] 11 Provider controllers wired
- [x] SMS scanning toggle
- [x] Investment tracking toggle
- [x] Onboarding flow fixed
- [x] Transaction wizard step-0 flash fixed
- [x] SmoothScrollPhysics + cacheExtent on large lists
- [x] CSV/PDF/Excel exports via share_plus
- [x] Account details sheet + per-account CSV
- [x] Investment item tap → Add/Sell/Details action sheet
- [x] Light mode WCAG AA color helpers
- [x] Landscape nav bar hidden + swipe-back
- [x] CardDeckView widget (swipe stack)
- [x] Dashboard card deck (6 cards)
- [x] Spending Insights — expandable category/rhythm/merchant sections (uncommitted, 3 files modified)

---

## Batch Tracking

### Next Batch: Security + P0 Data Safety
**IDs:** SEC-01, SEC-02, SEC-03, DB-03, ASYNC-01→05, SAVE-01→08, MDL-01→08 (enum + type safety)

**Rule:** Commit + build APK after every batch.
