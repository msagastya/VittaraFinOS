# Navigation Patterns - VittaraFinOS

This document standardizes the navigation patterns used throughout the application, specifically around modals and wizards.

## Overview

VittaraFinOS uses two primary navigation patterns for user interactions:
1. **Modals** - For single-step operations or simple edits
2. **Wizards** - For multi-step flows with complex data collection

---

## When to Use Modals

Use modals for:
- **Single-step operations** that can be completed in one screen
- **Simple edits** to existing data
- **Quick actions** like withdrawal, deletion, or settings changes
- **Read-only views** like viewing history, schedules, or details
- **Confirmation dialogs** for destructive actions

### Modal Characteristics

- Present as bottom sheets or full-screen overlays
- Single focused task
- Can be dismissed easily
- No progress indicators needed
- Immediate save/cancel actions

### Modal Examples

```dart
// Withdrawal Modal (Single Step)
FDWithdrawalModal(
  fd: fixedDeposit,
  onWithdraw: () { /* handle withdrawal */ },
)

// Edit Modal (Single Screen with Multiple Fields)
FDEditModal(
  fd: fixedDeposit,
  originalInvestment: investment,
)

// Settings Modal
showCupertinoModalPopup(
  context: context,
  builder: (context) => SettingsModal(...),
)
```

### Modal UI Patterns

**Header Structure:**
```dart
CupertinoNavigationBar(
  middle: const Text('Modal Title'),
  previousPageTitle: 'Back',
  backgroundColor: AppStyles.getBackground(context),
  border: null,
  trailing: // Optional save/action button
)
```

**Action Buttons:**
```dart
// Single primary action
CupertinoButton(
  color: SemanticColors.getPrimary(context),
  onPressed: _handleAction,
  child: const Text('Action'),
)

// Primary + Secondary actions
Row(
  children: [
    Expanded(child: CupertinoButton(/* Secondary */)),
    SizedBox(width: Spacing.md),
    Expanded(child: CupertinoButton(/* Primary */)),
  ],
)
```

---

## When to Use Wizards

Use wizards for:
- **Multi-step processes** that require progressive data collection
- **Complex creation flows** (e.g., creating FD, RD, Stock investments)
- **Onboarding flows** with multiple stages
- **Configuration processes** with dependencies between steps

### Wizard Characteristics

- Multiple sequential steps/screens
- Progress indicator showing current step
- Back button to return to previous step
- Review step before final submission
- Maintains state across steps
- Can save partial progress

### Wizard Examples

```dart
// FD Creation Wizard (7 Steps)
FDWizard(
  steps: [
    AccountSelectionStep(),
    PrincipalStep(),
    InterestRateStep(),
    TenureStep(),
    CompoundingStep(),
    FDTypePayoutStep(),
    DebitAndReviewStep(),
  ],
)

// Stock Purchase Wizard (4 Steps)
StocksWizard(
  steps: [
    StockSearchStep(),
    AccountSelectionStep(),
    TransactionDetailsStep(),
    ReviewStep(),
  ],
)
```

### Wizard UI Patterns

**Progress Indicator:**
```dart
// Linear progress bar
Container(
  height: 4,
  child: LinearProgressIndicator(
    value: (currentStep + 1) / totalSteps,
    backgroundColor: Colors.grey[300],
    valueColor: AlwaysStoppedAnimation<Color>(
      SemanticColors.getPrimary(context),
    ),
  ),
)

// Step counter text
Text(
  'Step ${currentStep + 1} of $totalSteps',
  style: TextStyle(
    color: AppStyles.getSecondaryTextColor(context),
    fontSize: TypeScale.footnote,
  ),
)
```

**Navigation Controls:**
```dart
// Back button (in AppBar)
CupertinoNavigationBar(
  leading: CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: _goToPreviousStep,
    child: Row(
      children: [
        Icon(CupertinoIcons.back),
        Text('Back'),
      ],
    ),
  ),
  middle: Text('Step Title'),
)

// Continue/Next button (bottom of screen)
CupertinoButton(
  color: SemanticColors.getPrimary(context),
  onPressed: _canProceed ? _goToNextStep : null,
  child: Text(_isLastStep ? 'Complete' : 'Continue'),
)
```

**State Management:**
```dart
class WizardController extends ChangeNotifier {
  int _currentStep = 0;
  final Map<String, dynamic> _data = {};

  void goToStep(int step) {
    _currentStep = step.clamp(0, totalSteps - 1);
    notifyListeners();
  }

  void updateData(String key, dynamic value) {
    _data[key] = value;
    notifyListeners();
  }

  void goToNextStep() {
    if (_currentStep < totalSteps - 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  void goToPreviousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }
}
```

---

## Navigation Button Behavior Standards

### Cancel Button Behavior

**In Modals:**
- Label: "Cancel" or "Close"
- Position: Top-left of navigation bar OR bottom-left of action row
- Action: Dismiss modal immediately without confirmation (unless data entered)
- Icon: `CupertinoIcons.xmark_circle_fill` for top-right close buttons

**In Wizards:**
- Label: "Back" or "Previous"
- Position: Top-left of navigation bar
- Action: Return to previous step (NOT dismiss entire wizard)
- Icon: `CupertinoIcons.back` or `CupertinoIcons.chevron_left`

### Confirmation for Data Loss

```dart
Future<bool> _onWillPop() async {
  if (_hasUnsavedChanges) {
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to go back?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    ) ?? false;
  }
  return true;
}
```

### Back Button Behavior

