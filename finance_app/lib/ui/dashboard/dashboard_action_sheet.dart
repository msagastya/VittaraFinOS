import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Divider;
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/utils/logger.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/logic/fixed_deposit_model.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/recurring_deposit_model.dart';
import 'package:vittara_fin_os/ui/manage/bonds/bonds_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/commodities/commodities_wizard.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/cryptocurrency/crypto_wizard.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/digital_gold/digital_gold_wizard.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/fd/fd_wizard_screen.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/fo/fo_wizard.dart';
import 'package:vittara_fin_os/ui/manage/investments/simple_investment_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/models/mutual_fund_model.dart';
import 'package:vittara_fin_os/ui/manage/nps/nps_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/pension/pension_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/pension/pension_wizard.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/rd/rd_wizard_screen.dart';
import 'package:vittara_fin_os/ui/manage/simple_investment_entry_wizard.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stock_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard.dart';
import 'package:vittara_fin_os/ui/manage/transfer_wizard.dart';
import 'package:vittara_fin_os/ui/dashboard/quick_entry_sheet.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

final _dashboardLogger = AppLogger();

// ── Entry point ───────────────────────────────────────────────────────────────

void showDashboardActionSheet(BuildContext context) {
  final nav = Navigator.of(context);
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => RLayout.tabletConstrain(
      _,
      _DashboardActionSheet(navigator: nav),
    ),
  );
}

// ── Internal page enum ────────────────────────────────────────────────────────

enum _Page {
  home,
  investmentType,
  investmentAction,
  investmentAddPick,
  investmentSellPick,
  dividendType,
  dividendPick,
}

// ── Sheet type info ───────────────────────────────────────────────────────────

class _TypeInfo {
  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;
  final String description;
  const _TypeInfo(
      this.label, this.shortLabel, this.icon, this.color, this.description);
}

// ── Main sheet widget ─────────────────────────────────────────────────────────

class _DashboardActionSheet extends StatefulWidget {
  final NavigatorState navigator;
  const _DashboardActionSheet({required this.navigator});

  @override
  State<_DashboardActionSheet> createState() => _DashboardActionSheetState();
}

class _DashboardActionSheetState extends State<_DashboardActionSheet> {
  _Page _page = _Page.home;
  bool _forward = true;
  InvestmentType? _selectedType;
  List<Investment> _typeInvestments = [];
  bool _isDividendStock = true;
  List<Investment> _dividendInvestments = [];

  // ── Investment type metadata ────────────────────────────────────────────────
  static const Map<InvestmentType, _TypeInfo> _typeInfo = {
    InvestmentType.stocks: _TypeInfo('Stocks & ETFs', 'Stocks', CupertinoIcons.chart_bar_fill, Color(0xFF00B050), 'NSE/BSE equities & ETFs'),
    InvestmentType.mutualFund: _TypeInfo('Mutual Funds', 'MF', CupertinoIcons.chart_pie_fill, Color(0xFF0066CC), 'SIP or lumpsum investments'),
    InvestmentType.fixedDeposit: _TypeInfo('Fixed Deposit', 'FD', CupertinoIcons.lock_fill, Color(0xFFFF6B00), 'Bank FD, guaranteed returns'),
    InvestmentType.recurringDeposit: _TypeInfo('Recurring Deposit', 'RD', CupertinoIcons.arrow_clockwise, Color(0xFFD600CC), 'Monthly savings deposit'),
    InvestmentType.bonds: _TypeInfo('Bonds', 'Bonds', CupertinoIcons.doc_circle_fill, Color(0xFF00A6CC), 'Govt & corporate bonds'),
    InvestmentType.nationalSavingsScheme: _TypeInfo('NPS', 'NPS', CupertinoIcons.flag_circle_fill, Color(0xFFEC6100), 'National Pension System'),
    InvestmentType.digitalGold: _TypeInfo('Digital Gold', 'Gold', CupertinoIcons.star_circle_fill, Color(0xFFFFB81C), 'Gold in digital form'),
    InvestmentType.pensionSchemes: _TypeInfo('Pension Schemes', 'Pension', CupertinoIcons.person_2_fill, Color(0xFF9B59B6), 'EPF, PPF & other schemes'),
    InvestmentType.cryptocurrency: _TypeInfo('Cryptocurrency', 'Crypto', CupertinoIcons.arrow_right_arrow_left_circle_fill, Color(0xFFF7931A), 'Bitcoin, Ethereum & more'),
    InvestmentType.futuresOptions: _TypeInfo('Futures & Options', 'F&O', CupertinoIcons.waveform, Color(0xFF1ABC9C), 'Derivatives trading'),
    InvestmentType.forexCurrency: _TypeInfo('Forex / Currency', 'Forex', CupertinoIcons.globe, Color(0xFF34495E), 'Foreign currency positions'),
    InvestmentType.commodities: _TypeInfo('Commodities', 'Comm.', CupertinoIcons.cube_box_fill, Color(0xFF8B4513), 'Silver, oil & others'),
  };

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _push(_Page page) => setState(() {
        _forward = true;
        _page = page;
      });

