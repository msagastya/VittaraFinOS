import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/tags_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/ui/financial_calendar_screen.dart';
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

const String _appName = 'VittaraFinOS';
const String _appTagline = 'Track Wealth, Master Life';
const String _appVersion = '1.0.0+1';
const String _supportEmail = 'support@vittarafinos.app';

class DashboardAppMenuScreen extends StatelessWidget {
  const DashboardAppMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text(
          'Menu',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.isDarkMode(context) ? Colors.black : Colors.white.withValues(alpha: 0.95),
        border: null,
      ),
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
                      icon: CupertinoIcons.sparkles,
                      color: SemanticColors.success,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const WhatsNewScreen()),
                      ),
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
                  title: 'Help',
                  items: [
                    _MenuItem(
                      title: 'FAQs',
                      subtitle: 'Answers for common financial app workflows',
                      icon: CupertinoIcons.question_circle_fill,
                      color: SemanticColors.warning,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const FAQsScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Contact Support',
                      subtitle: 'Raise issues and get help from the team',
                      icon: CupertinoIcons.chat_bubble_text_fill,
                      color: SemanticColors.lending,
                      onTap: () => _showSupportOptions(context),
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
                const SizedBox(height: Spacing.lg),
                _MenuSectionCard(
                  title: 'Policies',
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
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                _MenuSectionCard(
                  title: 'Achievements',
                  items: [
                    _MenuItem(
                      title: 'Your Achievements',
                      subtitle: 'Milestones unlocked across your financial journey',
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
                  title: 'Utilities',
                  items: [
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
                      title: 'Reports & Analysis',
                      subtitle:
                          'Deep analysis by date/category/account/type + exports',
                      icon: CupertinoIcons.chart_bar_square_fill,
                      color: SemanticColors.info,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const ReportsAnalysisScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Manage',
                      subtitle: 'Banks, accounts, categories, and app entities',
                      icon: CupertinoIcons.square_grid_2x2_fill,
                      color: SemanticColors.accounts,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const ManageScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Import CSV',
                      subtitle: 'Import bank statement transactions from CSV',
                      icon: CupertinoIcons.arrow_down_doc_fill,
                      color: AppStyles.aetherTeal,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const CsvImportScreen()),
                      ),
                    ),
                    _MenuItem(
                      title: 'Settings',
                      subtitle: 'Security, theme, backup, and preferences',
                      icon: CupertinoIcons.settings_solid,
                      color: SemanticColors.tags,
                      onTap: () => Navigator.of(context).push(
                        FadeScalePageRoute(page: const SettingsScreen()),
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

  Future<void> _showSupportOptions(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => RLayout.tabletConstrain(
        ctx,
        CupertinoActionSheet(
        title: const Text('Contact Support'),
        message: const Text(
          'Share your issue with relevant details. Include screenshots and steps to reproduce for faster resolution.',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: _supportEmail),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              toast.showSuccess('Support email copied');
            },
            child: const Text('Copy Support Email'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              final text = StringBuffer()
                ..writeln('App: $_appName')
                ..writeln('Version: $_appVersion')
                ..writeln('Platform: Flutter');
              await Clipboard.setData(ClipboardData(text: text.toString()));
              if (ctx.mounted) Navigator.of(ctx).pop();
              toast.showInfo('Diagnostic info copied');
            },
            child: const Text('Copy Diagnostic Summary'),
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
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
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

class FAQsScreen extends StatelessWidget {
  const FAQsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = <_FaqEntry>[
      const _FaqEntry(
        question: 'How is Scorecard calculated?',
        answer:
            'Your Scorecard combines all positive assets and subtracts credit liabilities. Cash, banks, and investments contribute positively while used credit reduces the total.',
      ),
      const _FaqEntry(
        question: 'How do transfers affect reports?',
        answer:
            'Transfers move value between accounts. They do not represent spending by default, but charges and cashback are tracked for transparency.',
      ),
      const _FaqEntry(
        question: 'Can I customize categories and icons?',
        answer:
            'Yes. You can create, edit, and delete categories including icon and color customization from Manage > Categories.',
      ),
      const _FaqEntry(
        question: 'Can I track cash outside bank accounts?',
        answer:
            'Yes. Use Manage > Cash to track wallet cash, withdrawals, deposits, and ongoing cash balance updates.',
      ),
      const _FaqEntry(
        question: 'How secure is local data?',
        answer:
            'App data is stored on-device. Security options such as app lock and related settings are available under Settings.',
      ),
      const _FaqEntry(
        question: 'How can I request support?',
        answer:
            'Use Menu > Contact Support to copy support email and diagnostics before raising your issue.',
      ),
    ];

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text('FAQs',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(Spacing.lg),
          itemBuilder: (context, index) {
            final faq = faqs[index];
            return Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: AppStyles.sectionDecoration(
                context,
                tint: SemanticColors.warning.withValues(alpha: 0.8),
                radius: Radii.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    faq.question,
                    style: TextStyle(
                      color: AppStyles.getTextColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: TypeScale.callout,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    faq.answer,
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.body,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: Spacing.md),
          itemCount: faqs.length,
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
          navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
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
                const _InfoStatRow(
                  label: 'Support Contact',
                  value: _supportEmail,
                ),
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
      'Enhanced category management with icon/color edit support.',
      'Improved transfer and cashback routing clarity.',
      'AI planner refinements for SIP/RD and structured outflow visibility.',
      'Cash management integration in Manage section.',
      'Dashboard menu experience with support, legal, and product pages.',
    ];

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
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
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
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

class _FaqEntry {
  final String question;
  final String answer;

  const _FaqEntry({
    required this.question,
    required this.answer,
  });
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
    heading: '4. Support and Diagnostics',
    content:
        'When contacting support, only details you explicitly share are transmitted. Avoid including sensitive credentials or full card/account numbers.',
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
