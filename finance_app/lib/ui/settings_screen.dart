import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
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
        middle: Text('Settings', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context).withValues(alpha: 0.8),
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

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

              _buildHeader('Features'),
              _buildModernSection(context, [
                _buildToggleRow(
                  context,
                  icon: CupertinoIcons.chat_bubble_text,
                  title: 'SMS Auto Detection',
                  value: false, // Placeholder
                  color: CupertinoColors.systemIndigo,
                  onChanged: (val) {},
                ),
                _buildDivider(context),
                _buildToggleRow(
                  context,
                  icon: CupertinoIcons.doc_checkmark,
                  title: 'Statement Reconciliation',
                  value: false, // Placeholder
                  color: CupertinoColors.systemTeal,
                  onChanged: (val) {},
                ),
              ]),

              _buildHeader('Data'),
              _buildModernSection(context, [
                _buildNavRow(
                  context,
                  icon: CupertinoIcons.cloud_upload,
                  title: 'Backups',
                  color: CupertinoColors.systemPink,
                  onTap: () => _showBackupOptions(context),
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

  Widget _buildToggleRow(BuildContext context, {
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
            padding: const EdgeInsets.all(8),
            decoration: AppStyles.iconBoxDecoration(context, color),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: AppStyles.titleStyle(context)),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: CupertinoColors.activeGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(BuildContext context, {
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
              padding: const EdgeInsets.all(8),
              decoration: AppStyles.iconBoxDecoration(context, color ?? CupertinoColors.systemBlue),
              child: Icon(icon, size: 20, color: color ?? CupertinoColors.systemBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: AppStyles.titleStyle(context)),
            ),
            if (value != null) ...[
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
              const SizedBox(width: 8),
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

  void _showLockTimeoutOptions(BuildContext context, SettingsController settings) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Auto-Lock Timeout'),
        actions: [
          _buildActionSheetItem(context, 'Immediate', () => settings.setLockTimeout(0)),
          _buildActionSheetItem(context, 'After 10 seconds', () => settings.setLockTimeout(10)),
          _buildActionSheetItem(context, 'After 30 seconds', () => settings.setLockTimeout(30)),
          _buildActionSheetItem(context, 'After 1 minute', () => settings.setLockTimeout(60)),
          _buildActionSheetItem(context, 'After 5 minutes', () => settings.setLockTimeout(300)),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showThemeOptions(BuildContext context, SettingsController settings) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Appearance'),
        actions: [
          _buildActionSheetItem(context, 'Light', () => settings.setThemeMode(ThemeMode.light)),
          _buildActionSheetItem(context, 'Dark (AMOLED)', () => settings.setThemeMode(ThemeMode.dark)),
          _buildActionSheetItem(context, 'System Default', () => settings.setThemeMode(ThemeMode.system)),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
  
  void _showBackupOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Backup & Restore'),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Local Backup')),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Google Drive Backup')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
  }

  Widget _buildActionSheetItem(BuildContext context, String text, VoidCallback onPressed) {
    return CupertinoActionSheetAction(
      onPressed: () {
        onPressed();
        Navigator.pop(context);
      },
      child: Text(text),
    );
  }
}
