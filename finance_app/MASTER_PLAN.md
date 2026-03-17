# VittaraFinOS — Master Plan (Living Document)
# NEVER DELETE THIS FILE. Update status inline as tasks complete.
# Last updated: 2026-03-17

---

## HOW TO USE THIS FILE
- `[ ]` = not started | `[~]` = in progress | `[x]` = done | `[–]` = skipped/not applicable
- Each task has a unique ID (e.g. `AU1-01`). Reference by ID when discussing work.
- Sections: AU = Audit tasks | FT = New Features | MG = Merge | RM = Remove | PR = PIN Recovery

---

# PART A — 20-DIMENSION AUDIT TASKS

## AU1 — USER SIDE (End-user experience & flow completeness)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU1-01 | P1 | [~] | Add step progress bar ("Step 3 of 7") below nav bar in ALL multi-step wizards | `transaction_wizard.dart`, all investment wizards |
| AU1-02 | P1 | [~] | After creating investment/account/transaction, scroll parent list to new item on pop | `investments_screen.dart`, `accounts_screen.dart` |
| AU1-03 | P1 | [x] | Audit every list screen: ensure there is a "no items" empty state with icon + CTA button | All list screens |
| AU1-04 | P1 | [x] | Add `WillPopScope` → "Discard changes?" confirm dialog on back when wizard has data entered | All multi-step wizards |
| AU1-05 | P2 | [x] | Persist search query across navigation (investments, accounts, archive) | `investments_screen.dart`, `accounts_screen.dart`, `transactions_archive_screen.dart` |
| AU1-06 | P2 | [x] | Auto-focus amount field when entering a wizard step that has an amount input | All amount steps |
| AU1-07 | P2 | [x] | After delete/edit operations, show brief "Updated" confirmation toast | All delete/edit handlers |
| AU1-08 | P3 | [x] | Add grey sub-text under "Skip" buttons: "Optional — you can add this later" | Merchant/Description/Tags wizard steps |
| AU1-09 | P3 | [–] | New user first-launch checklist: "Add account → Add first transaction → Set a budget" | Onboarding / dashboard |

---

## AU2 — DEVELOPER SIDE (Code quality, maintainability)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU2-01 | P1 | [~] | Extract wizard steps from `transaction_wizard.dart` (3,457 LOC) into separate step widget files | `transaction_wizard.dart` |
| AU2-02 | P1 | [~] | Extract sections from `reports_analysis_screen.dart` (3,728 LOC) into sub-widgets | `reports_analysis_screen.dart` |
| AU2-03 | P1 | [x] | **FIXED** Remove duplicate `_buildDivider(context)` in settings Features section | `settings_screen.dart:113-114` |
| AU2-04 | P1 | [x] | Standardize controller initialization — all should call `.load()` in `create:` lambda | `main.dart:67–121` |
| AU2-05 | P2 | [x] | Create `PrefKeys` const class with all SharedPreferences string keys in one place | New file `lib/utils/pref_keys.dart` |
| AU2-06 | P2 | [x] | Standardize `with ChangeNotifier` vs `extends ChangeNotifier` — pick `with` everywhere | All 11 controllers |
| AU2-07 | P2 | [~] | Create `BaseModel` abstract class with `toMap()`/`fromMap()` mixin to remove duplication | All model files |
| AU2-08 | P2 | [~] | Move SMS parser bank regex patterns to a JSON asset file (`assets/sms_patterns.json`) | `sms_parser.dart` |
| AU2-09 | P3 | [~] | Add `/test` directory with controller unit tests (at minimum: TransactionsController, InvestmentsController) | New `/test` directory |
| AU2-10 | P3 | [~] | Add widget tests for critical flows: PIN entry, account creation, transaction wizard | New `/test/widget` |

---

## AU3 — FUTURE-PROOF (Scalability, migrations, hard-coded assumptions)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU3-01 | P1 | [x] | Move all API base URLs (gold price, NAV fetch) to `AppConfig` class | `gold_price_service.dart`, `mf_search_service.dart` |
| AU3-02 | P1 | [x] | Document database schema migration path; add `_migrateV4toV5()` skeleton | `backup_restore_service.dart` |
| AU3-03 | P2 | [~] | Add `go_router` or `auto_route` for deep link support and cleaner navigation | `main.dart` |
| AU3-04 | P2 | [x] | Create ARB/l10n structure so app is i18n-ready (add `AppStrings` class as starting point) | New `lib/l10n/` |
| AU3-05 | P2 | [~] | Move investment type metadata to a registry pattern instead of hardcoded Map | `dashboard_action_sheet.dart:91–105` |
| AU3-06 | P3 | [x] | Add remote config stub (even if local JSON) for feature flags and A/B toggles | New `lib/services/remote_config_service.dart` |

