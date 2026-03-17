import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Bottom sheet shown once on first launch after an app update.
class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({super.key});

  static const currentVersion = '2.0.0';

  static const _features = [
    ('Financial Calendar', 'All SIP dates, FD maturities, and EMI dues in one place.'),
    ('Loan & EMI Tracker', 'Track principal, interest, tenure and amortization.'),
    ('Insurance Tracker', 'Manage health, life, and vehicle insurance renewals.'),
    ('SIP Tracker Dashboard', 'Monitor SIP contributions and XIRR at a glance.'),
    ('Financial Health Score', 'A 0–100 score based on savings, budgets, investments and debt.'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);

    return Container(
      decoration: AppStyles.bottomSheetDecoration(context),
      padding: const EdgeInsets.fromLTRB(
          Spacing.xl, Spacing.lg, Spacing.xl, Spacing.xxl),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppStyles.getDividerColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Spacing.xl),

            // Title
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppStyles.aetherTeal, AppStyles.novaPurple],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.sparkles,
                    color: CupertinoColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's New",
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: TypeScale.title2,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    Text(
                      'Version $currentVersion',
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: Spacing.xl),

            // Feature list
            ..._features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppStyles.aetherTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.$1,
                              style: TextStyle(
                                fontSize: TypeScale.body,
                                fontWeight: FontWeight.w600,
                                color: AppStyles.getTextColor(context),
                              ),
                            ),
                            Text(
                              f.$2,
                              style: TextStyle(
                                fontSize: TypeScale.footnote,
                                color: AppStyles.getSecondaryTextColor(context),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: Spacing.xl),

            // Got it button
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(14),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
