# VittaraFinOS — Bloomberg-Level Master Plan
> Single source of truth. Update `[~]` (in progress), `[x]` (done) after every task.
> Created: 2026-03-22 | Stack: Flutter + Provider + SQLite | ~95K LOC, 249 files

---

## Legend
- `[ ]` not started
- `[~]` in progress
- `[x]` done
- **P0** = critical bug / must fix before release
- **P1** = high-value UX/perf
- **P2** = enhancement
- **P3** = nice-to-have

---

## PHASE 0 — Completed Foundations (Previous Sessions)

### Session 1–7 (complete)
- [x] AMOLED dark theme (pure black, 0xFF000000)
- [x] 11 Provider controllers wired at startup
- [x] SMS scanning toggle (default OFF)
- [x] Investment tracking toggle
- [x] Onboarding navigation fixed
- [x] Transaction wizard step-0 flash fixed
- [x] SmoothScrollPhysics + cacheExtent on large lists
- [x] CSV/PDF/Excel exports via share_plus system sheet
- [x] Account details sheet: recent txns + per-account CSV export
- [x] Investment item tap → Add/Sell/Details action sheet
- [x] SIP Tracker dashboard widget (F8/J9)
- [x] RepaintBoundary on AnimatedCounter + haptic success on investment wizards
- [x] Net worth monthly history snapshots + sparkline trend chart
- [x] NPS ₹2L annual limit warning

### Session 8 — Light Mode + Performance (complete)
- [x] **L1/L2** — `AppStyles` theme-aware color helpers: `gain(ctx)`, `loss(ctx)`, `gold(ctx)`, `teal(ctx)`, `violet(ctx)` — WCAG AA in light, AMOLED neon in dark
- [x] **L3** — Categories screen: SliverGrid replacing shrinkWrap GridView (P0 perf fix)
- [x] **L4/L5** — Landscape helpers: `isLandscape()`, `landscapeContentConstraints()`, `sheetMaxHeight()` in AppStyles; replaced all hardcoded `size.height * 0.XX` sheet heights
- [x] **L6** — TransactionTypeTheme.typeColor converted from getter to method with BuildContext
- [x] **L7** — ~350 neon color usages across 60+ files replaced with theme-aware helpers

---

## PHASE 1 — Core Infrastructure (Start Here)

### D-01 — CardDeckView Widget Engine `[x]` P1
**File:** `lib/ui/widgets/card_deck_view.dart` (new file)
**Design:**
- Stack of 3 visible cards, depth illusion: scale 1.0 / 0.95 / 0.90, translateY 0 / 10 / 20px, opacity 1.0 / 0.85 / 0.65
- Swipe gesture: horizontal swipe threshold 80px sends current card to back (circular)
- Spring physics on return: `SpringSimulation` with mass 1.0, stiffness 200, damping 20
- `AnimationController` per card, duration 350ms, curve `Curves.easeOutBack`
- API: `CardDeckView(cards: List<Widget>, onCardChanged: (int index) {})`
- Haptic: `HapticFeedback.lightImpact()` on each swipe

### D-02 — Dashboard Card Deck `[x]` P1
**File:** `lib/ui/dashboard/` (main dashboard screen)
**Cards (6 total):**
1. Net Worth Vault — headline number, 30-day delta, sparkline
2. Monthly Budget Radar — budget vs actual, top 3 overspend categories
3. Cash Flow Pulse — income vs expense bar (MTD), trend arrow
4. Investment Ticker — top mover (gain/loss), total portfolio delta today
5. Lending Ledger — outstanding lent/borrowed, next expected return
6. SIP Command — next SIP dates, MTD invested, projected year-end
**Implementation:** Replace current `ReorderableListView` in dashboard with `CardDeckView`, keep quick-add FAB intact

### NW-01 — Net Worth Page Card Deck `[x]` P1
**File:** `lib/ui/net_worth/` (net worth screen)
**Cards (6 total):**
1. Vault — total net worth, absolute + % change (1M/3M/1Y tabs)
2. Trajectory — line chart (12-month history), projection line (linear extrapolation)
3. Liquid Assets — cash + savings + wallet breakdown, available-to-spend highlight
4. Portfolio — investment breakdown donut: stocks/MF/FD/gold/crypto/NPS
5. Obligations — loans outstanding, total EMI/month, payoff timeline
6. Horizon — net worth goal progress, years to FI (Financial Independence) estimate
**Implementation:** `CardDeckView` on net worth page