---

## AU4 — PERFORMANCE (Rebuilds, caching, list rendering)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU4-01 | P1 | [x] | Fix filter/sort cache: invalidate `_cachedSortedList` when `InvestmentsController` notifies | `investments_screen.dart:76–78` |
| AU4-02 | P1 | [x] | Remove `SharedPreferences.getInstance()` call from screen init; use controller's cached `_prefs` | `investments_screen.dart:112–128` |
| AU4-03 | P2 | [~] | Move gold price future into `InvestmentsController.goldPrice` field so it's shared across screens | `investments_screen.dart:88–89` |
| AU4-04 | P2 | [~] | Replace `Consumer<T>` with `Selector<T, SubType>` in high-rebuild-frequency screens (dashboard, investments list) | `main.dart`, `investments_screen.dart` |
| AU4-05 | P2 | [x] | Limit `ImageFilter.blur` usage to one layer per screen; avoid stacking multiple blurs | Dashboard, modal overlays |
| AU4-06 | P3 | [x] | Run `dart fix --apply` for `prefer_const_constructors` across entire lib | All files |

---

## AU5 — SECURITY (Encryption, PII, PIN storage, exports)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU5-01 | **P0** | [x] | Migrate PIN hash storage from `SharedPreferences` to `flutter_secure_storage` (Android Keystore / iOS Keychain) | `settings_controller.dart:26,63` |
| AU5-02 | **P0** | [~] | Migrate backup encryption key from hardcoded bytes to PBKDF2-derived key from user's backup password | `backup_restore_service.dart:99–125` |
| AU5-03 | P1 | [x] | Implement full offline PIN recovery system (see Part C of this document) | New `lib/ui/pin_recovery_screen.dart` |
| AU5-04 | P1 | [x] | Auto-clear clipboard 30 seconds after card number copy | `accounts_screen.dart` |
| AU5-05 | P2 | [x] | Redact amounts/account numbers before any `logger.info/debug` call in SMS parser | `sms_parser.dart` |
| AU5-06 | P2 | [x] | Delete exported file from app storage after `Share.shareXFiles` completes | All export handlers |
| AU5-07 | P3 | [x] | Strip all PII fields before log output in production mode (`kReleaseMode` check) | `utils/logger.dart` |

---

## AU6 — OPTIMIZATION (Memoization, selector, redundant reads)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU6-01 | P1 | [x] | Memoize `getTotalInvestmentAmount()` with dirty flag — recompute only when list changes | `investments_controller.dart` |
| AU6-02 | P1 | [x] | Cache `_visibleWidgets` list in `DashboardController`, invalidate only on config change | `dashboard_controller.dart` |
| AU6-03 | P2 | [x] | Debounce `notifyListeners()` in `TransactionsController` for batch add operations (SMS import) | `transactions_controller.dart` |
| AU6-04 | P2 | [~] | Move sort/filter preferences into `SettingsController` so no per-screen `SharedPreferences` reads | `investments_screen.dart`, `archive_screen.dart` |
| AU6-05 | P3 | [~] | Audit `ReorderableListView` in dashboard — cap visible widgets to 12, paginate if more | `main.dart:970` |

---

## AU7 — PIPELINE (Page connections, navigation, data refresh)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU7-01 | P1 | [x] | After investment detail edit pop, call `InvestmentsController.load()` to refresh list | All investment detail screens |
| AU7-02 | P1 | [x] | Fix `TransferWizard` navigation: use `Navigator.push` not `pushReplacement` so back returns to wizard branch | `transaction_wizard.dart` |
| AU7-03 | P2 | [x] | Add `PageStorageKey` to all `ListView.builder` — restore scroll position on back navigate | All major list screens |
| AU7-04 | P2 | [x] | Audit all `CupertinoNavigationBar` — ensure `previousPageTitle: 'Back'` set everywhere | All screens |
| AU7-05 | P2 | [x] | Add `PopScope(canPop: false)` on lock screen to prevent back gesture bypass | `main.dart` |
| AU7-06 | P3 | [x] | Ensure notifications page uses `Navigator.push` not `pushReplacement` so back returns to notifications | `notifications_page.dart` |

---

