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
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart' show SettingsController;

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _busy = false;
  String? _lastStatus;
  Map<String, dynamic>? _lastSummary;
  List<File> _localBackups = const [];

  // T-129: Encrypt backup toggle + password fields
  bool _encryptExport = false;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _refreshLocalBackups();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _refreshLocalBackups() async {
    final files = await BackupRestoreService.listLocalBackupFiles();
    if (!mounted) return;
    setState(() => _localBackups = files);
  }

  Future<void> _createLocalBackup() async {
    setState(() => _busy = true);
    final result = await BackupRestoreService.createLocalBackupFile();
    if (!mounted) return;
    await _refreshLocalBackups();
    setState(() {
      _busy = false;
      _lastStatus = result.message;
      _lastSummary = result.details;
    });
    if (result.success) {
      toast.showSuccess(result.filePath ?? 'Backup created');
    } else {
      toast.showError(result.message);
    }
  }

  Future<void> _exportBackup() async {
    // T-135: biometric gate before generating backup
    final settings = context.read<SettingsController>();
    final ok = await settings.authenticateSensitiveScreen(
      reason: 'Authenticate to export your backup',
    );
    if (!mounted || !ok) return;

    // T-129: if encryption enabled, validate passwords first
    if (_encryptExport) {
      final pw = _passwordController.text.trim();
      final confirm = _confirmPasswordController.text.trim();
      if (pw.isEmpty) {
        toast.showError('Please enter a password for encryption.');
        return;
      }
      if (pw.length < 8) {
        toast.showError('Password must be at least 8 characters.');
        return;
      }
      if (pw != confirm) {
        toast.showError('Passwords do not match.');
        return;
      }
    }

    setState(() => _busy = true);
    final BackupOperationResult result;
    if (_encryptExport) {
      result = await BackupRestoreService.buildAndExportPasswordEncryptedFile(
        _passwordController.text.trim(),
      );
    } else {
      result = await BackupRestoreService.buildAndExportBackupFile();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastStatus = result.message;
      _lastSummary = result.details;
    });
    if (!result.success || result.filePath == null) {
      toast.showError(result.message);
      return;
    }
    await Share.shareXFiles(
      [XFile(result.filePath!)],
      subject: 'Vittara Backup',
    );
  }

  Future<void> _restoreFromPickedFile() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'vittara_enc', 'vittara_backup'],
        withData: true,
      );
    } catch (_) {}
    if (!mounted) return;
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    String? rawContent;
    if (file.bytes != null) {
      rawContent = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      rawContent = await File(file.path!).readAsString();
    }
    if (!mounted) return;
    if (rawContent == null || rawContent.trim().isEmpty) {
      toast.showError('Could not read the selected file.');
      return;
    }

    // T-130: detect .vittara_enc extension → prompt for password
    final fileName = file.name.toLowerCase();
    String rawJson = rawContent;
    if (fileName.endsWith('.vittara_enc')) {
      final password = await _promptRestorePassword();
      if (!mounted || password == null) return;
      try {
        rawJson = BackupRestoreService.decryptJsonWithPassword(rawContent, password);
      } catch (e) {
        toast.showError(e.toString().replaceFirst('FormatException: ', ''));
        return;
      }
    }

    final inspect = await BackupRestoreService.inspectBackupJson(rawJson);
    if (!mounted) return;
    if (!inspect.success) {
      toast.showError('Not a valid Vittara backup: ${inspect.message}');
      return;
    }

    final txCount = inspect.details?['transactionCount'] ?? 0;
    final accounts = inspect.details?['accountCount'] ?? 0;
    final confirm = await _confirmDestructive(
      title: 'Restore from file?',
      message:
          'This backup contains $txCount transactions and $accounts accounts. Current data will be overwritten.',
      destructiveText: 'Restore',
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    final result = await BackupRestoreService.restoreFromJson(rawJson);
    if (result.success) await _reloadAllControllers();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastStatus = result.message;
      _lastSummary = result.details;
    });
    if (result.success) {
      toast.showSuccess('Backup restored');
    } else {
      toast.showError(result.message);
    }
  }

  /// Shows a dialog asking for the decryption password.
  Future<String?> _promptRestorePassword() async {
    final controller = TextEditingController();
    bool obscure = true;
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => CupertinoAlertDialog(
          title: const Text('Enter backup password'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CupertinoTextField(
              controller: controller,
              placeholder: 'Password',
              obscureText: obscure,
              autofocus: true,
              suffix: GestureDetector(
                onTap: () => setState(() => obscure = !obscure),
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
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Decrypt'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocalBackupPicker() async {
    if (_localBackups.isEmpty) {
      toast.showInfo('No local backup files found');
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (modalContext) => RLayout.tabletConstrain(
        modalContext,
        CupertinoActionSheet(
          title: const Text('Local Backups'),
          message: const Text('Select a backup to restore'),
          actions: _localBackups.take(8).map((file) {
            final name = file.path.split('/').last;
            return CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.pop(modalContext);
                final confirm = await _confirmDestructive(
                  title: 'Restore "$name"?',
                  message: 'Current data will be overwritten.',
                  destructiveText: 'Restore',
                );
                if (confirm != true) return;
                setState(() => _busy = true);
                final raw = await file.readAsString();
                final result = await BackupRestoreService.restoreFromJson(raw);
                if (result.success) {
                  await _reloadAllControllers();
                }
                if (!mounted) return;
                setState(() {
                  _busy = false;
                  _lastStatus = result.message;
                  _lastSummary = result.details;
                });
                if (result.success) {
                  toast.showSuccess('Backup restored');
                } else {
                  toast.showError(result.message);
                }
              },
              child: Text(name),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(modalContext),
            child: const Text('Close'),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDestructive({
    required String title,
    required String message,
    required String destructiveText,
  }) async {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(destructiveText),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadAllControllers() async {
    final accounts = context.read<AccountsController>();
    final transactions = context.read<TransactionsController>();
    final investments = context.read<InvestmentsController>();
    final categories = context.read<CategoriesController>();
    final contacts = context.read<ContactsController>();
    final tags = context.read<TagsController>();
    final apps = context.read<PaymentAppsController>();
    final lending = context.read<LendingBorrowingController>();
    final settings = context.read<SettingsController>();
    final archive = context.read<TransactionsArchiveController>();
    final goals = context.read<GoalsController>();
    final budgets = context.read<BudgetsController>();
    final dashboard = context.read<DashboardController>();
    final investmentPrefs = context.read<InvestmentTypePreferencesController>();

    await accounts.loadAccounts();
    await transactions.loadTransactions();
    await investments.loadInvestments();
    await categories.loadCategories();
    await contacts.loadContacts();
    await tags.loadTags();
    await apps.loadApps();
    await lending.loadRecords();
    await settings.loadSettings();
    await archive.reloadFromStorage();
    await goals.reloadFromStorage();
    await budgets.reloadFromStorage();
    await dashboard.initialize();
    await investmentPrefs.loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsCount =
        context.watch<TransactionsController>().transactions.length;
    final accountsCount = context.watch<AccountsController>().accounts.length;
    final investmentsCount =
        context.watch<InvestmentsController>().investments.length;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context)
          ? null
          : CupertinoNavigationBar(
              middle: Text(
                'Backup & Restore',
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
              previousPageTitle: 'Back',
              backgroundColor: AppStyles.getBackground(context),
              border: null,
            ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            _buildOverviewCard(
              context,
              transactionsCount: transactionsCount,
              accountsCount: accountsCount,
              investmentsCount: investmentsCount,
            ),
            const SizedBox(height: Spacing.md),

            // ── Backup ──────────────────────────────────────────────────
            _buildSectionHeader(context, 'Backup'),

            // T-129: Encrypt backup toggle
            _buildEncryptToggleCard(context),
            const SizedBox(height: 10),

            _buildActionCard(
              context,
              title: 'Export & Share',
              subtitle: _encryptExport
                  ? 'Password-protected backup. Share securely.'
                  : 'Send to Google Drive, WhatsApp, Files, or any app. Survives reinstall.',
              icon: CupertinoIcons.share_solid,
              color: CupertinoColors.systemGreen,
              onTap: _busy ? null : _exportBackup,
            ),

            // T-131: Warning text
            _buildExportWarning(context),
            const SizedBox(height: 4),
            _buildActionCard(
              context,
              title: 'Save Local Backup',
              subtitle: 'Saves a copy on this device. Export to keep it safe across reinstalls.',
              icon: CupertinoIcons.cloud_download_fill,
              color: CupertinoColors.systemBlue,
              onTap: _busy ? null : _createLocalBackup,
            ),

            const SizedBox(height: Spacing.sm),

            // ── Restore ─────────────────────────────────────────────────
            _buildSectionHeader(context, 'Restore'),
            _buildActionCard(
              context,
              title: 'Restore from File',
              subtitle: 'Pick a backup .json from your device, Drive, or any cloud storage.',
              icon: CupertinoIcons.tray_arrow_up_fill,
              color: CupertinoColors.systemOrange,
              onTap: _busy ? null : _restoreFromPickedFile,
            ),
            _buildActionCard(
              context,
              title: 'Restore from Local Backup',
              subtitle:
                  _localBackups.isEmpty
                      ? 'No local backups found yet.'
                      : '${_localBackups.length} backup${_localBackups.length == 1 ? '' : 's'} on this device — pick one to restore.',
              icon: CupertinoIcons.folder_fill,
              color: CupertinoColors.systemIndigo,
              onTap: (_busy || _localBackups.isEmpty) ? null : _showLocalBackupPicker,
            ),

            if (_busy) ...[
              const SizedBox(height: Spacing.lg),
              const Center(child: CupertinoActivityIndicator(radius: 12)),
            ],
            if (_lastStatus != null) ...[
              const SizedBox(height: Spacing.lg),
              Text(
                _lastStatus!,
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.subhead,
                ),
              ),
            ],
            if (_lastSummary != null) ...[
              const SizedBox(height: Spacing.sm),
              _buildSummaryCard(context, _lastSummary!),
            ],
          ],
        ),
      ),
    );
  }

  // T-129: Encrypt toggle + password fields card
  Widget _buildEncryptToggleCard(BuildContext context) {
    final secondary = AppStyles.getSecondaryTextColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppStyles.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encrypt backup',
                      style: AppStyles.titleStyle(context)
                          .copyWith(fontSize: TypeScale.callout),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Protect with a password (AES-256)',
                      style: TextStyle(
                          color: secondary, fontSize: TypeScale.footnote),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: _encryptExport,
                onChanged: (v) => setState(() {
                  _encryptExport = v;
                  if (!v) {
                    _passwordController.clear();
                    _confirmPasswordController.clear();
                  }
                }),
              ),
            ],
          ),
          if (_encryptExport) ...[
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: _passwordController,
              placeholder: 'Password (min 8 characters)',
              obscureText: !_showPassword,
              suffix: GestureDetector(
                onTap: () => setState(() => _showPassword = !_showPassword),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    _showPassword
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.eye,
                    size: 18,
                    color: secondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: _confirmPasswordController,
              placeholder: 'Confirm password',
              obscureText: !_showPassword,
            ),
          ],
        ],
      ),
    );
  }

  // T-131: Warning text below export option
  Widget _buildExportWarning(BuildContext context) {
    final amber = CupertinoColors.systemYellow.resolveFrom(context);
    final msg = _encryptExport
        ? 'Password-protected. Keep your password safe — we cannot recover it.'
        : 'This file contains all your financial data. Store it securely.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.exclamationmark_circle,
              size: 13, color: amber),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                fontSize: TypeScale.caption,
                color: amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: TypeScale.caption,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppStyles.getSecondaryTextColor(context),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required int transactionsCount,
    required int accountsCount,
    required int investmentsCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Data',
            style: AppStyles.titleStyle(context)
                .copyWith(fontSize: TypeScale.title3),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '$transactionsCount transactions · $accountsCount accounts · $investmentsCount investments',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppStyles.cardDecoration(context),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: AppStyles.iconBoxDecoration(context, color),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppStyles.titleStyle(context)
                            .copyWith(fontSize: TypeScale.callout),
                      ),
                      const SizedBox(height: Spacing.xxs),
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
                if (onTap != null)
                  const Icon(CupertinoIcons.chevron_right, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, Map<String, dynamic> summary) {
    String value(String key) => '${summary[key] ?? '-'}';
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: AppStyles.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last Operation',
            style: AppStyles.titleStyle(context)
                .copyWith(fontSize: TypeScale.body),
          ),
          const SizedBox(height: Spacing.sm),
          Text('Transactions: ${value('transactionCount')}'),
          Text('Accounts: ${value('accountCount')}'),
          Text('Investments: ${value('investmentCount')}'),
        ],
      ),
    );
  }
}
