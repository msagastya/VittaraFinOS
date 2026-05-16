import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/tags_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/services/ai_voice_command_service.dart';
import 'package:vittara_fin_os/ui/financial_calendar_screen.dart';
import 'package:vittara_fin_os/ui/device_sync_screen.dart';
import 'package:vittara_fin_os/ui/settings/csv_import_screen.dart';
import 'package:vittara_fin_os/ui/manage/reports_analysis_screen.dart';
import 'package:vittara_fin_os/ui/manage_screen.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/floating_particle_background.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';
import 'package:vittara_fin_os/ui/engagement/achievements_screen.dart';
import 'package:vittara_fin_os/ui/widgets/monthly_statement_sheet.dart';

const String _appName = 'VittaraFinOS';
const String _appTagline = 'Track Wealth, Master Life';
const String _appVersion = '1.0.0+2013';

class DashboardAppMenuScreen extends StatelessWidget {
  const DashboardAppMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context)
          ? null
          : AppStyles.standardNavBar(context, 'Menu'),
      child: SafeArea(
        child: SubtleParticleOverlay(
          particleCount: 28,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppStyles.backgroundGradient(context),
            ),
            child: ListView(
              padding: const EdgeInsets.all(Spacing.lg),
              children: [
                _BrandHeader(),
                const SizedBox(height: Spacing.xl),
                _MenuSectionCard(
                  title: 'Core Actions',
                  items: [
                    _MenuItem(
                      title: 'AI Assistant',
                      subtitle:
                          'Voice commands, entries, summaries, exports, navigation',
                      icon: CupertinoIcons.sparkles,
                      color: AppStyles.aetherTeal,
                      onTap: () => AIVoiceCommandService.openAssistant(context),
                    ),
                    _MenuItem(
                      title: 'Manage',
                      subtitle:
                          'Banks, accounts, categories, investments, lending',
                      icon: CupertinoIcons.square_grid_2x2_fill,
                      color: SemanticColors.accounts,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const ManageScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Import Bank Statement',
                      subtitle: 'CSV, PDF, XLS, XLSX import with AI review',
                      icon: CupertinoIcons.arrow_down_doc_fill,
                      color: AppStyles.aetherTeal,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const CsvImportScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Monthly Statement',
                      subtitle:
                          'Generate and share account-wise PDF statements',
                      icon: CupertinoIcons.doc_text_fill,
                      color: SemanticColors.primary,
                      onTap: () => showMonthlyStatementSheet(context),
                    ),
                    _MenuItem(
                      title: 'Reports & Analysis',
                      subtitle:
                          'Deep analysis by date, category, account, type',
                      icon: CupertinoIcons.chart_bar_square_fill,
                      color: SemanticColors.info,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const ReportsAnalysisScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Settings',
                      subtitle: 'Theme, security, backup, and preferences',
                      icon: CupertinoIcons.settings_solid,
                      color: SemanticColors.tags,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const SettingsScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Device Sync',
                      subtitle: 'Encrypted manual sync between mobile and Mac',
                      icon: CupertinoIcons.arrow_2_circlepath,
                      color: AppStyles.aetherTeal,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const DeviceSyncScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Achievements',
                      subtitle: 'Milestones across your financial journey',
                      icon: CupertinoIcons.star_fill,
                      color: AppStyles.solarGold,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const AchievementsScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                _MenuSectionCard(
                  title: 'Product',
                  items: [
                    _MenuItem(
                      title: 'About',
                      subtitle: 'Vision, positioning, and product philosophy',
                      icon: CupertinoIcons.info_circle_fill,
                      color: SemanticColors.primary,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const AboutAppScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'What\'s New',
                      subtitle: 'Recent improvements and release highlights',
                      icon: CupertinoIcons.bolt_fill,
                      color: SemanticColors.success,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const WhatsNewScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Financial Calendar',
                      subtitle:
                          'FD maturities, SIPs, bills, goals & budget resets',
                      icon: CupertinoIcons.calendar_badge_plus,
                      color: AppStyles.aetherTeal,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(
                            page: const FinancialCalendarScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Help & Diagnostics',
                      subtitle: 'Copy app diagnostics for bug reports',
                      icon: CupertinoIcons.doc_text_search,
                      color: SemanticColors.lending,
                      onTap: () => _showDiagnosticsOptions(context),
                    ),
                    _MenuItem(
                      title: 'App Information',
                      subtitle: 'Version, build metadata, and capabilities',
                      icon: CupertinoIcons.device_phone_portrait,
                      color: SemanticColors.info,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const AppInformationScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                _MenuSectionCard(
                  title: 'Legal',
                  items: [
                    _MenuItem(
                      title: 'Privacy Policy',
                      subtitle:
                          'How your financial and personal data is handled',
                      icon: CupertinoIcons.lock_shield_fill,
                      color: SemanticColors.primary,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(
                          page: const LegalDocumentScreen(
                              title: 'Privacy Policy',
                              lastUpdated: 'February 20, 2026',
                              sections: _privacySections),
                        ),
                      ),
                    ),
                    _MenuItem(
                      title: 'Terms of Use',
                      subtitle:
                          'Usage terms, responsibilities, and limitations',
                      icon: CupertinoIcons.doc_plaintext,
                      color: SemanticColors.info,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(
                          page: const LegalDocumentScreen(
                              title: 'Terms of Use',
                              lastUpdated: 'February 20, 2026',
                              sections: _termsSections),
                        ),
                      ),
                    ),
                    _MenuItem(
                      title: 'Open Source Licenses',
                      subtitle: 'Dependency attributions and license details',
                      icon: CupertinoIcons.doc_text_fill,
                      color: SemanticColors.categories,
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: _appName,
                        applicationVersion: _appVersion,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessGrid(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    // Count today's events (FD maturities and recurring templates due today)
    final investmentsCtrl = context.read<InvestmentsController>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int todayEventCount = 0;
    for (final inv in investmentsCtrl.investments) {
      if (inv.type != InvestmentType.fixedDeposit) continue;
      final meta = inv.metadata;
      if (meta == null) continue;
      try {
        DateTime? d;
        if (meta.containsKey('maturityDate')) {
          d = DateTime.tryParse((meta['maturityDate'] as String?) ?? '');
        }
        if (d != null && DateTime(d.year, d.month, d.day) == today) {
          todayEventCount++;
        }
      } catch (_) {}
    }

    final items = <_QuickItem>[
      _QuickItem(
        label: 'Calendar',
        icon: CupertinoIcons.calendar_badge_plus,
        color: AppStyles.aetherTeal,
        badge: todayEventCount,
        onTap: () => Navigator.of(context)
            .push(FadeScalePageRoute(page: const FinancialCalendarScreen())),
      ),
      _QuickItem(
        label: 'Manage',
        icon: CupertinoIcons.square_grid_2x2_fill,
        color: SemanticColors.accounts,
        onTap: () => Navigator.of(context)
            .push(FadeScalePageRoute(page: const ManageScreen())),
      ),
      _QuickItem(
        label: 'Settings',
        icon: CupertinoIcons.settings_solid,
        color: SemanticColors.tags,
        onTap: () => Navigator.of(context)
            .push(FadeScalePageRoute(page: const SettingsScreen())),
      ),
      _QuickItem(
        label: 'Reports',
        icon: CupertinoIcons.chart_bar_square_fill,
        color: SemanticColors.info,
        onTap: () => Navigator.of(context)
            .push(FadeScalePageRoute(page: const ReportsAnalysisScreen())),
      ),
      _QuickItem(
        label: 'Statement',
        icon: CupertinoIcons.doc_text_fill,
        color: SemanticColors.primary,
        onTap: () => showMonthlyStatementSheet(context),
      ),
      _QuickItem(
        label: 'Import',
        icon: CupertinoIcons.arrow_down_doc_fill,
        color: AppStyles.accentTeal,
        onTap: () => Navigator.of(context)
            .push(FadeScalePageRoute(page: const CsvImportScreen())),
      ),
      _QuickItem(
        label: 'Achievements',
        icon: CupertinoIcons.star_fill,
        color: AppStyles.solarGold,
        onTap: () => Navigator.of(context)
            .push(FadeScalePageRoute(page: const AchievementsScreen())),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md, left: 2),
          child: Row(
            children: [
              Icon(CupertinoIcons.bolt_fill,
                  size: 12, color: AppStyles.getSecondaryTextColor(context)),
              const SizedBox(width: 6),
              Text(
                'QUICK ACCESS',
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getSecondaryTextColor(context),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: Spacing.md,
            crossAxisSpacing: Spacing.md,
            childAspectRatio: 0.88,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            return BouncyButton(
              onPressed: item.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: isDark ? 0.15 : 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            item.color.withValues(alpha: isDark ? 0.25 : 0.18),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                            child:
                                Icon(item.icon, color: item.color, size: 22)),
                        if (item.badge > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppStyles.plasmaRed,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item.badge}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showDiagnosticsOptions(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => RLayout.tabletConstrain(
        ctx,
        CupertinoActionSheet(
          title: const Text('Help & Diagnostics'),
          message: const Text(
            'This app does not have built-in customer support yet. Copy diagnostics and attach them when you report an issue manually.',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                final text = StringBuffer()
                  ..writeln('App: $_appName')
                  ..writeln('Version: $_appVersion')
                  ..writeln('Platform: Flutter')
                  ..writeln('Issue:')
                  ..writeln('Steps to reproduce:')
                  ..writeln('Expected:')
                  ..writeln('Actual:');
                await Clipboard.setData(ClipboardData(text: text.toString()));
                if (ctx.mounted) Navigator.of(ctx).pop();
                toast.showInfo('Diagnostic info copied');
              },
              child: const Text('Copy Diagnostic Template'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: SemanticColors.primary,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [SemanticColors.primary, SemanticColors.info],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              'V',
              style: TextStyle(
                color: Colors.white,
                fontSize: RT.largeTitle(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _appName,
                  style: AppStyles.titleStyle(context).copyWith(
                    fontSize: RT.title2(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  _appTagline,
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.callout,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuSectionCard extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSectionCard({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppStyles.sectionDecoration(
        context,
        tint: SemanticColors.primary.withValues(alpha: 0.75),
        radius: Radii.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.lg,
              Spacing.lg,
              Spacing.sm,
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: TypeScale.subhead,
                fontWeight: FontWeight.w700,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
          ),
          ...items.asMap().entries.map(
                (entry) => _MenuRow(
                  item: entry.value,
                  showDivider: entry.key != items.length - 1,
                ),
              ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MenuItem item;
  final bool showDivider;

  const _MenuRow({
    required this.item,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onPressed: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: AppStyles.getDividerColor(context)
                        .withValues(alpha: 0.4),
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: AppStyles.iconBoxDecoration(context, item.color),
              alignment: Alignment.center,
              child: Icon(item.icon, color: item.color, size: IconSizes.md),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: TypeScale.callout,
                    ),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    item.subtitle,
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
              size: IconSizes.sm,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badge; // 0 = no badge

  const _QuickItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context)
          ? null
          : CupertinoNavigationBar(
              middle: Text('About',
                  style: TextStyle(color: AppStyles.getTextColor(context))),
              previousPageTitle: 'Back',
              backgroundColor: AppStyles.getBackground(context),
              border: null,
            ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            const _InfoPanel(
              title: _appName,
              subtitle: _appTagline,
              icon: CupertinoIcons.graph_square_fill,
              color: SemanticColors.primary,
            ),
            const SizedBox(height: Spacing.lg),
            const _RichContentCard(
              title: 'What We Solve',
              points: [
                'Unified tracking for banks, wallets, cash, transfers, and investments.',
                'Actionable guidance through AI planning and budget health context.',
                'Operational control through categories, tags, contacts, and app-level management.',
              ],
            ),
            const SizedBox(height: Spacing.lg),
            const _RichContentCard(
              title: 'Core Product Principles',
              points: [
                'Clarity first: every financial action should have a clear trace.',
                'Control first: users can customize categories, flows, and structures.',
                'Continuity first: data is persisted for long-term trend analysis.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AppInformationScreen extends StatelessWidget {
  const AppInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer5<AccountsController, CategoriesController,
        TransactionsController, InvestmentsController, TagsController>(
      builder: (
        context,
        accountsController,
        categoriesController,
        transactionsController,
        investmentsController,
        tagsController,
        _,
      ) {
        return CupertinoPageScaffold(
          backgroundColor: AppStyles.getBackground(context),
          navigationBar: AppStyles.isLandscape(context)
              ? null
              : CupertinoNavigationBar(
                  middle: Text(
                    'App Information',
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
                const _InfoStatRow(label: 'App Name', value: _appName),
                const _InfoStatRow(label: 'Tagline', value: _appTagline),
                const _InfoStatRow(label: 'Version', value: _appVersion),
                const _InfoStatRow(label: 'Platform', value: 'Flutter'),
                const _InfoStatRow(
                  label: 'Data Model',
                  value: 'On-device local storage',
                ),
                _InfoStatRow(
                  label: 'Accounts',
                  value: '${accountsController.accounts.length}',
                ),
                _InfoStatRow(
                  label: 'Categories',
                  value: '${categoriesController.categories.length}',
                ),
                _InfoStatRow(
                  label: 'Transactions',
                  value: '${transactionsController.transactions.length}',
                ),
                _InfoStatRow(
                  label: 'Investments',
                  value: '${investmentsController.investments.length}',
                ),
                _InfoStatRow(
                  label: 'Tags',
                  value: '${tagsController.tags.length}',
                ),
                const _InfoStatRow(
                  label: 'Major Modules',
                  value: 'Dashboard, Manage, Reports, AI Planner, Goals',
                ),
                const _InfoStatRow(label: 'Diagnostics', value: 'Available'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const changes = [
      'Adaptive portrait, landscape, tablet, and macOS sheet behavior.',
      'Manual encrypted device sync between mobile and Mac.',
      'Quick Access refresh with Manage, Import, Statements, Reports, Achievements, and Settings.',
      'Financial Health now reads direct investments from Manage > Investments.',
      'Dashboard menu cleanup with diagnostics, legal, and product information.',
    ];

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context)
          ? null
          : CupertinoNavigationBar(
              middle: Text('What\'s New',
                  style: TextStyle(color: AppStyles.getTextColor(context))),
              previousPageTitle: 'Back',
              backgroundColor: AppStyles.getBackground(context),
              border: null,
            ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            const _InfoPanel(
              title: 'Version $_appVersion',
              subtitle: 'Latest product upgrades and stability improvements',
              icon: CupertinoIcons.sparkles,
              color: SemanticColors.success,
            ),
            const SizedBox(height: Spacing.lg),
            ...changes.map(
              (change) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: AppStyles.sectionDecoration(
                    context,
                    tint: SemanticColors.success.withValues(alpha: 0.75),
                    radius: Radii.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        color: SemanticColors.success,
                        size: IconSizes.sm,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          change,
                          style: TextStyle(
                            color: AppStyles.getTextColor(context),
                            fontSize: TypeScale.body,
                          ),
                        ),
                      ),
                    ],
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

class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<LegalSection> sections;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context)
          ? null
          : CupertinoNavigationBar(
              middle: Text(title,
                  style: TextStyle(color: AppStyles.getTextColor(context))),
              previousPageTitle: 'Back',
              backgroundColor: AppStyles.getBackground(context),
              border: null,
            ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.lg),
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Text(
                'Last Updated: $lastUpdated',
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.footnote,
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            ...sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.lg),
                child: Container(
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(
                      color: AppStyles.getDividerColor(context)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.heading,
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontWeight: FontWeight.w700,
                          fontSize: TypeScale.callout,
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        section.content,
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.body,
                          height: 1.45,
                        ),
                      ),
                    ],
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

class _InfoPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _InfoPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: color,
        radius: Radii.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: IconSizes.md),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: TypeScale.title3,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppStyles.getSecondaryTextColor(context),
                    fontSize: TypeScale.body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RichContentCard extends StatelessWidget {
  final String title;
  final List<String> points;

  const _RichContentCard({
    required this.title,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: AppStyles.accentTeal.withValues(alpha: 0.75),
        radius: Radii.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontWeight: FontWeight.w700,
              fontSize: TypeScale.callout,
            ),
          ),
          const SizedBox(height: Spacing.md),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.body,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.body,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStatRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoStatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.sectionDecoration(
        context,
        tint: AppStyles.accentBlue.withValues(alpha: 0.72),
        radius: Radii.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppStyles.getSecondaryTextColor(context),
              fontSize: TypeScale.footnote,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            value,
            style: TextStyle(
              color: AppStyles.getTextColor(context),
              fontSize: TypeScale.callout,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class LegalSection {
  final String heading;
  final String content;

  const LegalSection({
    required this.heading,
    required this.content,
  });
}

const List<LegalSection> _privacySections = [
  LegalSection(
    heading: '1. Data Storage',
    content:
        'Financial entries, account metadata, and preferences are primarily stored on-device. You retain control over your data lifecycle within the app.',
  ),
  LegalSection(
    heading: '2. Data Usage',
    content:
        'Data is used to provide budgeting, tracking, planning, and analytics capabilities. The app does not require external sharing of your transaction records for core functionality.',
  ),
  LegalSection(
    heading: '3. Security Controls',
    content:
        'Security settings such as lock preferences and authentication flow are user-configurable. You are responsible for securing device-level access and credentials.',
  ),
  LegalSection(
    heading: '4. Diagnostics',
    content:
        'The app can copy a diagnostic issue template that you may share manually. Avoid including sensitive credentials or full card/account numbers.',
  ),
];

const List<LegalSection> _termsSections = [
  LegalSection(
    heading: '1. Intended Use',
    content:
        'VittaraFinOS is designed as a personal finance tracking and planning utility. It is not a substitute for licensed financial, legal, or tax advice.',
  ),
  LegalSection(
    heading: '2. User Responsibility',
    content:
        'Users are responsible for the accuracy of entered data and operational decisions made from app insights, projections, and recommendations.',
  ),
  LegalSection(
    heading: '3. Service Scope',
    content:
        'Feature behavior may evolve with updates. The app experience may include workflow, analytics, and UI improvements over time.',
  ),
  LegalSection(
    heading: '4. Limitation',
    content:
        'The application is provided as-is. The product team is not liable for losses arising from data entry errors, interpretation of analytics, or external financial actions.',
  ),
];
