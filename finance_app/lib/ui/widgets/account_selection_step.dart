import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

/// Reusable account selection step for wizards.
///
/// Shows a list of accounts filtered by [accountTypes] if provided.
/// The caller must supply the [accounts] list (typically from
/// [AccountsController.accounts]) so this widget stays decoupled from any
/// specific wizard controller.
class AccountSelectionStep extends StatelessWidget {
  /// Full list of accounts to display (pre-loaded by caller).
  final List<Account> accounts;

  /// Currently selected account (highlighted with border + checkmark).
  final Account? selectedAccount;

  /// Callback invoked when the user taps an account card.
  final ValueChanged<Account> onAccountSelected;

  /// Optional whitelist of account types. When provided, only accounts whose
  /// [AccountType] is in this list will be shown.
  final List<AccountType>? accountTypes;

  /// Heading shown above the list. Defaults to 'Select Account'.
  final String? title;

  /// Subtitle shown below the title.
  final String? subtitle;

  /// Message shown when the filtered list is empty.
  final String? emptyMessage;

  const AccountSelectionStep({
    super.key,
    required this.accounts,
    required this.onAccountSelected,
    this.selectedAccount,
    this.accountTypes,
    this.title,
    this.subtitle,
    this.emptyMessage,
  });

  // ── helpers ──────────────────────────────────────────────────────────────

  List<Account> _filtered() {
    final types = accountTypes;
    if (types == null || types.isEmpty) return accounts;
    return accounts.where((a) => types.contains(a.type)).toList();
  }

  String _accountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.savings:
        return 'Savings';
      case AccountType.current:
        return 'Current';
      case AccountType.credit:
        return 'Credit Card';
      case AccountType.payLater:
        return 'Pay Later';
      case AccountType.wallet:
        return 'Wallet';
      case AccountType.investment:
        return 'Investment / Demat';
      case AccountType.cash:
        return 'Cash';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered();
    final effectiveTitle = title ?? 'Select Account';
    final effectiveEmpty = emptyMessage ?? 'No matching accounts found';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.xl,
            Spacing.xl,
            Spacing.xl,
            Spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                effectiveTitle,
                style: TextStyle(
                  fontSize: TypeScale.title3,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                  letterSpacing: -0.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── List ─────────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.creditcard,
                          size: 52,
                          color: AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: Spacing.lg),
                        Text(
                          effectiveEmpty,
                          style: TextStyle(
                            fontSize: TypeScale.subhead,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: Spacing.sm,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _AccountCard(
                      account: filtered[index],
                      isSelected: selectedAccount?.id == filtered[index].id,
                      typeLabel: _accountTypeLabel(filtered[index].type),
                      onTap: () => onAccountSelected(filtered[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private account card widget
// ---------------------------------------------------------------------------

class _AccountCard extends StatelessWidget {
  final Account account;
  final bool isSelected;
  final String typeLabel;
  final VoidCallback onTap;

  const _AccountCard({
    required this.account,
    required this.isSelected,
    required this.typeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppStyles.getPrimaryColor(context);
    final accentColor = isSelected ? primaryColor : account.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.10)
              : AppStyles.getCardColor(context),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Account colour dot / icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _iconForType(account.type),
                  size: 20,
                  color: accentColor,
                ),
              ),
            ),

            const SizedBox(width: Spacing.md),

            // Name / bank / type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        account.bankName,
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                      Text(
                        '  ·  $typeLabel',
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: Spacing.sm),

            // Balance + checkmark
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  CurrencyFormatter.compact(account.balance),
                  style: TextStyle(
                    fontSize: TypeScale.subhead,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? primaryColor
                        : AppStyles.getTextColor(context),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 4),
                  Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    size: 18,
                    color: primaryColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(AccountType type) {
    switch (type) {
      case AccountType.savings:
        return CupertinoIcons.building_2_fill;
      case AccountType.current:
        return CupertinoIcons.building_2_fill;
      case AccountType.credit:
        return CupertinoIcons.creditcard_fill;
      case AccountType.payLater:
        return CupertinoIcons.clock_fill;
      case AccountType.wallet:
        return CupertinoIcons.bag_fill;
      case AccountType.investment:
        return CupertinoIcons.chart_bar_fill;
      case AccountType.cash:
        return CupertinoIcons.money_dollar_circle_fill;
    }
  }
}