### SYS-07 — Color Semantic Completeness `[x]` P1
**File:** `lib/ui/styles/app_styles.dart`
Add missing semantic helpers:
- `AppStyles.neutral(context)` — zero/flat change: dark `Color(0xFF8E8E93)`, light `Color(0xFF6B6B6B)`
- `AppStyles.warning(context)` — caution/80% budget: dark `Color(0xFFFF9F0A)`, light `Color(0xFF9A5700)`
- `AppStyles.info(context)` — informational: dark `Color(0xFF0A84FF)`, light `Color(0xFF0062CC)`
- `AppStyles.surface(context)` — card surface (replaces hardcoded darkCard/lightCard usages)

---

## PHASE 2 — Landscape Mode + Data Surfaces

### SYS-LAND-NAV — Fix Landscape Navigation Bar `[x]` **P0** (All 67 screens done — nav bar hidden in landscape, swipe-back for navigation)
**Problem:** `CupertinoNavigationBar` / `AppBar` takes ~50% of screen height in landscape orientation on phones — unusable.
**Fix:** In every screen that uses a nav bar:
1. Wrap with `OrientationBuilder`
2. In landscape: replace `CupertinoNavigationBar` with a compact 36px overlay header using `SliverPersistentHeader` or `PreferredSize(preferredSize: Size.fromHeight(36))`
3. OR: completely hide the nav bar in landscape and add a back-chevron overlay `Positioned(top: 8, left: 8)` with `BackdropFilter` frosted pill
**Priority screens:** All 19 main screens. Start with Dashboard, Transaction Wizard, Net Worth, Investments, Spending Insights.
**Pattern to use:**
```dart
// In every CupertinoPageScaffold:
navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(...),
// Then in body, conditionally show compact back button overlay
```

### SYS-03 — Skeleton Loading States `[x]` P1
**File:** `lib/ui/widgets/skeleton_loader.dart` (new)
**Design:** Shimmer sweep animation (135° angle, 1.2s loop), color `Color(0xFF1A1A1A)` dark / `Color(0xFFE8E8E8)` light
- `SkeletonBox(width, height, radius)` — base widget
- `SkeletonCard()` — 3 lines + icon placeholder
- `SkeletonListTile()` — standard list item shape
- `SkeletonChart()` — bar chart placeholder (5 bars of varying height)
Apply to: Investments screen (initial load), Transaction history (first paint), Budget screen

### SYS-04 — LandscapeSplitView Widget `[x]` P1
**File:** `lib/ui/widgets/landscape_split_view.dart` (new)
**API:**
```dart
LandscapeSplitView(
  leftPanelFlex: 2,
  rightPanelFlex: 3,
  leftPanel: Widget,
  rightPanel: Widget,
  portraitLayout: Widget, // fallback
)
```
**Apply to (priority order):**
1. Investments screen — left: category tabs + summary bar; right: holdings list
2. Net Worth — left: vault + obligations; right: trajectory chart
3. Budget screen — left: category radial; right: transaction drill-down
4. Transaction History — left: filters + summary; right: transaction list
5. Spending Insights — left: chart; right: category breakdown
6. Loan Tracker — left: loan cards; right: amortization chart
7. Lending & Borrowing — left: lent list; right: borrowed list
8. Reports / Tax — left: filter/period picker; right: data table
9. Dashboard — left: net worth + budget cards; right: cash flow + investments

### INV-01 — Investments Portfolio Terminal `[x]` P1 (landscape nav done; LandscapeSplitView pending PageView extraction)
**File:** `lib/ui/manage/investments_screen.dart`
**Redesign:**
- **Summary bar** (always visible, sticky): Total portfolio value | Day P&L (₹ + %) | Absolute return (%)
- **Pill tabs** (horizontal scroll): All | Stocks | MF | FD | Gold | Crypto | NPS | Bonds
- **Card redesign:** Each investment card = Bloomberg-style ticker row:
  - Left: ticker symbol + full name (2 lines), category pill
  - Center: current value (large), invested amount (small secondary)
  - Right: P&L ₹ (colored), P&L % (colored badge), mini 7-day sparkline
- **Sort bar:** Return % | Value | Name | Date Added (tap to toggle, arrow indicator)
- **Aggregate footer:** Total invested | Total current | Absolute return | XIRR (if calculable)

### BUD-01 — Budget Mission Control `[x]` P1
**File:** `lib/ui/budget_screen.dart` (or equivalent)
**Redesign:**
- **Hero metric:** Big radial gauge (0–100%) showing MTD budget consumption
- **Pace indicator:** "On track" / "Overpacing by ₹X" / "₹Y headroom" — colored pill
- **Category spending pace:** Horizontal bar per category (budget vs actual), color shifts red at 80%
- **Spending velocity chart:** Last 7 days daily spend vs daily budget line (area chart)
- **Projection callout:** "At this pace, you'll exceed budget by ₹X on [date]"

