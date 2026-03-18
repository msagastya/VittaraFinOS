import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Standard date picker for VittaraFinOS.
/// Always presents as a bottom sheet modal with consistent styling.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? minimumDate,
  DateTime? maximumDate,
  CupertinoDatePickerMode mode = CupertinoDatePickerMode.date,
}) async {
  DateTime selected = initialDate;
  bool confirmed = false;

  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => Container(
      decoration: AppStyles.bottomSheetDecoration(ctx),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppStyles.getSecondaryTextColor(ctx).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.lg, vertical: Spacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(ctx))),
                  ),
                  Text(
                    mode == CupertinoDatePickerMode.date
                        ? 'Select Date'
                        : 'Select Date & Time',
                    style: TextStyle(
                      color: AppStyles.getTextColor(ctx),
                      fontWeight: FontWeight.w600,
                      fontSize: TypeScale.body,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      confirmed = true;
                      Navigator.pop(ctx);
                    },
                    child: const Text('Done',
                        style: TextStyle(
                          color: Color(0xFF00D4AA),
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Picker
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                mode: mode,
                initialDateTime: initialDate,
                minimumDate: minimumDate,
                maximumDate: maximumDate,
                onDateTimeChanged: (dt) => selected = dt,
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    ),
  );

  return confirmed ? selected : null;
}
