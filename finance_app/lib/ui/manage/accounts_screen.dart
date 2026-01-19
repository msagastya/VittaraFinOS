import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AppLogger logger = AppLogger();
  final List<Account> _accounts = [];

  void _showAddOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final settings = Provider.of<SettingsController>(context, listen: false);
        final showInvestment = settings.isInvestmentTrackingEnabled;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Add New Account',
                    style: AppStyles.titleStyle(context).copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the type of account you want to add',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOptionCard(
                          context,
                          title: 'Bank\nAccount',
                          icon: CupertinoIcons.building_2_fill,
                          color: CupertinoColors.systemBlue,
                          onTap: () {
                            Navigator.pop(context);
                            _startWizard(isInvestment: false);
                          },
                        ),
                      ),
                      if (showInvestment) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildOptionCard(
                            context,
                            title: 'Investment\nAccount',
                            icon: CupertinoIcons.graph_square_fill,
                            color: CupertinoColors.systemPurple,
                            onTap: () {
                              Navigator.pop(context);
                              _startWizard(isInvestment: true);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return BouncyButton(
      onPressed: onTap,
      child: Container(
        height: 160,
        decoration: AppStyles.cardDecoration(context).copyWith(
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppStyles.titleStyle(context).copyWith(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startWizard({required bool isInvestment}) async {
    final Account? result = await Navigator.push<Account>(
      context,
      FadeScalePageRoute(page: AccountWizard(isInvestment: isInvestment)),
    );

    if (result != null) {
      setState(() {
        _accounts.add(result);
      });
      logger.info('Added account: ${result.name}', context: 'AccountsScreen');
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _accounts.removeAt(oldIndex);
      _accounts.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Accounts', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Stack(
        children: [
          if (_accounts.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.creditcard,
                    size: 64,
                    color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Accounts Added',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            SafeArea(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _accounts.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  return _buildAccountCard(_accounts[index]);
                },
              ),
            ),
          Positioned(
            right: 16,
            bottom: 32,
            child: FadingFloatingActionButton(
              onPressed: () => _showAddOptions(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Account account) {
    return Container(
      key: ValueKey(account.id),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppStyles.cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: AppStyles.iconBoxDecoration(context, account.color),
              child: Center(
                child: Icon(
                  account.type == AccountType.investment 
                      ? CupertinoIcons.chart_bar_square_fill 
                      : CupertinoIcons.building_2_fill,
                  color: account.color,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name, style: AppStyles.titleStyle(context)),
                  const SizedBox(height: 4),
                  Text(
                    '${account.bankName} • ${account.type.name.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.getSecondaryTextColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${account.balance.toStringAsFixed(2)}',
                  style: AppStyles.titleStyle(context).copyWith(
                    color: AppStyles.accentBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FadingFloatingActionButton extends StatefulWidget {
  final VoidCallback onPressed;
  const FadingFloatingActionButton({super.key, required this.onPressed});
  @override
  State<FadingFloatingActionButton> createState() => _FadingFloatingActionButtonState();
}

class _FadingFloatingActionButtonState extends State<FadingFloatingActionButton> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(_controller);
    _startInactivityTimer();
  }
  
  void _startInactivityTimer() {
    _timer?.cancel();
    if (_controller.value > 0) _controller.reverse();
    _timer = Timer(const Duration(seconds: 4), () { if (mounted) _controller.forward(); });
  }
  
  @override
  void dispose() { _timer?.cancel(); _controller.dispose(); super.dispose(); }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: GestureDetector(
            onTapDown: (_) => _startInactivityTimer(),
            onTap: () { _startInactivityTimer(); widget.onPressed(); },
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemBlue.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4)
                  )
                ],
              ),
              child: const Icon(CupertinoIcons.add, color: Colors.white, size: 28),
            ),
          ),
        );
      },
    );
  }
}