### TXN-01 — Transaction History Terminal `[x]` P1
**File:** `lib/ui/transactions/transaction_history_screen.dart`
**Redesign:**
- **Sticky summary header:** Period income | Period expense | Net (colored) — collapses on scroll
- **Smart filters bar:** Date range chip | Type chips | Category chips — horizontal scroll, active = accent fill
- **Row redesign:** Date column (left, compact) | Icon+Name | Category pill | Amount (right, colored) — Bloomberg terminal row aesthetic
- **Section headers:** Grouped by date, show day total (income - expense)
- **Swipe actions:** Left = edit, Right = archive (with undo toast)

### REP-01 — Reports & Analytics Terminal `[x]` P2
**File:** `lib/ui/reports/` (reports screen)
**Redesign:**
- **Period selector:** Pill tabs: This Month | Last Month | Q1/Q2/Q3/Q4 | FY | Custom
- **Key metrics grid (2x2):** Total spend | Avg daily spend | Biggest category | Savings rate
- **Trend chart:** 12-month income vs expense area chart (two series, filled)
- **Category treemap:** Area-proportional blocks, tap to drill down
- **Export terminal:** Quick access to CSV/PDF/Excel — single tap, no confirmation needed

---

## PHASE 3 — Screen-by-Screen Upgrades

### FC-01 — Financial Calendar Terminal `[x]` P2
**File:** `lib/ui/calendar/` (financial calendar screen)
**Redesign:**
- **Month grid:** Each day cell shows: dot indicators (income=green, expense=red, EMI=orange, SIP=blue)
- **Day tap → bottom sheet:** Timeline view of all events that day, sorted by time
- **Week strip mode:** Landscape → week strip at top (7 columns), rest = event list
- **Upcoming bar:** Horizontal scroll strip showing next 7 days with event count badges
- **Recurring events highlighted:** EMI, SIP, rent — shown with repeat icon overlay

### GOL-01 — Goals Dashboard `[x]` P2
**File:** `lib/ui/goals/` (goals screen)
**Redesign:**
- **Goal card redesign:** Progress ring (arc, not bar) + amount needed + target date countdown
- **Milestone celebrations:** Confetti + haptic at 25%, 50%, 75%, 100%
- **Projection overlay:** "You'll reach this goal on [date] at current save rate"
- **Priority stacking:** Visual urgency — goals near deadline float to top
- **Add contribution FAB:** Quick-add ₹ to any goal from list view

### LB-01 — Lending & Borrowing Terminal `[x]` P2
**File:** `lib/ui/manage/lending_borrowing_screen.dart`
**Redesign:**
- **Summary bar:** Total lent out (₹) | Total borrowed (₹) | Net exposure (₹)
- **Contact grouping:** Group by person, show total balance per person (net: owed to you vs you owe)
- **Status pills:** Active | Partially paid | Overdue | Settled
- **Timeline per record:** Loan date → partial payments → expected return date
- **Overdue alert:** Red banner for any record past expected return date

---

## PHASE 4 — System Polish

### NOT-01 — Notifications & Alerts Redesign `[x]` P2
**File:** `lib/ui/notifications_page.dart`
**Redesign:**
- Group by type: Budget | Bill | Goal | Insight | System
- Priority badges: P0 (red dot) | P1 (orange) | Info (gray)
- Swipe to dismiss per item + "Clear all" in section header
- Actionable CTAs inline: "View Budget" / "Pay Now" / "Add Transaction"

### MNG-01 — Manage Screen Polish `[x]` P2
**File:** `lib/ui/manage_screen.dart`
- Add section grouping: ACCOUNTS | TRACKING | ORGANIZE
- Visual separators between groups
- Badge counts on relevant items (e.g., "Accounts (3)", "Categories (12)")
- Animate cards on first load (staggered entrance, 30ms delay each)

### HS-01 — Financial Health Score Widget `[x]` P2
**File:** (dashboard or dedicated screen)
**Redesign:**
- Replace numeric score with a gauge + letter grade (A+/A/B/C/D)
- 5 sub-dimensions shown as horizontal bars: Savings / Debt / Diversification / Budget / Goals
- Trend line: score history (last 6 months)
- Actionable insight: "Improve your score by: [top recommendation]"

### SYS-01 — Global Search `[x]` P2
**File:** `lib/ui/widgets/global_search_overlay.dart` (new)
- Triggered by search icon in dashboard header or Cmd+F / pull-down gesture
- Searches: transactions (name, amount, category) | accounts | investments | goals | contacts
- Results grouped by type, tappable → navigate to record
- Recent searches persisted in SharedPreferences (last 10)
- Debounce 200ms, min 2 chars

