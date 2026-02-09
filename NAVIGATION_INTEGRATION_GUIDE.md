# Navigation Integration Guide

## Quick Reference for Adding Financial Planning Screens to App Navigation

### Import Statements
Add these imports to your navigation/routing file:

```dart
// Goals
import 'package:vittara_fin_os/ui/manage/goals/goals_screen.dart';
import 'package:vittara_fin_os/ui/manage/goals/goal_details_screen.dart';

// Budgets
import 'package:vittara_fin_os/ui/manage/budgets/budgets_screen.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budget_details_screen.dart';

// Savings Planners
import 'package:vittara_fin_os/ui/manage/savings/savings_planners_screen.dart';

// AI Planner
import 'package:vittara_fin_os/ui/manage/ai_planner/ai_monthly_planner_screen.dart';
```

### Route Definitions
Add these routes to your app's route configuration:

```dart
'/goals': (context) => const GoalsScreen(),
'/goals/details': (context) => GoalDetailsScreen(goalId: args['goalId']),

'/budgets': (context) => const BudgetsScreen(),
'/budgets/details': (context) => BudgetDetailsScreen(budgetId: args['budgetId']),

'/savings-planners': (context) => const SavingsPlannersScreen(),

'/ai-planner': (context) => const AIMonthlyPlannerScreen(),
```

### Navigation Examples

#### Navigating to Goals Screen
```dart
Navigator.of(context).push(
  CupertinoPageRoute(
    builder: (context) => const GoalsScreen(),
  ),
);
```

#### Navigating to Goal Details
```dart
Navigator.of(context).push(
  CupertinoPageRoute(
    builder: (context) => GoalDetailsScreen(goalId: 'goal_123'),
  ),
);
```

#### Navigating to Budgets Screen
```dart
Navigator.of(context).push(
  CupertinoPageRoute(
    builder: (context) => const BudgetsScreen(),
  ),
);
```

#### Navigating to Budget Details
```dart
Navigator.of(context).push(
  CupertinoPageRoute(
    builder: (context) => BudgetDetailsScreen(budgetId: 'budget_123'),
  ),
);
```

#### Navigating to Savings Planners
```dart
Navigator.of(context).push(
  CupertinoPageRoute(
    builder: (context) => const SavingsPlannersScreen(),
  ),
);
```

#### Navigating to AI Planner
```dart
Navigator.of(context).push(
  CupertinoPageRoute(
    builder: (context) => const AIMonthlyPlannerScreen(),
  ),
);
```

### Menu Items for Manage Section

Add these to your manage/settings menu:

```dart
// In your manage screen list
ListTile(
  leading: Icon(CupertinoIcons.flag_fill, color: SemanticColors.success),
  title: Text('Goals'),
  subtitle: Text('Track your financial goals'),
  trailing: Icon(CupertinoIcons.chevron_right),
  onTap: () => Navigator.push(context, CupertinoPageRoute(
    builder: (context) => const GoalsScreen(),
  )),
),

ListTile(
  leading: Icon(CupertinoIcons.chart_pie_fill, color: SemanticColors.primary),
  title: Text('Budgets'),
  subtitle: Text('Manage your spending limits'),
  trailing: Icon(CupertinoIcons.chevron_right),
  onTap: () => Navigator.push(context, CupertinoPageRoute(
    builder: (context) => const BudgetsScreen(),
  )),
),

ListTile(
  leading: Icon(CupertinoIcons.money_dollar_circle_fill, color: SemanticColors.success),
  title: Text('Savings Planners'),
  subtitle: Text('Track monthly savings'),
  trailing: Icon(CupertinoIcons.chevron_right),
  onTap: () => Navigator.push(context, CupertinoPageRoute(
    builder: (context) => const SavingsPlannersScreen(),
  )),
),

ListTile(
  leading: Icon(CupertinoIcons.sparkles, color: SemanticColors.info),
  title: Text('AI Planner'),
  subtitle: Text('Get smart recommendations'),
  trailing: Icon(CupertinoIcons.chevron_right),
  onTap: () => Navigator.push(context, CupertinoPageRoute(
    builder: (context) => const AIMonthlyPlannerScreen(),
  )),
),
```

