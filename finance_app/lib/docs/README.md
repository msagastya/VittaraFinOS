# VittaraFinOS Documentation

This directory contains comprehensive documentation for the VittaraFinOS codebase, covering patterns, guidelines, and implementation details.

---

## Documentation Index

### 1. Navigation Patterns
**File:** `NAVIGATION_PATTERNS.md`

Learn when and how to use modals vs wizards for user flows.

**Topics Covered:**
- Modal vs Wizard decision guide
- Navigation button behavior standards
- Progress indicator patterns
- Code templates and examples
- Design token integration

**Use this when:**
- Creating new user flows
- Implementing modals or wizards
- Standardizing navigation behavior

---

### 2. Empty State Patterns
**File:** `EMPTY_STATE_PATTERNS.md`

Guide for implementing consistent empty states across the application.

**Topics Covered:**
- EmptyStateView widget usage
- Icon selection guide
- Content writing guidelines
- Screen-specific examples
- Accessibility considerations

**Use this when:**
- Implementing screens with lists
- Handling no-data scenarios
- Creating search result pages
- Showing filtered content

---

### 3. Implementation Summary
**File:** `IMPLEMENTATION_SUMMARY.md`

Detailed summary of Tasks 16-21 implementation.

**Topics Covered:**
- Task completion details
- Files created and modified
- Feature implementations
- Code quality standards
- Integration points
- Testing recommendations

**Use this when:**
- Understanding recent changes
- Reviewing completed features
- Planning similar implementations
- Onboarding new developers

---

## Quick Reference

### Design Tokens
All UI implementations should use design tokens from:
```
/lib/ui/styles/design_tokens.dart
```

**Key Token Categories:**
- `Spacing` - Padding and margins
- `TypeScale` - Font sizes
- `SemanticColors` - Color palette
- `IconSizes` - Icon dimensions
- `Radii` - Border radius values
- `Shadows` - Elevation effects
- `AppDurations` - Animation timing
- `MotionCurves` - Animation curves

### Common Widgets
Reusable UI components are in:
```
/lib/ui/widgets/common_widgets.dart
```

**Available Widgets:**
- `EmptyStateView` - Empty state display
- `FadingFAB` - Floating action button
- `ModalHandle` - Bottom sheet handle
- `SectionHeader` - List section headers
- `IconBox` - Icon containers
- `ActionButtonRow` - Modal action buttons
- `SmallActionButton` - Inline actions
- `AppSearchBar` - Search input
- `SummaryCard` - Stats display
- `ListCard` - List item cards
- `OptionCard` - Selection cards
- `SettingsRow` - Settings items
- `ColorPickerRow` - Color selection
- `LoadingOverlay` - Loading states

### Utility Functions
Helper utilities are organized by domain:

**Bulk Operations:**
```
/lib/utils/bulk_account_operations.dart
```
- Account bulk operations
- Export/import functions
- Archive system utilities

---

## Implementation Patterns

### Modal Pattern
```dart
SafeArea(
  child: Scaffold(
    appBar: CupertinoNavigationBar(
      middle: const Text('Modal Title'),
      previousPageTitle: 'Back',
    ),
    body: SingleChildScrollView(
      padding: EdgeInsets.all(Spacing.lg),
      child: Column(
        children: [
          // Content
          SizedBox(height: Spacing.xxl),
          // Action buttons
        ],
      ),
    ),
  ),
)
```

### Wizard Pattern
```dart
Column(
  children: [
    _buildProgressIndicator(),
    Expanded(child: _buildCurrentStep()),
    _buildNavigationButtons(),
  ],
)
```

### Empty State Pattern
```dart
EmptyStateView(
  icon: CupertinoIcons.icon_name,
  title: 'No Items Yet',
  subtitle: 'Add your first item to get started',
  actionLabel: 'Add Item',
  onAction: _showAddModal,
)
```

---

## Code Style Guidelines

### File Organization
```
/lib
├── logic/           # Business logic and models
├── ui/              # User interface components
│   ├── manage/      # Management screens
│   ├── dashboard/   # Dashboard widgets
│   ├── styles/      # Design system
│   └── widgets/     # Reusable components
├── utils/           # Utility functions
├── services/        # External services
└── docs/            # Documentation (this folder)
```

### Naming Conventions
- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables**: `camelCase`
- **Constants**: `camelCase` (with const keyword)
- **Private members**: `_leadingUnderscore`

### Import Organization
```dart
// 1. Dart imports
import 'dart:async';

// 2. Flutter imports
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// 3. Package imports
import 'package:provider/provider.dart';

// 4. Project imports
import 'package:vittara_fin_os/logic/model.dart';
import 'package:vittara_fin_os/ui/screen.dart';
```