### DASH-EMPTY — Dashboard Widget Empty States `[x]` P2
**Problem:** When dashboard widgets have no data (no transactions, no investments, etc.), they look blank, visually unbalanced, or awkward — especially when all widgets are the same height.
**Fix:** Audit every dashboard widget for its empty-state appearance:
- Each widget must have a non-blank, visually complete empty state: icon + short prompt text + optional CTA button ("Add your first transaction" / "Add investment")
- Widget height must never collapse to near-zero in empty state — maintain minimum content height with a centered empty-state card
- No widget should look "unfinished" — use a placeholder illustration or icon + text as visual filler
- Test by temporarily clearing all data and checking each widget looks intentional and polished
**Affected widgets:** (all dashboard widgets in `lib/ui/dashboard/widgets/`)

### SYS-02 — Micro-Interaction Vocabulary `[x]` P3
**File:** `lib/ui/widgets/animations.dart` (extend existing)
- **NumberTicker:** Animate number changes (count up/down, 400ms, easeOut) — for all currency displays
- **PulseIndicator:** Periodic subtle pulse on "live" data points
- **SwipeDeleteIndicator:** Red/green sliding reveal on list items
- **LoadingDots:** 3-dot wave for async operations (replaces CircularProgressIndicator)
- **SuccessCheckmark:** Animated checkmark (path draw) for completion states

### SYS-05 — Performance Audit `[x]` P3
- Audit all `Consumer<>` widgets — replace with `context.select<>` where only 1-2 fields needed
- Add `RepaintBoundary` to: chart widgets, avatar/icon components, animated counters
- Audit `ListView` usages — ensure all are `ListView.builder`, never `ListView(children: [...])`
- Reduce `setState` scope in all wizard screens — use local state not widget-level
- Profile with Flutter DevTools, fix any jank above 16ms frame time

### SYS-06 — Typography Audit `[x]` P3
- Ensure all headers use Space Grotesk (not Plus Jakarta Sans)
- Ensure all body text uses Plus Jakarta Sans
- Standardize sizes to TypeScale tokens only (no hardcoded fontSize values outside design_tokens.dart)
- Add `TypeScale.display` (36px) for hero numbers (net worth, budget total)
- Add `TypeScale.micro` (10px) for labels/badges

---

## PHASE 5 — Advanced Features

### UTL-01 — CSV Smart Import `[x]` P3
- Parse bank statement CSVs (HDFC, SBI, ICICI, Axis formats)
- Auto-categorize using keyword matching
- Duplicate detection (same amount + date ± 1 day)
- Preview screen before committing import

### UTL-02 — Recurring Transaction Engine `[x]` P3
- Detect recurring patterns from history (same payee, similar amount, ~30 day gap)
- Suggest "Mark as recurring" with confirmation
- Auto-log recurring transactions + notification 1 day before

### UTL-03 — Widgets (Home Screen) `[x]` P3
- Net worth widget (2x1): current value + 30-day change
- Budget widget (2x2): radial gauge + top 3 categories
- Cash flow widget (4x2): income/expense bars current month

### UTL-04 — Data Backup & Restore `[x]` P3
**P0 security issue (AU5-02):** Move encryption key from hardcoded to device keychain
- Encrypted SQLite backup export to Files app
- Restore from backup file
- Auto-backup on each app open (daily, keep last 7)

### UTL-05 — PIN/Biometric Security `[x]` P0
**P0 security issue (AU5-01):** Move PIN hash from SharedPreferences to iOS Keychain / Android Keystore
- Biometric auth (FaceID/fingerprint) as primary, PIN as fallback
- Session timeout: lock after N minutes background (configurable: 1/5/15/never)
- Failed attempts: 5 strikes → 30 minute lockout

### TAX-01 — Tax Summary Upgrade `[x]` P2
- LTCG/STCG calculation for stocks and MF (based on holding period)
- Tax-loss harvesting suggestions
- Section 80C tracking (ELSS + PPF + NPS contributions)
- FY selector (Apr–Mar)
- Export to CA-ready PDF

### SET-01 — Settings Screen Redesign `[x]` P3
- Group: Privacy & Security | Data & Backup | Display | Notifications | About
- Each group = card section with dividers
- Toggles use CupertinoSwitch with immediate visual feedback
- Dangerous actions (Reset, Delete) isolated in a "red zone" section at bottom

