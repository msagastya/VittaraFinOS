import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _refreshLocalBackups();
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

  Future<void> _copyBackupJson() async {
    setState(() => _busy = true);
    final result = await BackupRestoreService.buildBackupJson();
    if (!mounted) return;
    if (result.success && result.backupJson != null) {
      await Clipboard.setData(ClipboardData(text: result.backupJson!));
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastStatus = result.message;
      _lastSummary = result.details;
    });
    if (result.success) {
      toast.showSuccess('Backup JSON copied');
    } else {
      toast.showError(result.message);
    }
  }

  Future<void> _restoreLatestLocalBackup() async {
    final confirm = await _confirmDestructive(
      title: 'Restore latest backup?',
      message:
          'This will overwrite current app data with the selected backup content.',
      destructiveText: 'Restore',
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    final result = await BackupRestoreService.restoreLatestLocalBackup();
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
  }

  Future<void> _restoreFromPastedJson() async {
    final controller = TextEditingController();
    final restoreJson = await showCupertinoModalPopup<String>(
      context: context,
      builder: (modalContext) => CupertinoActionSheet(
        title: const Text('Paste Backup JSON'),
        message: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CupertinoTextField(
              controller: controller,
              maxLines: 10,
              placeholder: 'Paste backup JSON here',
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(modalContext, controller.text),
            child: const Text('Restore from this JSON'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(modalContext),
          child: const Text('Cancel'),
        ),
      ),
    );
    controller.dispose();

    if (!mounted) return;
    if (restoreJson == null || restoreJson.trim().isEmpty) {
      return;
    }

    final inspect = await BackupRestoreService.inspectBackupJson(restoreJson);
    if (!mounted) return;
    if (!inspect.success) {
      toast.showError(inspect.message);
      return;
    }

    final txCount = inspect.details?['transactionCount'] ?? 0;
    final accounts = inspect.details?['accountCount'] ?? 0;
    final confirm = await _confirmDestructive(
      title: 'Restore from JSON?',
      message:
          'This backup contains $txCount transactions and $accounts accounts. Current data will be overwritten for restorable keys.',
      destructiveText: 'Restore',
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    final result = await BackupRestoreService.restoreFromJson(restoreJson);
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
  }

  Future<void> _showLocalBackupPicker() async {
    if (_localBackups.isEmpty) {
      toast.showInfo('No local backup files found');
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (modalContext) => CupertinoActionSheet(
        title: const Text('Local Backups'),
        message: const Text('Pick a file to restore from local storage'),
        actions: _localBackups.take(8).map((file) {
          final name = file.path.split('/').last;
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(modalContext);
              final confirm = await _confirmDestructive(
                title: 'Restore "$name"?',
                message:
                    'Current restorable keys will be overwritten with this file.',
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
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Backup & Restore',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Settings',
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
            _buildActionCard(
              context,
              title: 'Create Local Backup File',
              subtitle:
                  'Creates a versioned JSON backup in app documents storage.',
              icon: CupertinoIcons.cloud_download_fill,
              color: CupertinoColors.systemBlue,
              onTap: _busy ? null : _createLocalBackup,
            ),
            _buildActionCard(
              context,
              title: 'Copy Backup JSON',
              subtitle: 'Copy a complete backup bundle to clipboard.',
              icon: CupertinoIcons.doc_on_clipboard_fill,
              color: CupertinoColors.systemTeal,
              onTap: _busy ? null : _copyBackupJson,
            ),
            _buildActionCard(
              context,
              title: 'Restore Latest Local Backup',
              subtitle: 'Restores from the most recent local backup file.',
              icon: CupertinoIcons.arrow_clockwise_circle_fill,
              color: CupertinoColors.systemOrange,
              onTap: _busy ? null : _restoreLatestLocalBackup,
            ),
            _buildActionCard(
              context,
              title: 'Restore from Pasted JSON',
              subtitle: 'Paste any backup JSON (new or legacy format).',
              icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
              color: CupertinoColors.systemPurple,
              onTap: _busy ? null : _restoreFromPastedJson,
            ),
            _buildActionCard(
              context,
              title: 'Browse Local Backups',
              subtitle: 'Pick a specific backup file to restore.',
              icon: CupertinoIcons.folder_fill,
              color: CupertinoColors.systemIndigo,
              onTap: _busy ? null : _showLocalBackupPicker,
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
            'Current Data Snapshot',
            style: AppStyles.titleStyle(context).copyWith(fontSize: TypeScale.title3),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Transactions: $transactionsCount • Accounts: $accountsCount • Investments: $investmentsCount',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Backups are versioned and include typed storage snapshot for compatibility with future app upgrades.',
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
            ),
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
          opacity: onTap == null ? 0.55 : 1,
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
            'Last Operation Summary',
            style: AppStyles.titleStyle(context).copyWith(fontSize: TypeScale.body),
          ),
          const SizedBox(height: Spacing.sm),
          Text('Source: ${value('source')}'),
          Text('Keys: ${value('keys')}'),
          Text('Transactions: ${value('transactionCount')}'),
          Text('Unique Transaction IDs: ${value('uniqueTransactionIds')}'),
          Text(
              'Duplicate Transaction IDs: ${value('duplicateTransactionIds')}'),
          Text('Accounts: ${value('accountCount')}'),
          Text('Investments: ${value('investmentCount')}'),
        ],
      ),
    );
  }
}