**Modal Back Button:**
```dart
// Simple dismiss
onPressed: () => Navigator.of(context).pop()

// With confirmation if needed
onPressed: _hasChanges ? _confirmAndPop : () => Navigator.of(context).pop()
```

**Wizard Back Button:**
```dart
// Return to previous step
onPressed: () {
  if (controller.currentStep > 0) {
    controller.goToPreviousStep();
  } else {
    Navigator.of(context).pop(); // Exit wizard from first step
  }
}
```

---

## Progress Indicators in Wizards

### Types of Progress Indicators

1. **Linear Progress Bar** (Recommended)
   - Shows exact completion percentage
   - Visual and intuitive
   - Placement: Top of screen below navigation bar

2. **Step Counter Text**
   - Simple text: "Step X of Y"
   - Placement: Navigation bar subtitle or top of content

3. **Stepper Dots**
   - Horizontal dots showing steps
   - Good for 3-5 steps
   - Placement: Top of screen

### Implementation Examples

**Linear Progress Bar:**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Step ${currentStep + 1} of $totalSteps',
        style: TextStyle(
          color: AppStyles.getSecondaryTextColor(context),
          fontSize: TypeScale.footnote,
        ),
      ),
      SizedBox(height: Spacing.sm),
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.full),
        child: LinearProgressIndicator(
          value: (currentStep + 1) / totalSteps,
          minHeight: 4,
          backgroundColor: AppStyles.getDividerColor(context),
          valueColor: AlwaysStoppedAnimation<Color>(
            SemanticColors.getPrimary(context),
          ),
        ),
      ),
    ],
  ),
)
```

**Stepper Dots:**
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: List.generate(totalSteps, (index) {
    final isActive = index == currentStep;
    final isCompleted = index < currentStep;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: Spacing.xs),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? SemanticColors.getSuccess(context)
            : isActive
                ? SemanticColors.getPrimary(context)
                : AppStyles.getDividerColor(context),
      ),
    );
  }),
)
```

---

## Standardized Patterns

### Modal Template

```dart
class ExampleModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AppStyles.getBackground(context),
        appBar: CupertinoNavigationBar(
          middle: const Text('Modal Title'),
          previousPageTitle: 'Back',
          backgroundColor: AppStyles.getBackground(context),
          border: null,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(Spacing.lg),
          child: Column(
            children: [
              // Content here
              SizedBox(height: Spacing.xxl),
              // Action buttons
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: SemanticColors.getPrimary(context),
                  onPressed: _handleAction,
                  child: const Text('Action'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Wizard Template

```dart
class ExampleWizard extends StatefulWidget {
  @override
  State<ExampleWizard> createState() => _ExampleWizardState();
}

class _ExampleWizardState extends State<ExampleWizard> {
  int _currentStep = 0;
  final int _totalSteps = 4;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppStyles.getBackground(context),
        appBar: CupertinoNavigationBar(
          leading: _buildBackButton(),
          middle: Text('Step ${_currentStep + 1}'),
          backgroundColor: AppStyles.getBackground(context),
          border: null,
        ),
        body: Column(
          children: [
            _buildProgressIndicator(),
            Expanded(
              child: _buildCurrentStep(),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.all(Spacing.lg),
      child: LinearProgressIndicator(
        value: (_currentStep + 1) / _totalSteps,
      ),
    );
  }

  Widget _buildCurrentStep() {
    // Return current step widget based on _currentStep
    return Container();
  }

  Widget _buildNavigationButtons() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: CupertinoButton(
                  onPressed: () {
                    setState(() {
                      _currentStep--;
                    });
                  },
                  child: const Text('Back'),
                ),
              ),
            if (_currentStep > 0) SizedBox(width: Spacing.md),
            Expanded(
              child: CupertinoButton(
                color: SemanticColors.getPrimary(context),
                onPressed: _handleContinue,
                child: Text(_currentStep == _totalSteps - 1 ? 'Complete' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      return false;
    }
    return true;
  }
}
```

---

## Design Token Usage

All navigation components should use design tokens for consistency:

- **Spacing**: Use `Spacing.lg`, `Spacing.md`, etc.
- **Colors**: Use `SemanticColors.getPrimary(context)`, `AppStyles.getBackground(context)`
- **Typography**: Use `TypeScale.body`, `TypeScale.title1`, etc.
- **Animation**: Use `AppDurations.normal`, `MotionCurves.standard`
- **Border Radius**: Use `Radii.buttonRadius`, `Radii.cardRadius`

---

## Checklist

### Modal Checklist
- [ ] Uses CupertinoNavigationBar with proper styling
- [ ] Has clear title describing the action
- [ ] Action buttons are clearly labeled
- [ ] Dismissible with back button or cancel action
- [ ] Handles data loss confirmation if needed
- [ ] Uses consistent padding and spacing
- [ ] Follows design token standards

### Wizard Checklist
- [ ] Shows progress indicator
- [ ] Has clear step titles
- [ ] Back button returns to previous step
- [ ] Continue/Next button advances to next step
- [ ] Final step has "Complete" or "Finish" button
- [ ] Handles navigation with WillPopScope
- [ ] Maintains state across steps
- [ ] Has review step before final submission
- [ ] Uses consistent navigation patterns
- [ ] Follows design token standards

---

## Summary

- **Modals**: Single-step, simple operations, immediate actions
- **Wizards**: Multi-step, complex flows, progressive data collection
- **Back Button**: Returns to previous step in wizards, dismisses modals
- **Cancel Button**: Dismisses modal OR exits wizard from first step
- **Progress**: Always show in wizards, never in modals
- **Consistency**: Follow templates and use design tokens

This ensures a predictable, intuitive user experience across the entire application.