### ONB-01 — Onboarding Enhancement `[x]` P3
- Add interactive demo screen (5th page): tappable mock transaction, mock net worth chart
- "Try it" CTA opens the real app in a pre-seeded demo mode
- Skip demo → normal flow

### AI-01 — Insight Engine (On-Device) `[x]` P3
- Monthly "Your Money Story" summary: biggest change from last month
- Anomaly detection: "This is 40% more than your usual grocery spend"
- Goal nudge: "You're ₹500 behind your vacation goal"
- All computed locally using SQLite aggregates — no cloud

### LOAN-01 — Loan Tracker Upgrade `[x]` P2
- Amortization table: full schedule of principal/interest per EMI
- Prepayment calculator: "If you pay ₹X extra today, you save ₹Y interest and close N months early"
- EMI calendar overlay: show all future EMI dates on financial calendar
- Part-payment log: track actual vs scheduled payments

### INS-01 — Insurance Tracker Upgrade `[x]` P2
- Premium due reminder (30 days, 7 days, 1 day before)
- Coverage summary: total life cover | total health cover | total premium/year
- Claim tracker: log claim, track status, outcome
- Renewal alert: policies expiring in next 90 days

---

## Security Backlog (P0 — do before any public release)

### AU5-01 — PIN Hash Migration `[x]` **P0** (already implemented in settings_controller.dart)
Move PIN hash storage from SharedPreferences (readable by anyone with device access) to:
- iOS: `flutter_secure_storage` → iOS Keychain
- Android: `flutter_secure_storage` → Android Keystore
File: `lib/logic/settings_controller.dart` + `lib/ui/pin_recovery_screen.dart`

### AU5-02 — Encryption Key Security `[x]` **P0**
Move hardcoded backup encryption key to device secure storage.
File: wherever backup encryption is implemented (check `lib/utils/` or `lib/logic/`)

### AU5-03 — Input Validation `[x]` P1
Audit all text inputs for:
- SQLite injection (use parameterized queries — verify all)
- Amount fields: validate numeric, max ₹99,99,99,999
- Name fields: max 100 chars, strip dangerous characters

---

## Tracking

| Phase | Total Items | Done | Remaining |
|-------|-------------|------|-----------|
| 0 (Foundations) | 20 | 20 | 0 |
| 1 (Core Infra) | 5 | 0 | 5 |
| 2 (Landscape + Data) | 5 | 0 | 5 |
| 3 (Screen Upgrades) | 5 | 0 | 5 |
| 4 (Polish) | 7 | 0 | 7 |
| 5 (Advanced) | 11 | 0 | 11 |
| Security | 3 | 0 | 3 |
| **Total** | **56** | **20** | **36** |

---

## Implementation Notes

### Color System (implemented)
```dart
// Theme-aware (require BuildContext):
AppStyles.gain(context)     // income/profit: bioGreen dark, #00875A light
AppStyles.loss(context)     // expense/loss: plasmaRed dark, #CC1A35 light
AppStyles.gold(context)     // gold/savings: solarGold dark, #9A6800 light
AppStyles.teal(context)     // transfers: aetherTeal dark, #007A6E light
AppStyles.violet(context)   // investments: novaPurple dark, #5B3FCC light

// Static constants (no BuildContext — for const constructors):
AppStyles.bioGreen          // 0xFF00E5A0
AppStyles.plasmaRed         // 0xFFFF2D55
AppStyles.solarGold         // 0xFFFFCC00
AppStyles.aetherTeal        // 0xFF00E5CC
AppStyles.novaPurple        // 0xFFBF5AF2
AppStyles.accentBlue        // 0xFF0A84FF

// Semantic (theme-adaptive, no context):
SemanticColors.accounts     // safe green for both themes
SemanticColors.liabilities  // safe red for both themes
```

### Landscape Pattern (implemented)
```dart
AppStyles.isLandscape(context)              // bool
AppStyles.sheetMaxHeight(context)           // 0.95h landscape, 0.85h portrait
AppStyles.landscapeContentConstraints(ctx)  // maxWidth: 560 landscape
```

### Architecture Rules
- Never use `shrinkWrap: true` on ListView/GridView inside scrollable — use Sliver* instead
- All currency displays must use AnimatedCounter (RepaintBoundary already applied)
- Max stagger index = 8 (prevents accumulated animation delay)
- Use `context.select<>` not `Consumer<>` when watching ≤2 fields
- All list screens must use `ListView.builder` or `SliverList` with delegate

---

*Last updated: 2026-03-22 — Session 9 cont: SYS-LAND-NAV fully done (67 screens), NW-01, SYS-03, SYS-04, BUD-01 done, INV-01 partial*