## AU8 — UX (Micro-interactions, loading, error, undo)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU8-01 | P1 | [x] | Add `CupertinoActivityIndicator` spinner while wizard computes maturity/interest/TDS | FD/RD/MF/Stock wizards |
| AU8-02 | P1 | [x] | Add inline form validation — red border + error text on `onChanged`, not just on submit | All wizard amount/date steps |
| AU8-03 | P1 | [x] | Add undo toast (4s) when deleting a transaction (matches goal-delete pattern already done) | `transaction_history_screen.dart`, `transactions_archive_screen.dart` |
| AU8-04 | P2 | [x] | Audit every `BouncyButton` — ensure `Haptics.light()` on all interactive elements | All screens |
| AU8-05 | P2 | [x] | Add long-press on investment card → "Pin to top / Share P&L" action | `investments_screen.dart` |
| AU8-06 | P2 | [x] | Add color picker (8 preset swatches) to tag creation | `category_creation_modal.dart` (or tags modal) |
| AU8-07 | P3 | [~] | Add "Not now" / "Remind me later" option to all suggestion prompts | Onboarding, notification prompts |
| AU8-08 | P1 | [x] | Account detail: replace "last 5 transactions + Export" with "View All Transactions" button that opens filtered full transaction history for that account | `lib/ui/manage/accounts_screen.dart` |

---

## AU9 — UI (Visual consistency, card styles, buttons, modals)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU9-01 | P1 | [x] | Enforce `AppStyles.cardDecoration(context)` on ALL bottom sheets — remove raw `Container` styling | All modal/sheet widgets |
| AU9-02 | P1 | [x] | Set `border: null` globally in `CupertinoThemeData` nav bar override in `main.dart` | `main.dart` ThemeData |
| AU9-03 | P2 | [~] | Audit all 11 investment detail screens — standardize card padding, section header style, divider placement | All `*_details_screen.dart` files |
| AU9-04 | P2 | [~] | Enforce `AppStyles.headerStyle(context)` for all section headers — remove any `Text` with hardcoded style | All screens |
| AU9-05 | P3 | [~] | Create 5–6 reusable SVG/Lottie empty-state illustrations (no items, no data, locked, etc.) | New `assets/illustrations/` |
| AU9-06 | P3 | [x] | Create unified `AppButton` component (primary, secondary, destructive, ghost variants) | New `lib/ui/widgets/app_button.dart` |

---

## AU10 — COLORS (Theme consistency, hardcoded values, contrast)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU10-01 | P1 | [~] | Replace `Colors.white` with `AppStyles.getTextColor(context)` or `AppStyles.darkText` — ~86 files | Grep: `Colors.white` |
| AU10-02 | P1 | [x] | Replace `Colors.black` (backgrounds/text) with theme-aware equivalents | Grep: `Colors.black` |
| AU10-03 | P1 | [x] | Verify WCAG AA contrast ratio for light mode: `lightText` (0xFF0C1E3A) on `lightBackground` (0xFFF2F6FF) | `app_styles.dart` |
| AU10-04 | P2 | [x] | Add `AppStyles.disabledColor(context)` returning theme-aware grey for all disabled states | `app_styles.dart` |
| AU10-05 | P2 | [x] | Add semantic color aliases: `AppStyles.successColor`, `AppStyles.errorColor`, `AppStyles.warningColor`, `AppStyles.primaryAction` | `app_styles.dart` |
| AU10-06 | P3 | [~] | Audit all hardcoded hex colors inline (e.g., `Color(0xFF1C1C1E)`) — replace with token or AppStyles | Grep: `Color(0xFF` |

---

## AU11 — SIZE (Responsive layout, overflow, text scaling)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU11-01 | P1 | [x] | Fix PIN numpad: `width: 80, height: 80` → `min(80, MediaQuery.of(context).size.width / 5.5)` | `main.dart:493–495`, lock screen |
| AU11-02 | P1 | [x] | Add `overflow: TextOverflow.ellipsis, maxLines: 1` to ALL list item title/subtitle Text widgets | Grep: list item Text widgets |
| AU11-03 | P2 | [x] | Wrap bottom sheet modal content in `ConstrainedBox(constraints: BoxConstraints(maxWidth: 600))` + center for tablet landscape | All bottom sheets |
| AU11-04 | P2 | [x] | Replace fixed-height dashboard chart containers with `AspectRatio` or `LayoutBuilder` | Dashboard chart widgets |
| AU11-05 | P3 | [~] | Add Flutter golden screenshot tests at 3 screen sizes (small 375pt, standard 390pt, large 430pt) | New `/test/golden/` |

---

## AU12 — ANIMATIONS (Controllers, curves, performance, jank)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU12-01 | P1 | [x] | Remove individual `AnimationController` fallback from skeleton loaders — replaced with `TweenAnimationBuilder` | `common_widgets.dart` |
| AU12-02 | P2 | [x] | Create `AppCurves` token class: `standard`, `enter`, `exit`, `spring` — enforce across all transitions | New `lib/ui/styles/app_curves.dart` |
| AU12-03 | P2 | [~] | Stagger list item entrance animations: `delay = min(index * 40ms, 300ms)` cap | `investments_screen.dart`, `accounts_screen.dart` |
| AU12-04 | P2 | [~] | Use `CupertinoPageRoute` for drill-down navigation; reserve `FadeScalePageRoute` for root modals only | Navigation throughout app |
| AU12-05 | P3 | [x] | Replace `BouncyButton` linear scale tween with `SpringSimulation` for tactile physical feel | `lib/ui/widgets/animations.dart` |

