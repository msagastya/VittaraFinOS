# Empty State Patterns - VittaraFinOS

This document standardizes how empty states are displayed throughout the application for consistency and better user experience.

## Overview

Empty states are shown when a screen or list has no data to display. They should be informative, visually consistent, and guide users toward the next action.

---

## The EmptyStateView Widget

VittaraFinOS provides a reusable `EmptyStateView` widget that ensures consistency across all empty states.

### Location
`lib/ui/widgets/common_widgets.dart`

### Basic Usage

```dart
EmptyStateView(
  icon: CupertinoIcons.folder,
  title: 'No Accounts Yet',
  subtitle: 'Create your first account to get started',
  actionLabel: 'Add Account',
  onAction: _showAddAccountModal,
)
```

---

## Widget Parameters

### Required Parameters

- **`icon`** (`IconData`): The icon to display (use Cupertino icons for consistency)
- **`title`** (`String`): Main message explaining the empty state

### Optional Parameters

- **`subtitle`** (`String?`): Additional context or guidance
- **`actionLabel`** (`String?`): Label for the action button
- **`onAction`** (`VoidCallback?`): Callback when action button is tapped
- **`showPulse`** (`bool`): Whether to animate the icon (default: `true`)

---

## Design Patterns

### Visual Structure

1. **Icon** (64x64)
   - Centered at top
   - Uses secondary text color with reduced opacity
   - Optional pulse animation when action is available

2. **Title** (TypeScale.title3)
   - Short, descriptive message
   - Secondary text color
   - Medium weight font

3. **Subtitle** (TypeScale.body, optional)
   - Provides additional context
   - Secondary text color with more opacity
   - Lighter weight

4. **Action Button** (optional)
   - Primary color with shadow
   - Clear call-to-action text
   - Bouncy animation on press

### Spacing

- Icon to Title: `Spacing.lg`
- Title to Subtitle: `Spacing.sm`
- Subtitle to Action: `Spacing.xxl`

---

## Usage Examples

### 1. List with No Items

```dart
// Accounts screen with no accounts
EmptyStateView(
  icon: CupertinoIcons.creditcard,
  title: 'No Accounts Yet',
  subtitle: 'Add your bank accounts, credit cards, and wallets to start tracking your finances',
  actionLabel: 'Add Account',
  onAction: () => _showAddAccountModal(context),
)
```

### 2. Search with No Results

```dart
// Search results empty
EmptyStateView(
  icon: CupertinoIcons.search,
  title: 'No Results Found',
  subtitle: 'Try adjusting your search terms',
  showPulse: false, // No action available
)
```

### 3. Filtered List (No Matches)

```dart
// Transactions filtered but none match
EmptyStateView(
  icon: CupertinoIcons.line_horizontal_3_decrease,
  title: 'No Transactions Match',
  subtitle: 'No transactions match your current filters',
  actionLabel: 'Clear Filters',
  onAction: () => _clearFilters(),
)
```

### 4. Feature Not Yet Used

```dart
// Investments screen with no investments
EmptyStateView(
  icon: CupertinoIcons.chart_bar,
  title: 'No Investments Yet',
  subtitle: 'Start investing in FDs, RDs, Stocks, and more',
  actionLabel: 'Add Investment',
  onAction: () => _showInvestmentTypeSelection(context),
)
```

### 5. Read-Only Empty State (No Action)

```dart
// History with no items, no action to take
EmptyStateView(
  icon: CupertinoIcons.clock,
  title: 'No History',
  subtitle: 'Your activity history will appear here',
  showPulse: false,
)
```

---

## Icon Selection Guide

Use appropriate icons that represent the content type:

| Content Type | Recommended Icon |
|--------------|------------------|
| Accounts | `CupertinoIcons.creditcard` or `CupertinoIcons.money_dollar` |
| Transactions | `CupertinoIcons.arrow_right_arrow_left` |
| Investments | `CupertinoIcons.chart_bar` or `CupertinoIcons.graph_square` |
| Categories | `CupertinoIcons.square_grid_2x2` |
| Tags | `CupertinoIcons.tag` |
| Contacts | `CupertinoIcons.person_2` |
| History | `CupertinoIcons.clock` or `CupertinoIcons.time` |
| Search Results | `CupertinoIcons.search` |
| Notifications | `CupertinoIcons.bell` |
| Settings | `CupertinoIcons.settings` |

---

## Content Guidelines

### Title Best Practices

1. **Be Clear and Concise**
   - ✅ "No Accounts Yet"
   - ❌ "You Don't Have Any Accounts"

2. **Use Present Tense**
   - ✅ "No Transactions Found"
   - ❌ "You Haven't Made Any Transactions"

3. **Be Positive**
   - ✅ "No Investments Yet"
   - ❌ "You Have No Investments"

### Subtitle Best Practices

1. **Provide Context or Next Steps**
   - ✅ "Add your first account to start tracking expenses"
   - ❌ "There are no accounts"

2. **Keep It Short**
   - One or two sentences maximum
   - Avoid technical jargon

3. **Be Helpful**
   - Suggest what the user can do
   - Explain why this matters

### Action Label Best Practices

1. **Use Action Verbs**
   - ✅ "Add Account", "Create Investment", "Import Data"
   - ❌ "Click Here", "Get Started", "Continue"

2. **Be Specific**
   - ✅ "Add First Transaction"
   - ❌ "Add"

3. **Match the Context**
   - Use terminology consistent with the feature

---

## Implementation in Screens

### Conditional Rendering

```dart
Widget build(BuildContext context) {
  final accounts = Provider.of<AccountsController>(context).accounts;

  if (accounts.isEmpty) {
    return EmptyStateView(
      icon: CupertinoIcons.creditcard,
      title: 'No Accounts Yet',
      subtitle: 'Add your first account to start tracking your finances',
      actionLabel: 'Add Account',
      onAction: _showAddAccountModal,
    );
  }

  return ListView.builder(
    itemCount: accounts.length,
    itemBuilder: (context, index) => AccountCard(account: accounts[index]),
  );
}
```

### With Search/Filter

```dart
Widget build(BuildContext context) {
  final filteredAccounts = _getFilteredAccounts();

  return Column(
    children: [
      SearchBar(onChanged: _handleSearch),
      Expanded(
        child: filteredAccounts.isEmpty
            ? EmptyStateView(
                icon: _searchQuery.isEmpty
                    ? CupertinoIcons.creditcard
                    : CupertinoIcons.search,
                title: _searchQuery.isEmpty
                    ? 'No Accounts Yet'
                    : 'No Results Found',
                subtitle: _searchQuery.isEmpty
                    ? 'Add your first account'
                    : 'Try different search terms',
                actionLabel: _searchQuery.isEmpty ? 'Add Account' : 'Clear Search',
                onAction: _searchQuery.isEmpty
                    ? _showAddAccountModal
                    : _clearSearch,
              )
            : AccountList(accounts: filteredAccounts),
      ),
    ],
  );
}
```

---

## Accessibility Considerations

1. **Icon Size**: Large enough to be visible (64x64)
2. **Text Contrast**: Uses appropriate text colors from design tokens
3. **Touch Targets**: Action button meets minimum 44x44pt size
4. **Screen Reader**: All text is readable by screen readers
5. **Animation**: Pulse animation is subtle and not distracting

---

## Screen-Specific Examples

### Accounts Screen

```dart
EmptyStateView(
  icon: CupertinoIcons.creditcard,
  title: 'No Accounts Yet',
  subtitle: 'Add your bank accounts, credit cards, and digital wallets to start managing your finances',
  actionLabel: 'Add Account',
  onAction: () => _showAddAccountModal(context),
)
```

### Transactions Screen

