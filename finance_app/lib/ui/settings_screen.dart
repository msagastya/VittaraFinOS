import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/pin_recovery_controller.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/services/integrity_check_service.dart';
import 'package:vittara_fin_os/ui/backup_restore_screen.dart';
import 'package:vittara_fin_os/ui/recovery_code_save_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppLogger logger = AppLogger();

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsController>(context);

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text('Settings',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor:
            AppStyles.getBackground(context).withValues(alpha: 0.8),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (AppStyles.isLandscape(context)) _buildLandscapeNavBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Spacing.lg),

                    // ── PRIVACY & SECURITY ──────────────────────────────
                    _buildHeader('Privacy & Security'),
                    _buildModernSection(context, [
                      _buildToggleRow(
                        context,
                        icon: CupertinoIcons.viewfinder,
                        title: 'Biometric Auth',
                        subtitle: 'FaceID / fingerprint unlock',
                        value: settings.isBiometricEnabled,
                        color: AppStyles.gain(context),
                        onChanged: (val) => settings.toggleBiometric(val),
                      ),
                      if (settings.isBiometricEnabled) ...[
                        _buildDivider(context),
                        _buildToggleRow(
                          context,
                          icon: CupertinoIcons.lock_shield,
                          title: 'Lock on Minimize',
                          subtitle: 'Lock app when sent to background',
                          value: settings.lockOnMinimize,
                          color: CupertinoColors.systemOrange,
                          onChanged: (val) {
                            settings.toggleLockOnMinimize(val);
                            if (val)
                              _showLockTimeoutOptions(context, settings);
                          },
                        ),
                        if (settings.lockOnMinimize) ...[
                          _buildDivider(context),
                          _buildNavRow(
                            context,
                            icon: CupertinoIcons.time,
                            title: 'Lock Timeout',
                            subtitle: null,
                            value: _getTimeoutString(
                                settings.lockTimeoutSeconds),
                            color: CupertinoColors.systemGrey,
                            onTap: () =>
                                _showLockTimeoutOptions(context, settings),
                          ),
                        ],
                        _buildDivider(context),
                        _buildNavRow(
                          context,
                          icon: CupertinoIcons.number_square_fill,
                          title: 'PIN Lock',
                          subtitle: 'Set a 6-digit fallback PIN',
                          value: settings.isPinEnabled ? 'Enabled' : 'Not set',
                          color: CupertinoColors.systemPurple,
                          onTap: () => _showPinSetupSheet(context, settings),
                        ),
                        if (settings.isPinEnabled) ...[
                          _buildDivider(context),
                          _buildNavRow(
                            context,
                            icon: CupertinoIcons.shield_lefthalf_fill,
                            title: 'Recovery Code',
                            subtitle: 'View your 24-word recovery phrase',
                            value: 'View',
                            color: AppStyles.gold(context),
                            onTap: () =>
                                _showRecoveryCode(context, settings),
                          ),
                        ],
                      ],
                    ]),

                    // ── DISPLAY ─────────────────────────────────────────
                    _buildHeader('Display'),
                    _buildModernSection(context, [
                      _buildNavRow(
                        context,
                        icon: CupertinoIcons.brightness,
                        title: 'Theme',
                        subtitle: 'AMOLED dark / light / system',
                        value: _getThemeString(settings.themeMode),
                        color: CupertinoColors.systemBlue,
                        onTap: () => _showThemeOptions(context, settings),
                      ),
                    ]),

                    // ── DATA & BACKUP ────────────────────────────────────
                    _buildHeader('Data & Backup'),
                    _buildModernSection(context, [
                      _buildToggleRow(
                        context,
                        icon: CupertinoIcons.graph_square,
                        title: 'Investment Tracking',
                        subtitle: 'Show investments in Quick Add',
                        value: settings.isInvestmentTrackingEnabled,
                        color: AppStyles.violet(context),
                        onChanged: (val) =>
                            settings.toggleInvestmentTracking(val),
                      ),
                      _buildDivider(context),
                      _buildToggleRow(
                        context,
                        icon: CupertinoIcons.archivebox_fill,
                        title: 'Show Archived Transactions',
                        subtitle: 'Include in history and search',
                        value: settings.isArchivedTransactionsEnabled,
                        color: AppStyles.teal(context),
                        onChanged: (val) =>
                            settings.toggleArchivedTransactions(val),
                      ),
                      _buildDivider(context),
                      _buildToggleRow(
                        context,
                        icon: CupertinoIcons.chat_bubble_text_fill,
                        title: 'SMS Scanning',
                        subtitle: 'Auto-detect bank transactions',
                        value: settings.isSmsEnabled,
                        color: AppStyles.info(context),
                        onChanged: (val) => settings.toggleSmsScanning(val),
                      ),
                      _buildDivider(context),
                      _buildNavRow(
                        context,
                        icon: CupertinoIcons.cloud_upload,
                        title: 'Backup & Restore',
                        subtitle: 'Encrypted device backup',
                        value: null,
                        color: CupertinoColors.systemPink,
                        onTap: () => Navigator.of(context).push(
                          FadeScalePageRoute(
                              page: const BackupRestoreScreen()),
                        ),
                      ),
                      _buildDivider(context),
                      _buildNavRow(
                        context,
                        icon: CupertinoIcons.checkmark_shield,
                        title: 'Data Health',
                        subtitle: 'Check for orphaned records',
                        value: null,
                        color: AppStyles.accentBlue,
                        onTap: () => _runIntegrityCheck(context),
                      ),
                    ]),

                    // ── ABOUT ────────────────────────────────────────────
                    _buildHeader('About'),
                    _buildModernSection(context, [
                      _buildNavRow(
                        context,
                        icon: CupertinoIcons.info_circle_fill,
                        title: 'About VittaraFinOS',
                        subtitle: null,
                        value: 'v1.0.0',
                        color: AppStyles.getPrimaryColor(context),
                        onTap: () => _showAboutDialog(context),
                      ),
                    ]),

                    // ── DANGER ZONE ──────────────────────────────────────
                    _buildHeader('Danger Zone'),
                    _buildModernSection(context, [
                      _buildDangerRow(
                        context,
                        icon: CupertinoIcons.refresh,
                        title: 'Reset Settings',
                        subtitle: 'Restore all settings to defaults',
                        onTap: () => _confirmResetSettings(context, settings),
                      ),
                    ]),

                    const SizedBox(height: Spacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeNavBar(BuildContext context) {
    return Container(
      height: 40,
      color: AppStyles.getBackground(context),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => Navigator.of(context).maybePop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.chevron_left,
                    size: 16,
                    color: AppStyles.getPrimaryColor(context)),
                const SizedBox(width: 2),
                Text('Back',
                    style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getPrimaryColor(context))),
              ],
            ),
          ),
          const Spacer(),
          Text('SETTINGS',
              style: TextStyle(
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppStyles.getTextColor(context))),
          const Spacer(),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  void _runIntegrityCheck(BuildContext context) {
    final txCtrl = context.read<TransactionsController>();
    final accCtrl = context.read<AccountsController>();
    final issues = IntegrityCheckService.check(txCtrl: txCtrl, accCtrl: accCtrl);
    final message = issues.isEmpty
        ? 'No issues found. Your data looks healthy!'
        : issues.join('\n');
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(issues.isEmpty ? 'Data Health: OK' : 'Issues Found'),
        content: Text(message),
        actions: [
          if (issues.isNotEmpty)
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(ctx);
                final cleaned = await IntegrityCheckService.cleanupOrphanedRecords(
                  txCtrl: txCtrl,
                  accCtrl: accCtrl,
                );
                if (context.mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (c) => CupertinoAlertDialog(
                      title: const Text('Cleanup Complete'),
                      content: Text('$cleaned record(s) fixed.'),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Clean Up'),
            ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmResetSettings(
      BuildContext context, SettingsController settings) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Reset Settings?'),
        content: const Text(
          'This will restore all app settings to their defaults. '
          'Your financial data will not be affected.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await settings.resetToDefaults();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSection(BuildContext context, List<Widget> children) {
    return Container(
      decoration: AppStyles.cardDecoration(context),
      child: Column(children: children),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 24),
      child: Text(
        title.toUpperCase(),
        style: AppStyles.headerStyle(context),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Container(
        height: 1,
        color: AppStyles.getDividerColor(context),
      ),
    );
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: AppStyles.iconBoxDecoration(context, color),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppStyles.titleStyle(context)),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(context))),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: CupertinoColors.activeGreen,
            onChanged: (v) {
              Haptics.light();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
    String? value,
    required VoidCallback onTap,
  }) {
    return BouncyButton(
      scaleFactor: 0.98,
      onPressed: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: AppStyles.iconBoxDecoration(
                  context, color ?? CupertinoColors.systemBlue),
              child: Icon(icon,
                  size: 20, color: color ?? CupertinoColors.systemBlue),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppStyles.titleStyle(context)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context))),
                ],
              ),
            ),
            if (value != null) ...[
              Text(
                value,
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(width: Spacing.sm),
            ],
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: AppStyles.iconBoxDecoration(context, color),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(child: Text(title, style: AppStyles.titleStyle(context))),
          Text(value,
              style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.getSecondaryTextColor(context))),
        ],
      ),
    );
  }

  Widget _buildDangerRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return BouncyButton(
      scaleFactor: 0.98,
      onPressed: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: AppStyles.iconBoxDecoration(
                  context, AppStyles.loss(context)),
              child: Icon(icon, size: 20, color: AppStyles.loss(context)),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppStyles.titleStyle(context).copyWith(
                          color: AppStyles.loss(context))),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(context))),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 16,
                color: AppStyles.loss(context).withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  String _getTimeoutString(int seconds) {
    if (seconds == 0) return 'Immediate';
    if (seconds == 10) return '10 sec';
    if (seconds == 30) return '30 sec';
    if (seconds == 60) return '1 min';
    if (seconds == 300) return '5 min';
    return '$seconds s';
  }

  String _getThemeString(ThemeMode mode) {
    if (mode == ThemeMode.light) return 'Light';
    if (mode == ThemeMode.dark) return 'Dark';
    return 'System';
  }

  void _showLockTimeoutOptions(
      BuildContext context, SettingsController settings) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Auto-Lock Timeout'),
        actions: [
          _buildActionSheetItem(
              context, 'Immediate', () => settings.setLockTimeout(0)),
          _buildActionSheetItem(
              context, 'After 10 seconds', () => settings.setLockTimeout(10)),
          _buildActionSheetItem(
              context, 'After 30 seconds', () => settings.setLockTimeout(30)),
          _buildActionSheetItem(
              context, 'After 1 minute', () => settings.setLockTimeout(60)),
          _buildActionSheetItem(
              context, 'After 5 minutes', () => settings.setLockTimeout(300)),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showPinSetupSheet(BuildContext context, SettingsController settings) {
    if (settings.isPinEnabled) {
      // Already set — offer to change or clear
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text('PIN Lock'),
          message: const Text('Your PIN is currently set.'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _showPinEntryDialog(context, settings, isSetup: true);
              },
              child: const Text('Change PIN'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                settings.clearPin();
                Navigator.pop(ctx);
              },
              child: const Text('Remove PIN'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      _showPinEntryDialog(context, settings, isSetup: true);
    }
  }

  void _showPinEntryDialog(BuildContext context, SettingsController settings,
      {required bool isSetup}) {
    final List<String> digits = [];
    final List<String>? confirmDigits = isSetup ? [] : null;
    bool inConfirm = false;
    bool error = false;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final dotColor =
              error ? AppStyles.loss(ctx) : AppStyles.accentBlue;
          final current = inConfirm ? confirmDigits! : digits;

          Future<void> onDigit(String d) async {
            if (current.length >= 6) return;
            setS(() {
              current.add(d);
              error = false;
            });
            if (current.length == 6) {
              if (!isSetup) return; // shouldn't happen
              if (!inConfirm) {
                setS(() => inConfirm = true);
              } else {
                if (digits.join() == confirmDigits!.join()) {
                  await settings.setPin(digits.join());
                  Navigator.pop(ctx);
                  // Generate recovery code and show save screen
                  final code = await PinRecoveryController.instance
                      .generateAndStoreRecoveryCode();
                  if (context.mounted) {
                    Navigator.of(context).push(CupertinoPageRoute(
                      builder: (_) => RecoveryCodeSaveScreen(
                        recoveryCode: code,
                        onConfirmed: () => Navigator.of(context).pop(),
                      ),
                    ));
                  }
                } else {
                  setS(() {
                    error = true;
                    confirmDigits.clear();
                  });
                }
              }
            }
          }

          void onBack() {
            if (current.isEmpty) return;
            setS(() => current.removeLast());
          }

          return Container(
            height: AppStyles.sheetMaxHeight(ctx),
            decoration: AppStyles.bottomSheetDecoration(ctx),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const ModalHandle(),
                  const SizedBox(height: 24),
                  const Icon(CupertinoIcons.number_square_fill,
                      size: 36, color: CupertinoColors.systemPurple),
                  const SizedBox(height: 12),
                  Text(
                    inConfirm ? 'Confirm PIN' : 'Set New PIN',
                    style: TextStyle(
                      color: AppStyles.getTextColor(ctx),
                      fontSize: TypeScale.title2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error
                        ? 'PINs do not match. Try again.'
                        : inConfirm
                            ? 'Re-enter your 6-digit PIN'
                            : 'Choose a 6-digit PIN',
                    style: TextStyle(
                      color: error
                          ? AppStyles.loss(ctx)
                          : AppStyles.getSecondaryTextColor(ctx),
                      fontSize: TypeScale.body,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) {
                      final filled = i < current.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? dotColor : Colors.transparent,
                          border: Border.all(color: dotColor, width: 1.5),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        for (final row in [
                          ['1', '2', '3'],
                          ['4', '5', '6'],
                          ['7', '8', '9'],
                          ['', '0', '⌫'],
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: row.map((label) {
                                if (label.isEmpty) {
                                  return const SizedBox(width: 72);
                                }
                                return GestureDetector(
                                  onTap: () {
                                    if (label == '⌫') {
                                      onBack();
                                    } else {
                                      onDigit(label);
                                    }
                                  },
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppStyles.getCardColor(ctx),
                                    ),
                                    child: Center(
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: AppStyles.getTextColor(ctx),
                                          fontSize: 24,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRecoveryCode(
      BuildContext context, SettingsController settings) async {
    // Require authentication before revealing recovery code
    final authed = await settings.authenticateArchivedAccess(
        reason: 'Authenticate to view your recovery code');
    if (!authed || !context.mounted) return;

    final hasCode = await PinRecoveryController.instance.hasRecoveryCode();
    if (!context.mounted) return;

    if (!hasCode) {
      // No code yet — generate one now
      final code =
          await PinRecoveryController.instance.generateAndStoreRecoveryCode();
      if (!context.mounted) return;
      Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => RecoveryCodeSaveScreen(
          recoveryCode: code,
          onConfirmed: () => Navigator.of(context).pop(),
        ),
      ));
    } else {
      // Already exists — regenerate a fresh one and show it
      final code =
          await PinRecoveryController.instance.generateAndStoreRecoveryCode();
      if (!context.mounted) return;
      Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => RecoveryCodeSaveScreen(
          recoveryCode: code,
          onConfirmed: () => Navigator.of(context).pop(),
        ),
      ));
    }
  }

  void _showAboutDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('VittaraFinOS'),
        content: const Text(
          'Version 1.0.0\n\n'
          'All your financial data is stored 100% on-device — '
          'no cloud sync, no servers, no third-party access.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showThemeOptions(BuildContext context, SettingsController settings) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Appearance'),
        actions: [
          _buildActionSheetItem(
              context, 'Light', () => settings.setThemeMode(ThemeMode.light)),
          _buildActionSheetItem(context, 'Dark',
              () => settings.setThemeMode(ThemeMode.dark)),
          _buildActionSheetItem(context, 'System Default',
              () => settings.setThemeMode(ThemeMode.system)),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildActionSheetItem(
      BuildContext context, String text, VoidCallback onPressed) {
    return CupertinoActionSheetAction(
      onPressed: () {
        onPressed();
        Navigator.pop(context);
      },
      child: Text(text),
    );
  }
}