---

## AU13 — ENGAGING (Delight, charts, celebrations, motivation)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU13-01 | P1 | [x] | Add colored P&L badge (green/red pill) + 7-day mini sparkline to each investment list card | `investments_screen.dart` investment card builder |
| AU13-02 | P1 | [x] | Add dynamic motivational copy to net worth page: "Up ₹12K this month 🔥" / "Down ₹3K — let's recover" | `net_worth_page.dart` |
| AU13-03 | P2 | [x] | Add circular arc progress indicator on goals (replace percentage text with animated arc) | `goals_screen.dart` |
| AU13-04 | P2 | [x] | Animate budget bar fill on screen load + add shake animation when >100% | `budgets_screen.dart` |
| AU13-05 | P2 | [x] | Add "logging streak" counter (consecutive days with transactions) — show on dashboard or profile | New `lib/logic/streak_calculator.dart` |
| AU13-06 | P3 | [x] | Add Financial Health Score widget (0–100): savings rate + budget adherence + investment diversity + debt ratio | New dashboard widget `FT1-07` |

---

## AU14 — NON-TECHIE USER (Jargon, guidance, tooltips, error messages)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU14-01 | P1 | [x] | Add `ⓘ` info icon with tooltip popup for every financial jargon term (PRAN, ISIN, Greeks, PAN, Drawdown, CAGR, XIRR, NAV, TDS, HRA, 80C) | NPS/F&O/Bonds/MF/FD/RD wizards |
| AU14-02 | P1 | [~] | Add example hint text to every wizard field: "e.g., ₹10,000 for 1 year at 7.5%" | All wizard text fields |
| AU14-03 | P2 | [x] | Create `UserErrorMapper` class — map all exception types to friendly user-facing copy | New `lib/utils/user_error_mapper.dart` |
| AU14-04 | P2 | [x] | SMS review screen: show result summary card "Found 12 transactions — 3 unrecognized" after scan | `sms_review_screen.dart` |
| AU14-05 | P2 | [x] | Add one-line description under each investment type in wizard type selector | `dashboard_action_sheet.dart` investmentType page |
| AU14-06 | P3 | [x] | Add short educational tooltips on first-time use of each major feature (show once, store seen state) | Key screens |

---

## AU15 — OUTPUT FORMATTING (Numbers, dates, percentages, empty states)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU15-01 | P1 | [x] | Create `NumberFormatter.percent(double, {int decimals = 2})` and use everywhere percentages show | `lib/utils/number_formatter.dart` (new or extend existing) |
| AU15-02 | P1 | [x] | Create `DateFormatter.display(DateTime)` returning "15 Mar 2026" consistently — replace all ad hoc date strings | `lib/utils/date_formatter.dart` |
| AU15-03 | P1 | [x] | Standardize negative amounts to always `-₹100` format in `CurrencyFormatter` | `lib/utils/currency_formatter.dart` |
| AU15-04 | P2 | [x] | Show "—" or styled "₹0" with sub-label for zero balances instead of "₹0.00" | All balance display widgets |
| AU15-05 | P2 | [x] | Always use `CurrencyFormatter.compact()` in card headings; full format only in detail views | All card/list heading amounts |
| AU15-06 | P3 | [x] | Normalize ALL-CAPS merchant names from SMS to Title Case on import | `sms_parser.dart` merchant extraction |

---

## AU16 — AI MODEL PERSPECTIVE (Data structure for ML/AI features)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU16-01 | P1 | [x] | Build `MerchantNormalizer` — fuzzy dedup on insert, store canonical merchant name | New `lib/utils/merchant_normalizer.dart` |
| AU16-02 | P1 | [x] | Add optional `parentCategoryId` field to `Category` model for hierarchical categories | `lib/logic/category_model.dart` (or wherever defined) |
| AU16-03 | P2 | [x] | Add `derived_metadata` JSON column to transactions table — background-computed: recurrence score, merchant frequency, amount percentile | `transaction_model.dart`, SQLite schema |
| AU16-04 | P2 | [x] | Add `AnomalyDetectorService` — flag transactions ±2σ from merchant mean, show subtle badge | New `lib/services/anomaly_detector.dart` |
| AU16-05 | P3 | [~] | Add nightly `ValuationSnapshotJob` for investments — store current prices for XIRR/trend charts | New `lib/services/valuation_snapshot_service.dart` |
| AU16-06 | P3 | [x] | Expose `TransactionsController.filter(dateRange, category, minAmount, maxAmount, merchant)` unified method for future NL query integration | `transactions_controller.dart` |

