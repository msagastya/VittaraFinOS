import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/backup_restore_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
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
      navigationBar: CupertinoNavigationBar(
        middle: Text('Settings',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor:
            AppStyles.getBackground(context).withValues(alpha: 0.8),
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Spacing.xl),

              _buildHeader('Security'),
              _buildModernSection(context, [
                _buildToggleRow(
                  context,
                  icon: CupertinoIcons.viewfinder,
                  title: 'Biometric Auth',
                  value: settings.isBiometricEnabled,
                  color: CupertinoColors.systemGreen,
                  onChanged: (val) => settings.toggleBiometric(val),
                ),
                if (settings.isBiometricEnabled) ...[
                  _buildDivider(context),
                  _buildToggleRow(
                    context,
                    icon: CupertinoIcons.lock_shield,
                    title: 'Lock on Minimize',
                    value: settings.lockOnMinimize,
                    color: CupertinoColors.systemOrange,
                    onChanged: (val) {
                      settings.toggleLockOnMinimize(val);
                      if (val) _showLockTimeoutOptions(context, settings);
                    },
                  ),
                  if (settings.lockOnMinimize) ...[
                    _buildDivider(context),
                    _buildNavRow(
                      context,
                      icon: CupertinoIcons.time,
                      title: 'Lock Timeout',
                      value: _getTimeoutString(settings.lockTimeoutSeconds),
                      color: CupertinoColors.systemGrey,
                      onTap: () => _showLockTimeoutOptions(context, settings),
                    ),
                  ],
                  _buildDivider(context),
                  _buildNavRow(
                    context,
                    icon: CupertinoIcons.number_square_fill,
                    title: 'PIN Lock',
                    value: settings.isPinEnabled ? 'Enabled' : 'Not set',
                    color: CupertinoColors.systemPurple,
                    onTap: () => _showPinSetupSheet(context, settings),
                  ),
                ],
              ]),

              _buildHeader('Appearance'),
              _buildModernSection(context, [
                _buildNavRow(
                  context,
                  icon: CupertinoIcons.brightness,
                  title: 'Theme',
                  value: _getThemeString(settings.themeMode),
                  color: CupertinoColors.systemBlue,
                  onTap: () => _showThemeOptions(context, settings),
                ),
              ]),

              // --- FEATURES ---
              _buildHeader('Features'),
              _buildModernSection(context, [
                _buildToggleRow(
                  context,
                  icon: CupertinoIcons.graph_square,
                  title: 'Investment Tracking',
                  value: settings.isInvestmentTrackingEnabled,
                  color: CupertinoColors.systemPurple,
                  onChanged: (val) => settings.toggleInvestmentTracking(val),
                ),
                _buildDivider(context),
                _buildToggleRow(
                  context,
                  icon: CupertinoIcons.archivebox_fill,
                  title: 'Show Archived Transactions',
                  value: settings.isArchivedTransactionsEnabled,
                  color: CupertinoColors.systemPurple,
                  onChanged: (val) => settings.toggleArchivedTransactions(val),
                ),
              ]),

              _buildHeader('Data'),
              _buildModernSection(context, [
                _buildNavRow(
                  context,
                  icon: CupertinoIcons.cloud_upload,
                  title: 'Backups',
                  color: CupertinoColors.systemPink,
                  onTap: () => Navigator.of(context).push(
                    FadeScalePageRoute(page: const BackupRestoreScreen()),
                  ),
                ),
              ]),

              const SizedBox(height: 40),
            ],
          ),
        ),
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
        color: AppStyles.isDarkMode(context)
            ? const Color(0xFF2C2C2E)
            : CupertinoColors.systemGrey6,
      ),
    );
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
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
          Expanded(
            child: Text(title, style: AppStyles.titleStyle(context)),
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
    Color? color,
    String? value,
    required VoidCallback onTap,
  }) {
    return BouncyButton(
      scaleFactor: 0.98,
      onPressed: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              child: Text(title, style: AppStyles.titleStyle(context)),
            ),
            if (value != null) ...[
              Text(
                value,
                style: TextStyle(
                  fontSize: TypeScale.headline,
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

  void _showPinSetupSheet(
      BuildContext context, SettingsController settings) {
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
          final isDark = AppStyles.isDarkMode(ctx);
          final dotColor = error ? CupertinoColors.systemRed : AppStyles.accentBlue;
          final current = inConfirm ? confirmDigits! : digits;

          void onDigit(String d) {
            if (current.length >= 6) return;
            setS(() { current.add(d); error = false; });
            if (current.length == 6) {
              if (!isSetup) return; // shouldn't happen
              if (!inConfirm) {
                setS(() => inConfirm = true);
              } else {
                if (digits.join() == confirmDigits!.join()) {
                  settings.setPin(digits.join());
                  Navigator.pop(ctx);
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
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 36, height: 5,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Icon(CupertinoIcons.number_square_fill,
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
                          ? CupertinoColors.systemRed
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
                        width: 16, height: 16,
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
                                    width: 72, height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? const Color(0xFF2C2C2E)
                                          : CupertinoColors.systemGrey5,
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

  void _showThemeOptions(BuildContext context, SettingsController settings) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Appearance'),
        actions: [
          _buildActionSheetItem(
              context, 'Light', () => settings.setThemeMode(ThemeMode.light)),
          _buildActionSheetItem(context, 'Dark — True AMOLED (Pure Black)',
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
