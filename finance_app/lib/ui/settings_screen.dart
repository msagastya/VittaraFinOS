import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/pin_recovery_controller.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/services/integrity_check_service.dart';
import 'package:vittara_fin_os/services/security/device_security_service.dart';
import 'package:vittara_fin_os/ui/backup_restore_screen.dart';
import 'package:vittara_fin_os/ui/recovery_code_save_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/styles/typography.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/landscape_scaffold.dart';
import 'package:vittara_fin_os/ui/whats_new_sheet.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppLogger logger = AppLogger();
  int _selectedSection = 0; // 0=Privacy, 1=Display, 2=Data, 3=About, 4=Danger

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsController>(context);

    final isLandscape = AppStyles.isLandscape(context);

    // ── Full settings content (portrait + landscape right panel) ────────
    Widget fullContent = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: RS.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Spacing.lg),
          // T-147: Display Name field
          _buildHeader('Profile'),
          _buildDisplayNameCard(context, settings),
          const SizedBox(height: Spacing.sm),
          _buildHeader('Privacy & Security'),
          // T-139: Security Status row
          _buildSecurityStatusCard(context, settings),
          const SizedBox(height: Spacing.sm),
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
                color: SemanticColors.warning,
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
                  subtitle: null,
                  value: _getTimeoutString(settings.lockTimeoutSeconds),
                  color: AppStyles.getSecondaryTextColor(context),
                  onTap: () => _showLockTimeoutOptions(context, settings),
                ),
              ],
              _buildDivider(context),
              _buildNavRow(
                context,
                icon: CupertinoIcons.number_square_fill,
                title: 'PIN Lock',
                subtitle: 'Set a 6-digit fallback PIN',
                value: settings.isPinEnabled ? 'Enabled' : 'Not set',
                color: SemanticColors.categories,
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
                  onTap: () => _showRecoveryCode(context, settings),
                ),
              ],
              // T-137: master toggle for sensitive-screen biometric gate
              _buildDivider(context),
              _buildToggleRow(
                context,
                icon: CupertinoIcons.lock_rotation,
                title: 'Require biometric for sensitive screens',
                subtitle: 'Archive, backup export, recovery code',
                value: settings.requireBiometricForSensitiveScreens,
                color: SemanticColors.categories,
                onChanged: settings.toggleRequireBiometricForSensitiveScreens,
              ),
            ],
          ]),
          _buildHeader('Display'),
          _buildModernSection(context, [
            _buildNavRow(
              context,
              icon: CupertinoIcons.brightness,
              title: 'Theme',
              subtitle: 'AMOLED dark / light / system',
              value: _getThemeString(settings.themeMode),
              color: AppStyles.getPrimaryColor(context),
              onTap: () => _showThemeOptions(context, settings),
            ),
            _buildDivider(context),
            // T-151: Number format toggle
            _buildToggleRow(
              context,
              icon: CupertinoIcons.textformat_123,
              title: 'Indian Number Format',
              subtitle: '1,00,000 vs 100,000',
              value: settings.numberFormatIndian,
              color: AppStyles.getSecondaryTextColor(context),
              onChanged: settings.setNumberFormatIndian,
            ),
            _buildDivider(context),
            // T-149: Accent Colour picker
            _buildNavRow(
              context,
              icon: CupertinoIcons.paintbrush_fill,
              title: 'Accent Colour',
              subtitle: '6 presets',
              value: _accentName(settings.accentColorValue),
              color: settings.accentColorValue != null
                  ? Color(settings.accentColorValue!)
                  : AppStyles.aetherTeal,
              onTap: () => _showAccentPicker(context, settings),
            ),
          ]),
          _buildHeader('Data & Backup'),
          _buildModernSection(context, [
            _buildToggleRow(
              context,
              icon: CupertinoIcons.graph_square,
              title: 'Investment Tracking',
              subtitle: 'Show investments in Quick Add',
              value: settings.isInvestmentTrackingEnabled,
              color: AppStyles.violet(context),
              onChanged: (val) => settings.toggleInvestmentTracking(val),
            ),
            _buildDivider(context),
            _buildToggleRow(
              context,
              icon: CupertinoIcons.archivebox_fill,
              title: 'Show Archived Transactions',
              subtitle: 'Include in history and search',
              value: settings.isArchivedTransactionsEnabled,
              color: AppStyles.teal(context),
              onChanged: (val) => settings.toggleArchivedTransactions(val),
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
              color: SemanticColors.error,
              onTap: () => Navigator.of(context).push(
                FadeScalePageRoute(page: const BackupRestoreScreen()),
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
            _buildDivider(context),
            _buildNavRow(
              context,
              icon: CupertinoIcons.sparkles,
              title: "What's New",
              subtitle: 'See recent feature updates',
              value: null,
              color: AppStyles.teal(context),
              onTap: () => showCupertinoModalPopup<void>(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.6),
                builder: (_) => const WhatsNewSheet(),
              ),
            ),
          ]),
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
    );

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar:
          isLandscape ? null : AppStyles.standardNavBar(context, 'Settings'),
      child: SafeArea(
        child: isLandscape
            ? LandscapeScaffold(
                railWidth: 200,
                leftRail: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LandscapeRailHeader(
                        title: 'SETTINGS', outerContext: context),
                    const RailDivider(indent: 0),
                    const SizedBox(height: 4),
                    ..._buildSettingsSectionTiles(context),
                  ],
                ),
                body: fullContent,
              )
            : fullContent,
      ),
    );
  }

  List<Widget> _buildSettingsSectionTiles(BuildContext context) {
    final sections = [
      (
        CupertinoIcons.lock_shield_fill,
        'Privacy & Security',
        AppStyles.gain(context)
      ),
      (
        CupertinoIcons.brightness,
        'Display',
        AppStyles.getPrimaryColor(context)
      ),
      (CupertinoIcons.cloud_upload, 'Data & Backup', SemanticColors.error),
      (CupertinoIcons.info_circle_fill, 'About', AppStyles.accentBlue),
      (
        CupertinoIcons.exclamationmark_triangle_fill,
        'Danger Zone',
        SemanticColors.error
      ),
    ];
    return sections.asMap().entries.map((entry) {
      final i = entry.key;
      final (icon, label, color) = entry.value;
      final isSelected = _selectedSection == i;
      return GestureDetector(
        onTap: () => setState(() => _selectedSection = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 15,
                  color: isSelected
                      ? color
                      : AppStyles.getSecondaryTextColor(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? color : AppStyles.getTextColor(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _runIntegrityCheck(BuildContext context) {
    final txCtrl = context.read<TransactionsController>();
    final accCtrl = context.read<AccountsController>();
    final issues =
        IntegrityCheckService.check(txCtrl: txCtrl, accCtrl: accCtrl);
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
                final cleaned =
                    await IntegrityCheckService.cleanupOrphanedRecords(
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

  // T-147: Display Name card
  Widget _buildDisplayNameCard(
      BuildContext context, SettingsController settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppStyles.cardDecoration(context),
      child: Row(
        children: [
          const Icon(CupertinoIcons.person_crop_circle, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoTextField(
              placeholder: 'Your name (shown in greeting)',
              controller: TextEditingController(text: settings.displayName),
              onChanged: (v) => settings.setDisplayName(v),
              style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontSize: TypeScale.body),
              placeholderStyle: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.body),
              padding: EdgeInsets.zero,
              decoration: const BoxDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  // T-139: Security Status card
  Widget _buildSecurityStatusCard(
      BuildContext context, SettingsController settings) {
    final dss = DeviceSecurityService.instance;
    final items = <(bool ok, String label)>[
      (true, 'Encrypted database'),
      (settings.isBiometricEnabled, 'Biometric enabled'),
      (settings.lockOnMinimize, 'Screenshot protection'),
      if (dss.isCompromised) (false, 'Rooted device detected'),
    ];
    final teal = AppStyles.gain(context);
    final amber = CupertinoColors.systemYellow.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppStyles.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security Status',
            style: AppStyles.titleStyle(context).copyWith(
                fontSize: TypeScale.footnote, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: items.map((item) {
              final color = item.$1 ? teal : amber;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.$1
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.exclamationmark_triangle_fill,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.$2,
                    style: TextStyle(fontSize: TypeScale.caption, color: color),
                  ),
                ],
              );
            }).toList(),
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
      padding: const EdgeInsets.only(
          left: Spacing.lg, bottom: Spacing.xs, top: Spacing.xxxl),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption(
                color: AppStyles.getSecondaryTextColor(context))
            .copyWith(letterSpacing: 1.2),
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
                Text(title,
                    style: AppTypography.callout(
                        color: AppStyles.getTextColor(context))),
                if (subtitle != null)
                  Text(subtitle,
                      style: AppTypography.footnote(
                          color: AppStyles.getSecondaryTextColor(context))),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: SemanticColors.getPrimary(context),
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
                  context, color ?? AppStyles.getPrimaryColor(context)),
              child: Icon(icon,
                  size: 20, color: color ?? AppStyles.getPrimaryColor(context)),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.callout(
                          color: AppStyles.getTextColor(context))),
                  if (subtitle != null)
                    Text(subtitle,
                        style: AppTypography.footnote(
                            color: AppStyles.getSecondaryTextColor(context))),
                ],
              ),
            ),
            if (value != null) ...[
              Text(
                value,
                style: AppTypography.footnote(
                    color: AppStyles.getSecondaryTextColor(context)),
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
          Expanded(
              child: Text(title,
                  style: AppTypography.callout(
                      color: AppStyles.getTextColor(context)))),
          Text(value,
              style: AppTypography.footnote(
                      color: AppStyles.getSecondaryTextColor(context))
                  .copyWith(fontWeight: FontWeight.w600)),
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
              decoration:
                  AppStyles.iconBoxDecoration(context, AppStyles.loss(context)),
              child: Icon(icon, size: 20, color: AppStyles.loss(context)),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.callout(
                          color: AppStyles.loss(context))),
                  Text(subtitle,
                      style: AppTypography.footnote(
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

  // T-149: Accent colour helpers
  static const _accentPresets = <(String, Color)>[
    ('Aether Teal', Color(0xFF00D4AA)),
    ('Nova Purple', Color(0xFF9B59B6)),
    ('Solar Gold', Color(0xFFF39C12)),
    ('Coral Red', Color(0xFFE74C3C)),
    ('Sky Blue', Color(0xFF3498DB)),
    ('Mint Green', Color(0xFF2ECC71)),
  ];

  String _accentName(int? colorValue) {
    if (colorValue == null) return 'Aether Teal';
    for (final (name, color) in _accentPresets) {
      if (color.value == colorValue) return name;
    }
    return 'Custom';
  }

  void _showAccentPicker(BuildContext context, SettingsController settings) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => RLayout.tabletConstrain(
        ctx,
        CupertinoActionSheet(
          title: const Text('Accent Colour'),
          actions: _accentPresets.map((preset) {
            final (name, color) = preset;
            final isSelected = settings.accentColorValue == color.value ||
                (settings.accentColorValue == null && name == 'Aether Teal');
            return CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                settings.setAccentColor(name == 'Aether Teal' ? null : color);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(name),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.checkmark, size: 14),
                  ],
                ],
              ),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
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
      builder: (context) => RLayout.tabletConstrain(
        context,
        CupertinoActionSheet(
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
      ),
    );
  }

  void _showPinSetupSheet(BuildContext context, SettingsController settings) {
    if (settings.isPinEnabled) {
      // Already set — offer to change or clear
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => RLayout.tabletConstrain(
          ctx,
          CupertinoActionSheet(
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
      builder: (ctx) => RLayout.tabletConstrain(
        ctx,
        StatefulBuilder(
          builder: (ctx, setS) {
            final dotColor = error ? AppStyles.loss(ctx) : AppStyles.accentBlue;
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
                    Icon(CupertinoIcons.number_square_fill,
                        size: 36, color: SemanticColors.categories),
                    const SizedBox(height: 12),
                    Text(
                      inConfirm ? 'Confirm PIN' : 'Set New PIN',
                      style: TextStyle(
                        color: AppStyles.getTextColor(ctx),
                        fontSize: RT.title2(ctx),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
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
                                            fontSize: RT.largeTitle(ctx),
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
      builder: (context) => RLayout.tabletConstrain(
        context,
        CupertinoActionSheet(
          title: const Text('Appearance'),
          actions: [
            _buildActionSheetItem(
                context, 'Light', () => settings.setThemeMode(ThemeMode.light)),
            _buildActionSheetItem(
                context, 'Dark', () => settings.setThemeMode(ThemeMode.dark)),
            _buildActionSheetItem(context, 'System Default',
                () => settings.setThemeMode(ThemeMode.system)),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