---

## AU17 — PIPELINE INTEGRITY (Missing connections found in deep dive)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU17-01 | P1 | [x] | Verify every `showCupertinoModalPopup` that edits data calls `setState` or controller refresh after pop | All modal call sites |
| AU17-02 | P1 | [x] | Add `Navigator.canPop(context)` guard before every `Navigator.pop(context)` call | All pop call sites |
| AU17-03 | P2 | [x] | After successful SMS import, auto-refresh transaction history and account balances | `sms_review_screen.dart` |
| AU17-04 | P2 | [x] | Ensure backup restore flow reloads ALL controllers after import completes | `backup_restore_service.dart` / `backup_restore_screen.dart` |
| AU17-05 | P3 | [x] | Add `PopScope` / `WillPopScope` on lock screen to prevent back-gesture bypassing lock | Lock screen widget in `main.dart` |

---

## AU18 — ACCESSIBILITY (A11y — an extra dimension added)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU18-01 | P1 | [x] | Add `Semantics` labels to all icon-only buttons (FAB, nav icons, close buttons) | All icon buttons |
| AU18-02 | P1 | [x] | Ensure color is never the ONLY way information is conveyed (P&L: add +/- prefix, not just green/red) | Investment P&L display, budget bars |
| AU18-03 | P2 | [x] | Add `excludeSemantics: true` on decorative widgets (particles, background gradients) | `animated_gradient_background.dart`, particle overlay |
| AU18-04 | P2 | [~] | Test with system font size at 1.3x (largest) — ensure no overflow or clipped text | All screens |
| AU18-05 | P3 | [~] | Add screen reader (TalkBack/VoiceOver) traversal order via `FocusTraversalGroup` on complex cards | Dashboard widget cards, investment cards |

---

## AU19 — DATA INTEGRITY (Consistency, edge cases — extra dimension)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU19-01 | P1 | [x] | If account is deleted, mark all linked transactions with `accountDeleted: true` in metadata (not orphan them) | `accounts_controller.dart` delete handler |
| AU19-02 | P1 | [~] | If investment type changes (edit), migrate all existing transactions linked to old type | Investment edit screens |
| AU19-03 | P2 | [x] | Add data integrity check on app startup: detect orphaned transactions (no valid accountId) | New `lib/services/integrity_check_service.dart` |
| AU19-04 | P2 | [~] | Add FD/RD: if linked account is deleted, show warning badge on investment card | FD/RD detail screens |
| AU19-05 | P3 | [~] | Periodic "your data health" notification: "3 transactions have unlinked accounts" | `alert_service.dart` |

---

## AU20 — ONBOARDING & FIRST-RUN (Extra dimension)

| ID | P | Status | Task | File / Location |
|----|---|--------|------|-----------------|
| AU20-01 | P1 | [~] | Add "Quick Setup" mode: create first account in under 30 seconds during onboarding | `onboarding_screen.dart` |
| AU20-02 | P1 | [x] | Show "What's new" sheet on first launch after app update (version-gated) | `main.dart` after splash |
| AU20-03 | P2 | [~] | Feature discovery tooltips on first use: highlight FAB, swipe-to-delete, long-press (show once each) | Key interaction points |
| AU20-04 | P2 | [~] | Onboarding page showing all 5 Quick Add options with animated demo | `onboarding_screen.dart` |
| AU20-05 | P3 | [~] | Add "Import from other apps" option in onboarding (CSV import of transactions) | Onboarding / data import screen |

---

# PART B — NEW FEATURES

## TIER 1 — High impact, moderate effort (build these next)

| ID | Status | Feature | Description | Where |
|----|--------|---------|-------------|-------|
| FT1-01 | [x] | **Financial Calendar** | Single calendar view: all SIP dates, FD maturities, EMI dues, bill reminders, goal deadlines. Month + agenda view. | New tab in Notifications OR new screen in Manage |
| FT1-02 | [x] | **Loan / EMI Tracker** | Replace dead Liabilities section. Track: principal, interest rate, tenure, EMI schedule, pre-payment impact, outstanding balance. Monthly amortization table. | `lib/ui/manage/loans/loan_tracker_screen.dart` |
| FT1-03 | [x] | **Insurance Tracker** | Track health/life/vehicle/term insurance: premium amount, payment frequency, renewal date, sum insured, nominee, insurer. Alert 30 days before renewal. | `lib/ui/manage/insurance/` new section |
| FT1-04 | [x] | **Bill Splitting** | Log shared expense, add contacts, split equally or custom %, track "owes you / you owe" balance. Settle with a tap (marks as paid). | `lib/ui/manage/lending/bill_split_screen.dart` |
| FT1-05 | [~] | **Receipt OCR** | Camera scan of receipt → auto-fill amount, merchant, date in transaction wizard. Use `google_ml_kit` text recognition. | Camera icon in transaction wizard step 1 |
| FT1-06 | [x] | **Spending Forecast** | "At this rate you'll spend ₹18,400 by month end" — based on daily avg × remaining days. Show on dashboard as warning widget. | Dashboard widget + `TransactionsController` |
| FT1-07 | [x] | **Financial Health Score** | 0–100 computed score: savings rate (25pts) + budget adherence (25pts) + investment diversity (25pts) + debt-to-income ratio (25pts). Trend arrow. | Dashboard widget + `lib/logic/health_score_calculator.dart` |