```dart
EmptyStateView(
  icon: CupertinoIcons.arrow_right_arrow_left,
  title: 'No Transactions',
  subtitle: 'Your transaction history will appear here once you start recording expenses and income',
  showPulse: false, // Transactions are usually recorded elsewhere
)
```

### Investments Screen

```dart
EmptyStateView(
  icon: CupertinoIcons.chart_bar,
  title: 'No Investments Yet',
  subtitle: 'Start investing in Fixed Deposits, Recurring Deposits, Stocks, Mutual Funds, and more',
  actionLabel: 'Add Investment',
  onAction: () => _showInvestmentTypeSelection(context),
)
```

### Categories Screen

```dart
EmptyStateView(
  icon: CupertinoIcons.square_grid_2x2,
  title: 'No Categories',
  subtitle: 'Create categories to organize your transactions',
  actionLabel: 'Add Category',
  onAction: () => _showAddCategoryModal(context),
)
```

### Tags Screen

```dart
EmptyStateView(
  icon: CupertinoIcons.tag,
  title: 'No Tags Yet',
  subtitle: 'Use tags to label and organize your transactions',
  actionLabel: 'Create Tag',
  onAction: () => _showAddTagModal(context),
)
```

### Contacts Screen

```dart
EmptyStateView(
  icon: CupertinoIcons.person_2,
  title: 'No Contacts',
  subtitle: 'Add contacts to track lending and borrowing',
  actionLabel: 'Add Contact',
  onAction: () => _showAddContactModal(context),
)
```

### Notifications Screen

```dart
EmptyStateView(
  icon: CupertinoIcons.bell,
  title: 'No Notifications',
  subtitle: 'You\'re all caught up! Notifications about your finances will appear here',
  showPulse: false,
)
```

### Search Results

```dart
EmptyStateView(
  icon: CupertinoIcons.search,
  title: 'No Results for "$searchQuery"',
  subtitle: 'Try different keywords or check your spelling',
  actionLabel: 'Clear Search',
  onAction: () => _clearSearch(),
)
```

---

## When NOT to Use EmptyStateView

Do not use `EmptyStateView` for:

1. **Loading States** - Use loading spinners instead
2. **Error States** - Use error messages with retry options
3. **Temporarily Hidden Content** - Use placeholder text
4. **Partial Empty States** - If some sections have data, only show empty state in the empty section

---

## Design Token Usage

The `EmptyStateView` widget uses the following design tokens:

- **Spacing**: `Spacing.lg`, `Spacing.sm`, `Spacing.xxl`
- **Icon Size**: `IconSizes.emptyStateIcon` (64.0)
- **Colors**: `AppStyles.getSecondaryTextColor(context)` with opacity
- **Typography**: `TypeScale.title3`, `TypeScale.body`
- **Opacity**: `Opacities.disabled` for icons
- **Shadows**: `Shadows.fab()` for action button
- **Border Radius**: `Radii.buttonRadius`
- **Animation**: `PulseAnimation` from animations.dart

---

## Checklist

When implementing an empty state, ensure:

- [ ] Uses `EmptyStateView` widget (don't create custom empty states)
- [ ] Icon is appropriate for the content type
- [ ] Title is clear and concise (2-4 words)
- [ ] Subtitle provides helpful context or guidance
- [ ] Action button is included if user can add content
- [ ] Action button label is specific and actionable
- [ ] Animation is appropriate (pulse on if action available)
- [ ] Consistent with other empty states in the app
- [ ] Text is helpful and friendly in tone
- [ ] Accessible (good contrast, readable text)

---

## Summary

- **Always use `EmptyStateView`** for consistency
- **Be helpful** - Guide users on what to do next
- **Be concise** - Keep titles short and clear
- **Be positive** - Use encouraging, friendly language
- **Be specific** - Action buttons should clearly indicate what happens
- **Follow patterns** - Use established icons and terminology

This ensures a consistent, professional, and user-friendly experience across the entire application.
