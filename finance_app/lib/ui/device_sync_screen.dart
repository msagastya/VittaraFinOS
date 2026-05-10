import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/backup_restore_service.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/dashboard_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/investment_type_preferences_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_controller.dart';
import 'package:vittara_fin_os/logic/payment_apps_controller.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/logic/tags_controller.dart';
import 'package:vittara_fin_os/logic/transactions_archive_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/services/device_sync_service.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';

class DeviceSyncScreen extends StatefulWidget {
  const DeviceSyncScreen({super.key});

  @override
  State<DeviceSyncScreen> createState() => _DeviceSyncScreenState();
}

class _DeviceSyncScreenState extends State<DeviceSyncScreen> {
  final _deviceNameController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  bool _showSecret = false;
  DeviceSyncState? _state;
  Map<String, dynamic>? _lastSummary;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final state = await DeviceSyncService.state();
    if (!mounted) return;
    setState(() {
      _state = state;
      _deviceNameController.text = state.deviceName;
    });
  }

  Future<void> _savePairing() async {
    final passphrase = _passphraseController.text.trim();
    final confirm = _confirmController.text.trim();
    if (passphrase.length < 10) {
      toast.showError('Use at least 10 characters for sync passphrase');
      return;
    }
    if (passphrase != confirm) {
      toast.showError('Sync passphrases do not match');
      return;
    }

    setState(() => _busy = true);
    try {
      await DeviceSyncService.savePairing(
        deviceName: _deviceNameController.text,
        passphrase: passphrase,
      );
      _passphraseController.clear();
      _confirmController.clear();
      await _loadState();
      toast.showSuccess('Device pairing saved');
    } catch (error) {
      toast.showError(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearPairing() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Remove sync pairing?'),
        content: const Text(
          'Future sync packages will need the passphrase again. Existing app data is not deleted.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await DeviceSyncService.clearPairing();
    await _loadState();
    toast.showSuccess('Sync pairing removed');
  }

  Future<void> _createSyncPackage() async {
    final state = _state;
    if (state == null || !state.isPaired) {
      toast.showError('Save a pairing passphrase first');
      return;
    }

    setState(() => _busy = true);
    final result = await DeviceSyncService.createSyncPackage();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastSummary = result.details;
    });
    await _loadState();

    if (!result.success || result.filePath == null) {
      toast.showError(result.message);
      return;
    }
    await Share.shareXFiles(
      [XFile(result.filePath!)],
      subject: 'VittaraFinOS Sync Package',
      text: 'Encrypted VittaraFinOS sync package for your trusted device.',
    );
  }

  Future<void> _importSyncPackage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['vittara_enc', 'json', 'vittara_backup'],
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    String? rawContent;
    if (file.bytes != null) {
      rawContent = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      rawContent = await File(file.path!).readAsString();
    }
    if (!mounted || rawContent == null || rawContent.trim().isEmpty) {
      toast.showError('Could not read selected sync package');
      return;
    }

    String rawJson = rawContent;
    if (file.name.toLowerCase().endsWith('.vittara_enc')) {
      final stored = await DeviceSyncService.storedPassphrase();
      final password =
          stored == null || stored.isEmpty ? await _promptPassphrase() : stored;
      if (!mounted || password == null) return;
      try {
        rawJson = BackupRestoreService.decryptJsonWithPassword(
          rawContent,
          password,
        );
      } catch (error) {
        toast.showError(error.toString().replaceFirst('FormatException: ', ''));
        return;
      }
    }

    final inspect = await BackupRestoreService.inspectBackupJson(rawJson);
    if (!mounted) return;
    if (!inspect.success) {
      toast.showError('Invalid sync package: ${inspect.message}');
      return;
    }

    final txCount = inspect.details?['transactionCount'] ?? 0;
    final accountCount = inspect.details?['accountCount'] ?? 0;
    final ok = await _confirmSyncApply(
      txCount: txCount,
      accountCount: accountCount,
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final result = await BackupRestoreService.restoreFromJson(rawJson);
    if (result.success) {
      await DeviceSyncService.markImported();
      await _reloadAllControllers();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastSummary = result.details;
    });
    await _loadState();

    if (result.success) {
      toast.showSuccess('Sync applied');
    } else {
      toast.showError(result.message);
    }
  }

  Future<String?> _promptPassphrase() async {
    final controller = TextEditingController();
    bool obscure = true;
    return showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Sync passphrase'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CupertinoTextField(
              controller: controller,
              autofocus: true,
              obscureText: obscure,
              placeholder: 'Enter pairing passphrase',
              suffix: GestureDetector(
                onTap: () => setDialogState(() => obscure = !obscure),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmSyncApply({
    required Object txCount,
    required Object accountCount,
  }) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Apply sync package?'),
        content: Text(
          'This package has $txCount transactions and $accountCount accounts. Vittara will merge and dedupe records on this device.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apply Sync'),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadAllControllers() async {
    await context.read<AccountsController>().loadAccounts();
    await context.read<TransactionsController>().loadTransactions();
    await context.read<InvestmentsController>().loadInvestments();
    await context.read<CategoriesController>().loadCategories();
    await context.read<ContactsController>().loadContacts();
    await context.read<TagsController>().loadTags();
    await context.read<PaymentAppsController>().loadApps();
    await context.read<LendingBorrowingController>().loadRecords();
    await context.read<SettingsController>().loadSettings();
    await context.read<TransactionsArchiveController>().reloadFromStorage();
    await context.read<GoalsController>().reloadFromStorage();
    await context.read<BudgetsController>().reloadFromStorage();
    await context.read<DashboardController>().initialize();
    await context.read<InvestmentTypePreferencesController>().loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final isWide = MediaQuery.of(context).size.width >= 820;
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context)
          ? null
          : AppStyles.standardNavBar(context, 'Device Sync'),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(gradient: AppStyles.backgroundGradient(context)),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 36 : Spacing.lg,
              vertical: Spacing.lg,
            ),
            children: [
              _buildHero(context, state),
              const SizedBox(height: Spacing.lg),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPairingCard(context, state)),
                    const SizedBox(width: Spacing.lg),
                    Expanded(child: _buildSyncActionsCard(context, state)),
                  ],
                )
              else ...[
                _buildPairingCard(context, state),
                const SizedBox(height: Spacing.lg),
                _buildSyncActionsCard(context, state),
              ],
              const SizedBox(height: Spacing.lg),
              _buildRulesCard(context),
              if (_lastSummary != null) ...[
                const SizedBox(height: Spacing.lg),
                _buildSummaryCard(context, _lastSummary!),
              ],
              if (_busy) ...[
                const SizedBox(height: Spacing.lg),
                const Center(child: CupertinoActivityIndicator(radius: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, DeviceSyncState? state) {
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: AppStyles.heroCardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: AppStyles.iconBoxDecoration(context, AppStyles.aetherTeal),
            child: const Icon(
              CupertinoIcons.arrow_2_circlepath,
              color: AppStyles.aetherTeal,
              size: 26,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mobile to Mac Sync',
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: TypeScale.title2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Daily entry on mobile. Professional review on Mac. Sync only when you explicitly create and apply an encrypted package.',
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(context, state?.isPaired == true ? 'Paired' : 'Not paired'),
                    _pill(context, 'Manual only'),
                    _pill(context, 'Encrypted'),
                    _pill(context, 'Dedupe merge'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingCard(BuildContext context, DeviceSyncState? state) {
    return _card(
      context,
      title: 'One-time pairing',
      subtitle: 'Use the same passphrase on mobile and Mac. It stays in secure storage and is never uploaded.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoTextField(
            controller: _deviceNameController,
            placeholder: 'Device name, e.g. Suyash Mac',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(CupertinoIcons.device_laptop),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _passphraseController,
            placeholder: state?.isPaired == true
                ? 'New sync passphrase'
                : 'Sync passphrase',
            obscureText: !_showSecret,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(CupertinoIcons.lock_shield),
            ),
            suffix: GestureDetector(
              onTap: () => setState(() => _showSecret = !_showSecret),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  _showSecret ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          CupertinoTextField(
            controller: _confirmController,
            placeholder: 'Confirm passphrase',
            obscureText: !_showSecret,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(CupertinoIcons.checkmark_shield),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: _busy ? null : _savePairing,
                  child: Text(state?.isPaired == true ? 'Update Pairing' : 'Save Pairing'),
                ),
              ),
              if (state?.isPaired == true) ...[
                const SizedBox(width: Spacing.sm),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: _busy ? null : _clearPairing,
                  child: const Text('Remove'),
                ),
              ],
            ],
          ),
          if (state?.pairedAt != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              'Paired ${DateFormatter.format(state!.pairedAt!)}',
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.footnote,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncActionsCard(BuildContext context, DeviceSyncState? state) {
    return _card(
      context,
      title: 'Sync actions',
      subtitle: 'Create on mobile, apply on Mac. Or use the same flow in reverse when needed.',
      child: Column(
        children: [
          _actionTile(
            context,
            title: 'Create Sync Package',
            subtitle: 'Build encrypted data package and share/save it.',
            icon: CupertinoIcons.arrow_up_doc_fill,
            color: AppStyles.aetherTeal,
            onTap: state?.isPaired == true && !_busy ? _createSyncPackage : null,
          ),
          const SizedBox(height: Spacing.sm),
          _actionTile(
            context,
            title: 'Apply Sync Package',
            subtitle: 'Pick package from Files/AirDrop and update this device.',
            icon: CupertinoIcons.tray_arrow_down_fill,
            color: CupertinoColors.systemIndigo,
            onTap: _busy ? null : _importSyncPackage,
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: _metric(
                  context,
                  'Last export',
                  _formatDate(state?.lastExportAt),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _metric(
                  context,
                  'Last import',
                  _formatDate(state?.lastImportAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard(BuildContext context) {
    final secondary = AppStyles.getSecondaryTextColor(context);
    return _card(
      context,
      title: 'Sync contract',
      subtitle: 'This is intentionally not invisible background sync.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rule(context, 'No two devices sync automatically. User action is required.'),
          _rule(context, 'Every package is password-encrypted before sharing.'),
          _rule(context, 'Import performs merge + dedupe, so repeated syncs are safe.'),
          _rule(context, 'Stocks/MF price refresh can still use the existing online APIs. Your personal data sync stays local/file-based.'),
          const SizedBox(height: Spacing.sm),
          Text(
            'Next hardening step: local network pairing over QR + device token. The current version gives the secure manual foundation without adding a server.',
            style: TextStyle(color: secondary, fontSize: TypeScale.footnote),
          ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppStyles.titleStyle(context).copyWith(fontSize: TypeScale.title3),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              height: 1.3,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          child,
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return BouncyButton(
      onPressed: onTap ?? () {},
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppStyles.isDarkMode(context) ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppStyles.titleStyle(context)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: AppStyles.getSecondaryTextColor(context),
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppStyles.getDividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.caption,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: AppStyles.titleStyle(context)),
        ],
      ),
    );
  }

  Widget _rule(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.checkmark_seal_fill, size: 16, color: AppStyles.aetherTeal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppStyles.getTextColor(context), height: 1.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppStyles.aetherTeal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.full),
        border: Border.all(color: AppStyles.aetherTeal.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppStyles.aetherTeal,
          fontSize: TypeScale.caption,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> summary) {
    String value(String key) => '${summary[key] ?? 0}';
    return _card(
      context,
      title: 'Last package summary',
      subtitle: 'Counts detected in the latest export/import operation.',
      child: Wrap(
        spacing: Spacing.sm,
        runSpacing: Spacing.sm,
        children: [
          _summaryChip(context, 'Transactions', value('transactionCount')),
          _summaryChip(context, 'Accounts', value('accountCount')),
          _summaryChip(context, 'Investments', value('investmentCount')),
          _summaryChip(context, 'Budgets', value('budgetCount')),
          _summaryChip(context, 'Goals', value('goalCount')),
        ],
      ),
    );
  }

  Widget _summaryChip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.full),
        color: AppStyles.getCardColor(context).withValues(alpha: 0.72),
        border: Border.all(color: AppStyles.getDividerColor(context)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: AppStyles.getTextColor(context),
          fontSize: TypeScale.footnote,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    return DateFormatter.format(date);
  }
}