### Dashboard Integration

Add quick access cards to dashboard:

```dart
// Goals Summary Card
BouncyButton(
  onPressed: () => Navigator.push(context, CupertinoPageRoute(
    builder: (context) => const GoalsScreen(),
  )),
  child: Consumer<GoalsController>(
    builder: (context, controller, child) {
      return GlassCard(
        child: Column(
          children: [
            Text('${controller.activeGoals.length} Active Goals'),
            Text('${controller.overallProgress.toStringAsFixed(1)}% Complete'),
            Icon(CupertinoIcons.flag_fill, color: SemanticColors.success),
          ],
        ),
      );
    },
  ),
);

// Budgets Summary Card
BouncyButton(
  onPressed: () => Navigator.push(context, CupertinoPageRoute(
    builder: (context) => const BudgetsScreen(),
  )),
  child: Consumer<BudgetsController>(
    builder: (context, controller, child) {
      final exceedingCount = controller.getBudgetsExceedingLimit().length;
      return GlassCard(
        child: Column(
          children: [
            Text('${controller.activeBudgets.length} Active Budgets'),
            if (exceedingCount > 0)
              Text('$exceedingCount Exceeded', style: TextStyle(color: SemanticColors.error)),
            Icon(CupertinoIcons.chart_pie_fill, color: SemanticColors.primary),
          ],
        ),
      );
    },
  ),
);
```

### Provider Setup

Ensure these are added to your MultiProvider:

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => GoalsController()..initialize()),
    ChangeNotifierProvider(create: (_) => BudgetsController()..initialize()),
    // ... other providers
  ],
  child: MyApp(),
)
```

### Deep Linking Support (Optional)

If using deep links/URIs:

```dart
'/goals/:id': (context, args) => GoalDetailsScreen(goalId: args['id']),
'/budgets/:id': (context, args) => BudgetDetailsScreen(budgetId: args['id']),
```

### Search Integration (Optional)

Add to app-wide search:

```dart
if (query.toLowerCase().contains('goal')) {
  results.add(SearchResult(
    title: 'Goals',
    screen: const GoalsScreen(),
    icon: CupertinoIcons.flag_fill,
  ));
}

if (query.toLowerCase().contains('budget')) {
  results.add(SearchResult(
    title: 'Budgets',
    screen: const BudgetsScreen(),
    icon: CupertinoIcons.chart_pie_fill,
  ));
}

if (query.toLowerCase().contains('savings')) {
  results.add(SearchResult(
    title: 'Savings Planners',
    screen: const SavingsPlannersScreen(),
    icon: CupertinoIcons.money_dollar_circle_fill,
  ));
}

if (query.toLowerCase().contains('ai') || query.toLowerCase().contains('planner')) {
  results.add(SearchResult(
    title: 'AI Monthly Planner',
    screen: const AIMonthlyPlannerScreen(),
    icon: CupertinoIcons.sparkles,
  ));
}
```

## Testing Checklist

- [ ] All screens navigate correctly
- [ ] Back button works on all screens
- [ ] Modals open and close properly
- [ ] Data persists across app restarts
- [ ] Provider updates trigger UI refreshes
- [ ] Empty states display when no data
- [ ] Loading states work correctly
- [ ] Error messages display properly
- [ ] Success notifications appear
- [ ] All animations are smooth
- [ ] Dark mode works correctly
- [ ] Forms validate properly
- [ ] Delete confirmations work
- [ ] FAB buttons are accessible

## Common Issues and Solutions

### Issue: Provider not found
**Solution**: Ensure GoalsController and BudgetsController are in the provider tree

### Issue: Navigation doesn't work
**Solution**: Check that imports are correct and routes are registered

### Issue: Data doesn't persist
**Solution**: Controllers call `initialize()` and save methods work

### Issue: UI doesn't update
**Solution**: Wrap widgets with Consumer or use context.watch<>()

### Issue: Modals don't show
**Solution**: Use showCupertinoModalPopup with correct context

All screens are production-ready and follow iOS design patterns with Cupertino widgets.