  void _goBack() => setState(() {
        _forward = false;
        switch (_page) {
          case _Page.home:
            Navigator.pop(context);
            return;
          case _Page.investmentType:
            _page = _Page.home;
            return;
          case _Page.investmentAction:
            _page = _Page.investmentType;
            return;
          case _Page.investmentAddPick:
            _page = _Page.investmentAction;
            return;
          case _Page.investmentSellPick:
            _page = _Page.investmentAction;
            return;
          case _Page.dividendType:
            _page = _Page.home;
            return;
          case _Page.dividendPick:
            _page = _Page.dividendType;
            return;
        }
      });

  void _launch(Widget screen) {
    // Pop the sheet first, then push on next frame to avoid race where the
    // sheet's pop and the new route's push happen in the same frame.
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.navigator.push(FadeScalePageRoute(page: screen));
    });
  }

  // ── Wizard router ───────────────────────────────────────────────────────────

  Widget _wizardFor(InvestmentType type) {
    switch (type) {
      case InvestmentType.stocks:
        return const StocksWizard();
      case InvestmentType.mutualFund:
        return const MFWizard();
      case InvestmentType.fixedDeposit:
        return const FDWizardScreen();
      case InvestmentType.recurringDeposit:
        return const RDWizardScreen();
      case InvestmentType.bonds:
        return const SimpleInvestmentEntryWizard(
          type: InvestmentType.bonds,
          title: 'Add Bond',
          subtitle: 'Track bond holdings with account linkage.',
          color: Color(0xFF00A6CC),
          defaultName: 'Bond Holding',
          referenceLabel: 'Issuer / ISIN (Optional)',
          referenceHint: 'Enter issuer or ISIN',
        );
      case InvestmentType.nationalSavingsScheme:
        return const SimpleInvestmentEntryWizard(
          type: InvestmentType.nationalSavingsScheme,
          title: 'Add NPS',
          subtitle: 'NPS account contribution tracker.',
          color: Color(0xFFEC6100),
          defaultName: 'NPS Account',
          referenceLabel: 'PRAN / Account ID (Optional)',
          referenceHint: 'Enter PRAN or account reference',
        );
      case InvestmentType.digitalGold:
        return const DigitalGoldWizard();
      case InvestmentType.pensionSchemes:
        return const PensionWizard();
      case InvestmentType.cryptocurrency:
        return const CryptoWizard();
      case InvestmentType.futuresOptions:
        return const FOWizard();
      case InvestmentType.forexCurrency:
        return const SimpleInvestmentEntryWizard(
          type: InvestmentType.forexCurrency,
          title: 'Add Forex',
          subtitle: 'Track foreign currency positions.',
          color: Color(0xFF34495E),
          defaultName: 'Forex Position',
        );
      case InvestmentType.commodities:
        return const CommoditiesWizard();
    }
  }

  // ── Add-to-existing wizard router ───────────────────────────────────────────

  Widget _addWizardFor(Investment investment) {
    switch (investment.type) {
      case InvestmentType.stocks:
        return StocksWizard(existingInvestment: investment);
      case InvestmentType.mutualFund:
        final meta = investment.metadata ?? {};
        final intent = MFWizardIntent(
          mode: MFWizardMode.buyMore,
          mutualFund: MutualFund(
            schemeCode: (meta['schemeCode'] as String?) ?? investment.id,
            schemeName: (meta['schemeName'] as String?) ?? investment.name,
            schemeType: meta['schemeType'] as String?,
            fundHouse: meta['fundHouse'] as String?,
          ),
          transactionAmount: 0,
          transactionNav: (meta['currentNAV'] as num?)?.toDouble() ?? 0.0,
          transactionDate: DateTime.now(),
          targetInvestment: investment,
          initialStep: 3,
        );
        return MFWizard(intent: intent);
      case InvestmentType.digitalGold:
        return DigitalGoldWizard(existingInvestment: investment);
      default:
        return SimpleInvestmentEntryWizard(
          type: investment.type,
          title: 'Add ${_typeInfo[investment.type]?.label ?? investment.type.name}',
          subtitle: 'Add more to your existing position.',
          color: _typeInfo[investment.type]?.color ?? const Color(0xFF888888),
          defaultName: investment.name,
          existingInvestment: investment,
        );
    }
  }

  // ── Details screen router ───────────────────────────────────────────────────

  Widget? _detailsFor(Investment inv, {bool openDividend = false}) {
    switch (inv.type) {
      case InvestmentType.stocks:
        return StockDetailsScreen(investment: inv, autoOpenDividend: openDividend);
      case InvestmentType.mutualFund:
        return MFDetailsScreen(investment: inv, autoOpenDividend: openDividend);
      case InvestmentType.fixedDeposit:
        final meta = inv.metadata;
        if (meta != null && meta.containsKey('fdData')) {
          try {
            final fd = FixedDeposit.fromMap(
                Map<String, dynamic>.from(meta['fdData'] as Map));
            return FDDetailsScreen(fd: fd);
          } catch (e) {
            _dashboardLogger.warning('Failed to parse FD data', error: e);
          }
        }
        return null;
      case InvestmentType.recurringDeposit:
        final meta = inv.metadata;
        if (meta != null && meta.containsKey('rdData')) {
          try {
            final rd = RecurringDeposit.fromMap(
                Map<String, dynamic>.from(meta['rdData'] as Map));
            return RDDetailsScreen(rd: rd);
          } catch (e) {
            _dashboardLogger.warning('Failed to parse RD data', error: e);
          }
        }
        return null;
      case InvestmentType.bonds:
        return BondsDetailsScreen(investment: inv);
      case InvestmentType.cryptocurrency:
        return CryptoDetailsScreen(investment: inv);
      case InvestmentType.digitalGold:
        return DigitalGoldDetailsScreen(investment: inv);
      case InvestmentType.nationalSavingsScheme:
        return NPSDetailsScreen(investment: inv);
      case InvestmentType.pensionSchemes:
        return PensionDetailsScreen(investment: inv);
      case InvestmentType.commodities:
        return CommoditiesDetailsScreen(investment: inv);
      case InvestmentType.futuresOptions:
        return FODetailsScreen(investment: inv);
      default:
        return SimpleInvestmentDetailsScreen(investment: inv);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF080F1C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              const ModalHandle(),
              // Animated page
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (child, animation) {
                  final offsetTween = Tween<Offset>(
                    begin: Offset(_forward ? 0.18 : -0.18, 0),
                    end: Offset.zero,
                  );
                  return SlideTransition(
                    position: offsetTween.animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_page),
                  child: _buildPage(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(bool isDark) {
    switch (_page) {
      case _Page.home:
        return _buildHome(isDark);
      case _Page.investmentType:
        return _buildInvestmentType(isDark);
      case _Page.investmentAction:
        return _buildInvestmentAction(isDark);
      case _Page.investmentAddPick:
        return _buildInvestmentAddPick(isDark);
      case _Page.investmentSellPick:
        return _buildInvestmentSellPick(isDark);
      case _Page.dividendType:
        return _buildDividendType(isDark);
      case _Page.dividendPick:
        return _buildDividendPick(isDark);
    }
  }

  // ── Page: Home ──────────────────────────────────────────────────────────────

  Widget _buildHome(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Quick Add',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: RT.title1(context),
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.4),
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _homeRow(
            icon: CupertinoIcons.arrow_up_arrow_down_circle_fill,
            label: 'Transaction',
            subtitle: 'Record an expense or income quickly',
            color: const Color(0xFF5E6AD2),
            onTap: () {
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showQuickEntrySheet(widget.navigator.context);
              });
            },
          ),
          _homeRow(
            icon: CupertinoIcons.arrow_right_arrow_left_circle_fill,
            label: 'Transfer',
            subtitle: 'Move money between accounts',
            color: AppStyles.accentBlue,
            onTap: () => _launch(const TransferWizard()),
            isLast: !context.read<SettingsController>().isInvestmentTrackingEnabled,
          ),
          if (context.read<SettingsController>().isInvestmentTrackingEnabled) ...[
            _homeRow(
              icon: CupertinoIcons.chart_bar_alt_fill,
              label: 'Investment',
              subtitle: 'Buy, sell or add to any investment',
              color: const Color(0xFF00B050),
              onTap: () => _push(_Page.investmentType),
              hasChevron: true,
            ),
            _homeRow(
              icon: CupertinoIcons.gift_alt_fill,
              label: 'Dividend',
              subtitle: 'Record dividend from stock or MF',
              color: const Color(0xFFFF9500),
              onTap: () => _push(_Page.dividendType),
              hasChevron: true,
              isLast: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _homeRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool hasChevron = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        BouncyButton(
          onPressed: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: TypeScale.caption,
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasChevron)
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: AppStyles.getDividerColor(context),
          ),
      ],
    );
  }

  // ── Page: Investment Type ────────────────────────────────────────────────────

  Widget _buildInvestmentType(bool isDark) {
    const allTypes = InvestmentType.values;
    final screenH = MediaQuery.of(context).size.height;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader('Investment Type', 'Select the type of investment'),
        SizedBox(
          height: screenH * 0.60,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const cols = 3;
              const hPad = 20.0;
              const spacing = 10.0;
              final gridW = constraints.maxWidth - hPad * 2;
              final itemW = (gridW - (cols - 1) * spacing) / cols;
              return GridView.builder(
            padding: const EdgeInsets.fromLTRB(hPad, 8, hPad, 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: spacing,
              mainAxisSpacing: 10,
              childAspectRatio: itemW / (itemW / 0.78),
            ),
            itemCount: allTypes.length,
            itemBuilder: (ctx, i) {
              final type = allTypes[i];
              final info = _typeInfo[type]!;
              return BouncyButton(
                onPressed: () {
                  final investments = context
                      .read<InvestmentsController>()
                      .investments
                      .where((inv) => inv.type == type)
                      .toList();
                  setState(() {
                    _selectedType = type;
                    _typeInvestments = investments;
                    _forward = true;
                    _page = _Page.investmentAction;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppStyles.darkCard : CupertinoColors.systemBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: info.color.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: info.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(info.icon, size: 20, color: info.color),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          info.shortLabel,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.getTextColor(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          info.description,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w400,
                            color: AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Page: Investment Action (Add / Sell) ─────────────────────────────────────

  Widget _buildInvestmentAction(bool isDark) {
    final type = _selectedType!;
    final info = _typeInfo[type]!;
    final hasSellable = _typeInvestments.isNotEmpty;
    final screenH = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenH * 0.68,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHeader(info.label, 'What would you like to do?'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _actionTile(
                    icon: CupertinoIcons.add_circled_solid,
                    label: 'Add',
                    subtitle: 'Buy or invest',
                    color: info.color,
                    onTap: () {
                      final hasExisting = _typeInvestments.isNotEmpty &&
                          type != InvestmentType.fixedDeposit &&
                          type != InvestmentType.recurringDeposit;
                      if (hasExisting) {
                        _push(_Page.investmentAddPick);
                      } else {
                        _launch(_wizardFor(type));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionTile(
                    icon: CupertinoIcons.minus_circle_fill,
                    label: 'Sell',
                    subtitle: hasSellable ? 'Redeem or withdraw' : 'No holdings yet',
                    color: hasSellable ? const Color(0xFFFF3B30) : AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.4),
                    onTap: hasSellable
                        ? () => _push(_Page.investmentSellPick)
                        : null,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Hint row at the bottom
            Center(
              child: Text(
                hasSellable
                    ? 'You have ${_typeInvestments.length} ${info.shortLabel} holding${_typeInvestments.length == 1 ? '' : 's'}'
                    : 'No ${info.shortLabel} holdings yet — start by adding one',
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.55),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return BouncyButton(
      onPressed: onTap ?? () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withValues(alpha: 0.10)
              : AppStyles.getCardColor(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap != null ? color.withValues(alpha: 0.35) : AppStyles.getDividerColor(context),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 38, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: TypeScale.body,
                fontWeight: FontWeight.w700,
                color: onTap != null ? color : AppStyles.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: TypeScale.caption,
                color: AppStyles.getSecondaryTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Page: Investment Add Pick (New or Existing) ──────────────────────────────

  Widget _buildInvestmentAddPick(bool isDark) {
    final type = _selectedType!;
    final info = _typeInfo[type]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader('Add ${info.label}', 'New investment or add to existing?'),
        // New option
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BouncyButton(
            onPressed: () => _launch(_wizardFor(type)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [info.color, info.color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppStyles.elevatedShadows(context, tint: info.color, strength: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.add, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Investment',
                          style: TextStyle(
                            fontSize: TypeScale.body,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Start a brand new ${info.shortLabel} position',
                          style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Existing list header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(width: 3, height: 14, decoration: BoxDecoration(color: info.color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(
                'Add to Existing',
                style: TextStyle(
                  fontSize: TypeScale.footnote,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getSecondaryTextColor(context),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _typeInvestments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final inv = _typeInvestments[i];
              return _investmentRow(inv, isDark, onTap: () {
                _launch(_addWizardFor(inv));
              }, actionLabel: 'Add');
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Page: Investment Sell Pick ────────────────────────────────────────────────

  Widget _buildInvestmentSellPick(bool isDark) {
    final type = _selectedType!;
    final info = _typeInfo[type]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader('Sell ${info.label}', 'Select which holding to sell / redeem'),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _typeInvestments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final inv = _typeInvestments[i];
              // Sell → go to details where the sell/redeem action lives
              return _investmentRow(inv, isDark, onTap: () {
                final screen = _detailsFor(inv);
                if (screen != null) _launch(screen);
              }, actionLabel: 'Sell');
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Page: Dividend Type ────────────────────────────────────────────────────

  Widget _buildDividendType(bool isDark) {
    final screenH = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenH * 0.68,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHeader('Dividend', 'Which type of holding paid a dividend?'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _actionTile(
                    icon: CupertinoIcons.chart_bar_fill,
                    label: 'Stocks',
                    subtitle: 'Equity dividend',
                    color: const Color(0xFF00B050),
                    onTap: () {
                      final investments = context
                          .read<InvestmentsController>()
                          .investments
                          .where((inv) => inv.type == InvestmentType.stocks)
                          .toList();
                      setState(() {
                        _isDividendStock = true;
                        _dividendInvestments = investments;
                        _forward = true;
                        _page = _Page.dividendPick;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionTile(
                    icon: CupertinoIcons.chart_pie_fill,
                    label: 'Mutual Fund',
                    subtitle: 'MF dividend / IDCW',
                    color: const Color(0xFF0066CC),
                    onTap: () {
                      final investments = context
                          .read<InvestmentsController>()
                          .investments
                          .where((inv) => inv.type == InvestmentType.mutualFund)
                          .toList();
                      setState(() {
                        _isDividendStock = false;
                        _dividendInvestments = investments;
                        _forward = true;
                        _page = _Page.dividendPick;
                      });
                    },
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Text(
                'Dividends are credited to your account as income',
                style: TextStyle(
                  fontSize: TypeScale.caption,
                  color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.55),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page: Dividend Pick ────────────────────────────────────────────────────

  Widget _buildDividendPick(bool isDark) {
    final label = _isDividendStock ? 'Stock Dividend' : 'MF Dividend';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader(label, 'Select which holding received a dividend'),
        if (_dividendInvestments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  _isDividendStock ? CupertinoIcons.chart_bar_fill : CupertinoIcons.chart_pie_fill,
                  size: 48,
                  color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No ${_isDividendStock ? 'stock' : 'MF'} holdings found.\nAdd investments first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    color: AppStyles.getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _dividendInvestments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final inv = _dividendInvestments[i];
                return _investmentRow(inv, isDark, onTap: () {
                  final screen = _detailsFor(inv, openDividend: true);
                  if (screen != null) _launch(screen);
                }, actionLabel: 'Record');
              },
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────────

  Widget _sheetHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _goBack,
                child: const Icon(
                  CupertinoIcons.chevron_left,
                  size: 20,
                  color: AppStyles.accentBlue,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: TypeScale.title3,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.35),
                  size: 24,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: TypeScale.caption,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _investmentRow(Investment inv, bool isDark, {required VoidCallback onTap, String? actionLabel}) {
    final info = _typeInfo[inv.type];
    final color = info?.color ?? AppStyles.accentBlue;
    final currentValue = (inv.metadata?['currentValue'] as num?)?.toDouble() ?? inv.amount;
    return BouncyButton(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppStyles.darkCard : CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppStyles.getDividerColor(context), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(info?.icon ?? CupertinoIcons.chart_bar_fill, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inv.name,
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    CurrencyFormatter.compact(currentValue),
                    style: TextStyle(
                      fontSize: TypeScale.caption,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                actionLabel ?? 'View',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