---

## Best Practices

### 1. Always Use Design Tokens
❌ **Don't:**
```dart
padding: EdgeInsets.all(16),
color: Colors.blue,
fontSize: 14,
```

✅ **Do:**
```dart
padding: EdgeInsets.all(Spacing.lg),
color: SemanticColors.getPrimary(context),
fontSize: TypeScale.body,
```

### 2. Handle Errors Gracefully
❌ **Don't:**
```dart
await controller.updateAccount(account);
```

✅ **Do:**
```dart
try {
  await controller.updateAccount(account);
  if (mounted) {
    toast.showSuccess('Updated successfully');
  }
} catch (e) {
  if (mounted) {
    toast.showError('Failed to update: $e');
  }
}
```

### 3. Check Mounted Before setState
❌ **Don't:**
```dart
await someAsyncOperation();
setState(() { /* ... */ });
```

✅ **Do:**
```dart
await someAsyncOperation();
if (mounted) {
  setState(() { /* ... */ });
}
```

### 4. Dispose Controllers
❌ **Don't:**
```dart
class _MyState extends State<MyWidget> {
  final controller = TextEditingController();
  // No dispose
}
```

✅ **Do:**
```dart
class _MyState extends State<MyWidget> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
```

### 5. Use Const Constructors
❌ **Don't:**
```dart
SizedBox(height: 16)
Text('Hello')
```

✅ **Do:**
```dart
SizedBox(height: Spacing.lg)
const Text('Hello')
```

---

## Testing Guidelines

### Unit Tests
Test business logic in `/logic` folder:
- Model serialization/deserialization
- Calculation functions
- Controller methods

### Widget Tests
Test UI components:
- Widget rendering
- User interactions
- State changes

### Integration Tests
Test complete flows:
- User journeys
- Data persistence
- Navigation flows

---

## Common Tasks

### Adding a New Modal
1. Create file in appropriate `/ui/manage/[type]/modals/` folder
2. Extend StatefulWidget
3. Use CupertinoNavigationBar
4. Follow modal pattern from NAVIGATION_PATTERNS.md
5. Use design tokens throughout
6. Add error handling and toast notifications

### Adding a New Wizard
1. Create wizard file and controller
2. Define steps as separate widgets
3. Add progress indicator
4. Implement step navigation
5. Follow wizard pattern from NAVIGATION_PATTERNS.md
6. Add review step before submission

### Adding a New Screen
1. Create screen file in appropriate `/ui/` folder
2. Check for empty states and use EmptyStateView
3. Add loading states
4. Implement error handling
5. Follow existing screen patterns

### Adding Bulk Operations
1. Add function to bulk_account_operations.dart
2. Use try-catch for each item
3. Return count of successful operations
4. Follow existing function patterns

---

## Troubleshooting

### Design Token Not Found
- Check import: `import 'package:vittara_fin_os/ui/styles/design_tokens.dart'`
- Verify token exists in design_tokens.dart
- Use appropriate getter (e.g., `SemanticColors.getPrimary(context)`)

### Modal Not Showing
- Check navigation context is valid
- Use `showCupertinoModalPopup` or `Navigator.push`
- Ensure modal is wrapped in Material/Cupertino app

### State Not Updating
- Verify `notifyListeners()` called in controller
- Check widget is listening to Provider
- Ensure `mounted` before setState

### Widget Overflow
- Wrap in SingleChildScrollView
- Use Expanded/Flexible appropriately
- Check for hardcoded sizes

---

## Resources

### External Documentation
- [Flutter Documentation](https://docs.flutter.dev)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Material Design Guidelines](https://material.io/design)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

### Project-Specific
- Design tokens: `/lib/ui/styles/design_tokens.dart`
- Common widgets: `/lib/ui/widgets/common_widgets.dart`
- App styles: `/lib/ui/styles/app_styles.dart`

---

## Contributing

When adding new features:

1. **Follow existing patterns** - Check similar implementations
2. **Use design tokens** - No hardcoded values
3. **Document your code** - Add comments for complex logic
4. **Write tests** - Unit tests for logic, widget tests for UI
5. **Update docs** - Add to this documentation if needed
6. **Review checklist** - Use checklists in pattern docs

---

## Version History

### v1.0 - February 2026
- Initial documentation structure
- Navigation patterns documented
- Empty state patterns documented
- Implementation summary added
- Code style guidelines established

---

## Support

For questions or issues:
1. Check relevant documentation file
2. Review code examples in docs
3. Look at similar implementations in codebase
4. Follow established patterns

---

**Last Updated:** February 5, 2026
**Maintained by:** VittaraFinOS Development Team