## TIER 2 — Moderate impact, higher effort

| ID | Status | Feature | Description |
|----|--------|---------|-------------|
| FT2-01 | [x] | **Tax Summary Dashboard** | Annual 80C usage (NPS/ELSS/LIC/PPF), capital gains (STCG/LTCG), HRA calculation. `tax_summary_screen.dart` exists — implement it. |
| FT2-02 | [~] | **Android / iOS Home Screen Widget** | Show today spend vs budget OR net worth change on home screen widget. Requires `home_widget` package. |
| FT2-03 | [x] | **CSV Transaction Import** | Import bank statement CSV → parse into transactions. Auto-map columns. Duplicate detection. |
| FT2-04 | [x] | **Multi-currency Support** | Add `currency` field to `Account` model. Auto-convert using cached exchange rates. Useful for forex/NRI accounts. |
| FT2-05 | [x] | **Spending Insights Cards** | Weekly/monthly auto-generated insight cards: "You spent 30% more on dining this month" — swipeable cards on dashboard. |
| FT2-06 | [~] | **Family / Shared Mode** | Multiple profiles on same device. Shared budget visibility. Profile switcher in app menu. |

## TIER 3 — Low priority / advanced

| ID | Status | Feature | Description |
|----|--------|---------|-------------|
| FT3-01 | [~] | Siri/Google Shortcuts | "Hey Siri, log ₹200 at Starbucks" → opens transaction wizard pre-filled |
| FT3-02 | [~] | Credit Score Tracker | Link to free CIBIL/Experian API, track score history chart |
| FT3-03 | [~] | Anomaly Detection Alerts | AnomalyDetectorService built (`lib/services/anomaly_detector.dart`); notification wiring deferred — no alert notification infrastructure to hook into |
| FT3-04 | [~] | Natural Language Filter | "Show all dining expenses over ₹500 last month" → parsed filter |
| FT3-05 | [~] | Investment Valuation Snapshots | Nightly price snapshot for XIRR calculation and trend sparklines |

---

# PART C — PIN / BIOMETRIC RECOVERY (Offline, No Server)

## The Problem
User sets 6-digit PIN. They forget it. Biometric also unavailable (new phone, Face ID failed,
injury). App is 100% device-local — no server, no account, no cloud reset.
User is locked out of all their financial data.

## Solution Design: Three-Layer Recovery

### Layer 1 — Emergency Recovery Code (Primary)
Modelled after 1Password Emergency Kit and hardware wallet seed phrases.

**Setup flow (when user enables PIN):**
1. Generate 32 random bytes using `dart:math.Random.secure()`
2. Format as `VFOS-XXXX-XXXX-XXXX-XXXX` (5 groups of 4 alphanumeric, uppercase)
3. Store `SHA-256(recovery_code)` in `flutter_secure_storage` (NOT SharedPreferences)
4. Show a full-screen "Save Your Recovery Code" modal:
   - Display the code large, clearly formatted
   - "Screenshot this or write it on paper and store safely"
   - "This is shown ONLY ONCE and cannot be retrieved again"
   - Two buttons: [Copy to Clipboard] [I've saved it — Continue]
5. After 7 days, show a reminder banner: "Did you save your recovery code? View it here"
   - Allow viewing recovery code once more only after biometric/PIN auth
   - After second view, never show reminder again

**Recovery flow:**
1. On lock screen: small "Forgot PIN?" link at the bottom
2. Taps → "Enter Recovery Code" screen with 20-character input (VFOS-XXXX-XXXX-XXXX-XXXX)
3. SHA-256 the input, compare to stored hash
4. Match → "Set New PIN" screen — data is 100% preserved
5. New PIN set → generate NEW recovery code → show setup flow again
6. No match → show error "Invalid code. Check for typos." (rate-limited: 3 attempts, then 5-minute lockout)

**Implementation files:**
- `lib/logic/pin_recovery_controller.dart` — generate, store, verify recovery code
- `lib/ui/pin_recovery_screen.dart` — "Enter recovery code" UI
- `lib/ui/recovery_code_save_screen.dart` — full-screen "save your code" after PIN setup
- `settings_controller.dart` — call `PinRecoveryController.generateCode()` after `setPin()`

### Layer 2 — Backup File Recovery (Secondary)
If recovery code is also lost, user can recover data via their backup:
1. "Forgot PIN?" → "I don't have my recovery code" → "Do you have a backup file?"
2. User provides backup file
3. App verifies backup integrity (HMAC check)
4. If valid: "This will reset your PIN and restore your data from backup"
5. Confirm → wipe local DB → restore from backup → set new PIN

Note: backup encryption password must be different from PIN for this to work as recovery.
If user used same backup password as PIN (and forgot both), they need Layer 3.

### Layer 3 — Nuclear Reset (Last Resort)
1. "Forgot PIN?" → "No recovery code" → "No backup" → "Erase Everything"
2. Triple-confirm:
   - Screen 1: "This will permanently delete all your data. This cannot be undone."
   - Screen 2: Type "DELETE MY DATA" manually (not a button)
   - Screen 3: Wait 10-second countdown with cancel option
3. Execute: clear SQLite DB, clear all SharedPreferences, clear flutter_secure_storage
4. Launch onboarding as if fresh install

### Additional Safeguards
- Rate limiting: 5 wrong PIN attempts → 1-minute lockout, exponential back-off (1, 2, 5, 15 min)
- Log wrong PIN attempt count in secure storage (not bypassable by app reinstall without wiping device)
- Recovery code shown in settings "Security → View Recovery Code" (requires current PIN/biometric to view)
- Export recovery code as PDF (same as 1Password Emergency Kit concept)

### Implementation Priority
| ID | P | Status | Task |
|----|---|--------|------|
| AU5-03a | P0 | [x] | `PinRecoveryController` — generate/store/verify recovery code using `flutter_secure_storage` |
| AU5-03b | P0 | [x] | `RecoveryCodeSaveScreen` — full-screen show-once recovery code display |
| AU5-03c | P1 | [x] | `PinRecoveryScreen` — enter recovery code to reset PIN |
| AU5-03d | P1 | [x] | Rate limiting on wrong PIN attempts (exponential back-off) |
| AU5-03e | P1 | [x] | Layer 3 nuclear reset with triple-confirm and 10s countdown |
| AU5-03f | P2 | [x] | "View recovery code" in Settings → Security (requires auth) |
| AU5-03g | P3 | [~] | Export recovery code as PDF / "Emergency Kit" |

---

# PART D — MERGE CANDIDATES

| ID | Status | Merge | Why |
|----|--------|-------|-----|
| MG-01 | [~] | **FD Wizard + RD Wizard** → Unified "Deposit Wizard" | 80% identical steps. Add "type" selection at step 1. Half the maintenance. |
| MG-02 | [~] | **Crypto + Digital Gold detail screens** → "Alternative Assets" | Both track price × quantity. Same detail layout. Different icons only. |
| MG-03 | [~] | **Archive Screen + Transaction History** | Archive is a filter, not a separate concept. Add "Archived" toggle/tab to History. Remove standalone archive screen. |
| MG-04 | [~] | **Notifications page + Actions widget** | FD maturity shows in both. One "Alerts & Actions" screen is cleaner. |
| MG-05 | [~] | **Banks screen + Accounts screen** | Banks only exist as metadata for accounts. Make Banks a sub-section inside Account creation, not a standalone screen. |
| MG-06 | [~] | **Goals contributions + Savings Rate widget** | Savings rate widget on dashboard duplicates what goals already show. Merge into goals page. |
| MG-07 | [~] | **App Menu Screen + Manage Screen** | App menu appears to duplicate navigation options already in Manage. Consolidate. |

---

# PART E — REMOVE CANDIDATES

| ID | Status | Remove | Reason | Alternative |
|----|--------|--------|--------|-------------|
| RM-01 | [x] | **Liabilities "Coming Soon" badge** | Dead navigation since session 2 — creates user confusion | Replace with working Loan/EMI Tracker (FT1-02) |
| RM-02 | [~] | **Forex / Currency investment type** | Extremely niche, no exchange rate integration, >99% users never use it | Move to "Other Assets" catch-all type |
| RM-03 | [~] | **F&O (Futures & Options)** | Requires Greeks/Theta/expiry — beyond scope of personal finance tracker | Gate behind "Advanced Mode" toggle in Settings, or move to "Other Assets" |
| RM-04 | [~] | **Payment Apps screen** | Shows list of apps but does nothing — no data, no tracking, no link | Remove OR replace with actual UPI deep-link shortcuts |
| RM-05 | [x] | **Dead `tax_summary_screen.dart`** | File exists but appears empty/placeholder | Fully implemented: 463 lines, FY selector, 80C, capital gains, all tax sections |
| RM-06 | [~] | **Savings rate dashboard widget** | Duplicates goals contribution data. Confusing to have both. | Keep goals, remove savings rate widget OR merge data |

---

# PART F — EXECUTION ORDER (Suggested Batches)

## Batch 1 — SECURITY & RECOVERY (Most critical, do first)
AU5-01, AU5-02, AU5-03a→g (full PIN recovery system), AU5-04, AU5-05, AU5-06

## Batch 2 — CRITICAL BUGS & DATA
AU4-01, AU2-03, AU7-02, AU19-01, AU19-02, AU17-02

## Batch 3 — OUTPUT FORMATTING (High user visibility)
AU15-01, AU15-02, AU15-03, AU15-04, AU15-05, AU15-06

## Batch 4 — UX IMPROVEMENTS
AU8-01, AU8-02, AU8-03, AU1-04, AU1-06, AU8-04

## Batch 5 — VISUAL POLISH (Colors + UI)
AU10-01, AU10-02, AU10-03, AU10-04, AU10-05, AU9-01, AU9-02, AU9-04

## Batch 6 — FEATURES TIER 1
FT1-01 (Financial Calendar), FT1-02 (Loan/EMI Tracker), FT1-07 (Health Score), FT1-06 (Forecast)

## Batch 7 — ENGAGING + ANIMATIONS
AU13-01, AU13-02, AU13-03, AU13-04, AU12-02, AU12-03, AU12-05

## Batch 8 — NON-TECHIE + ACCESSIBILITY
AU14-01, AU14-02, AU14-03, AU18-01, AU18-02

## Batch 9 — MERGE + REMOVE
MG-01→07, RM-01→06

## Batch 10 — PERFORMANCE + OPTIMIZATION
AU4-03, AU4-04, AU6-01, AU6-02, AU6-03

## Batch 11 — FEATURES TIER 2
FT2-01 (Tax Summary), FT2-03 (CSV Import), FT2-05 (Insights Cards)

## Batch 12 — DEVELOPER SIDE (Refactor)
AU2-01, AU2-02, AU2-04, AU2-05, AU2-06, AU2-07, AU2-09

## Batch 13 — FUTURE-PROOF + AI
AU3-01, AU3-02, AU16-01, AU16-02, AU16-03, AU16-04

---

# PART G — COMPLETED TASKS LOG
(Moved here when done — never delete, just mark [x] above)

## Sessions 1–7 (pre-audit) — all done, logged in MEMORY.md
## Session 8 (2026-03-15):
- [x] SMS Scanning toggle in Settings (default OFF) — gates startup scan, FAB button, _SmsSectionWidget
- [x] Investment Tracking toggle → gates Investment/Dividend in Quick Add
- [x] Onboarding Get Started / Skip navigation fixed (threaded BuildContext)
- [x] Transaction wizard step-0 flash fixed (PageController initialPage)
- [x] SmoothScrollPhysics + cacheExtent on all large list screens
- [x] All CSV/PDF/Excel exports now share via system share sheet
- [x] Account details sheet: recent transactions + per-account CSV export
- [x] Investment item tap → Add/Sell/Details action sheet


## Session 9 (2026-03-16):
- [x] AU8-02: tx wizard amount field onChanged clears error immediately
- [x] AU1-08: Skip button "Optional — you can add this later" hint text
- [x] AU11-01: PIN numpad responsive size clamp(56,80)
- [x] AU8-01: Already done (all wizards had spinners)
- [x] AU8-04: Already done (BouncyButton has haptics by default)
- [x] AU9-01: AppStyles.bottomSheetDecoration() added; applied to accounts modal, tx filter sheet, maturity calendar
- [x] AU9-02: border:null on all 20+ CupertinoNavigationBar instances
- [x] AU10-04/05: successColor, errorColor, warningColor, primaryAction, disabledColor(context) added to AppStyles
- [x] AU11-02: maxLines:1 + ellipsis on account/investment list item names
- [x] AU13-02: Motivational banner on Net Worth page (month-over-month delta)
- [x] AU13-03: Circular arc progress (CustomPainter + TweenAnimationBuilder) on Goals cards
- [x] AU13-04: ShakingBudgetBar shakes on load when budget exceeded
- [x] AU14-01: JargonTooltip widget (PRAN, NAV, CAGR, TDS, XIRR, ISIN, Greeks, Drawdown, 80C, SIP Date) — wired into NPS, FD details, investments, MF details
- [x] AU1-04: "Discard changes?" dialog in tx wizard on back with unsaved data


---

*This document is the single source of truth. Update it every session.*
*Total tasks: ~130 audit items + 18 features + 7 merges + 6 removes + 7 PIN recovery = ~168 items*
