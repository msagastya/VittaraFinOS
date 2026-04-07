import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/account_model.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/investment_model.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/models/mutual_fund_model.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/ui/manage/mf/sip_wizard.dart';
import 'package:vittara_fin_os/utils/date_formatter.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/services/nav_service.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/app_date_picker.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/ui/styles/responsive_utils.dart';

class MFDetailsScreen extends StatefulWidget {
  final Investment investment;
  final bool autoOpenDividend;

  const MFDetailsScreen({super.key, required this.investment, this.autoOpenDividend = false});

  @override
  State<MFDetailsScreen> createState() => _MFDetailsScreenState();
}

class _MFDetailsScreenState extends State<MFDetailsScreen> {
  // Backing field — refreshed at the start of every build() via context.watch
  late Investment _investment;
  // Convenience getter used by methods outside build()
  Investment get investment => _investment;

  bool _isRefreshingNAV = false;
  final _navService = NAVService();
  Future<List<NAVData>>? _navHistoryFuture;

  @override
  void initState() {
    super.initState();
    _investment = widget.investment;
    if (widget.autoOpenDividend) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDividendModal(context);
      });
    }
    final schemeCode = _investment.metadata?['schemeCode'] as String?;
    if (schemeCode != null) {
      _navHistoryFuture =
          _navService.getHistoricalNAV(schemeCode, lastNDays: 90);
    }
  }

  Future<void> _refreshNAV() async {
    // Always read LATEST investment from controller before refreshing
    // This ensures edits aren't lost if save was still pending
    final investmentsController = Provider.of<InvestmentsController>(context, listen: false);
    final latestInvestment = investmentsController.investments
        .firstWhere((i) => i.id == investment.id, orElse: () => investment);

    final metadata = latestInvestment.metadata ?? {};
    final schemeCode = metadata['schemeCode'] as String?;
    if (schemeCode == null) {
      toast.showError('Scheme code not found');
      return;
    }
    setState(() => _isRefreshingNAV = true);
    try {
      final navData =
          await _navService.getCurrentNAV(schemeCode, forceRefresh: true);
      if (!mounted) return;
      if (navData == null) {
        toast.showError('Could not fetch NAV — try again later');
        return;
      }
      final units = (metadata['units'] as num?)?.toDouble() ?? 0;
      final updatedMeta = Map<String, dynamic>.from(metadata)
        ..['currentNAV'] = navData.nav
        ..['currentValue'] = navData.nav * units
        ..['navDate'] = navData.date.toIso8601String();
      final updatedInvestment =
          latestInvestment.copyWith(metadata: updatedMeta);
      await investmentsController.updateInvestment(updatedInvestment);
      toast.showSuccess('NAV updated: ₹${navData.nav.toStringAsFixed(4)}');
    } catch (e) {
      if (mounted) toast.showError('Failed to refresh NAV');
    } finally {
      if (mounted) setState(() => _isRefreshingNAV = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Refresh from controller on every rebuild so edits/buy-more reflect immediately
    _investment = context.watch<InvestmentsController>().investments
        .firstWhere((i) => i.id == _investment.id, orElse: () => _investment);
    final investment = _investment;
    final metadata = investment.metadata ?? {};
    final investedAmount =
        (metadata['investmentAmount'] as num?)?.toDouble() ?? investment.amount;
    final currentValue = (metadata['currentValue'] as num?)?.toDouble() ?? 0;
    final bool sipActive = metadata['sipActive'] == true;
    final sipActionLabel = sipActive ? 'Manage SIP' : 'SIP';
    final gainLoss = currentValue - investedAmount;
    final gainPercent =
        investedAmount > 0 ? (gainLoss / investedAmount) * 100 : 0;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text(
          metadata['schemeName'] as String? ?? investment.name,
          style: TextStyle(color: AppStyles.getTextColor(context)),
          overflow: TextOverflow.ellipsis,
        ),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isRefreshingNAV ? null : _refreshNAV,
          child: _isRefreshingNAV
              ? const CupertinoActivityIndicator()
              : const Icon(
                  CupertinoIcons.arrow_clockwise,
                  color: AppStyles.accentBlue,
                  size: 20,
                ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Investment Summary Card
              Container(
                padding: const EdgeInsets.all(Spacing.xl),
                decoration: BoxDecoration(
                  color: AppStyles.getCardColor(context),
                  borderRadius: BorderRadius.circular(Radii.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata['schemeName'] as String? ?? investment.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      metadata['fundHouse'] as String? ?? '',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.footnote,
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invested',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: TypeScale.footnote,
                              ),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              '₹${investedAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: TypeScale.headline,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Current Value',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: TypeScale.footnote,
                              ),
                            ),
                            const SizedBox(height: Spacing.xs),
                            Text(
                              '₹${currentValue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: TypeScale.headline,
                                color: currentValue >= investedAmount
                                    ? AppStyles.gain(context)
                                    : AppStyles.loss(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // Gain/Loss Card
              Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: gainPercent >= 0
                      ? AppStyles.gain(context).withValues(alpha: 0.1)
                      : AppStyles.loss(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: gainPercent >= 0
                        ? AppStyles.gain(context).withValues(alpha: 0.3)
                        : AppStyles.loss(context).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gain/Loss',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.footnote,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          '${gainLoss >= 0 ? '+' : ''}₹${gainLoss.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: TypeScale.headline,
                            color: gainLoss >= 0
                                ? AppStyles.gain(context)
                                : AppStyles.loss(context),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Return %',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.footnote,
                          ),
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          '${gainPercent >= 0 ? '+' : ''}${gainPercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: TypeScale.headline,
                            color: gainPercent >= 0
                                ? AppStyles.gain(context)
                                : AppStyles.loss(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // NAV History Sparkline
              if (_navHistoryFuture != null)
                FutureBuilder<List<NAVData>>(
                  future: _navHistoryFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.length < 5) {
                      return const SizedBox.shrink();
                    }
                    final navPoints = snapshot.data!.reversed.toList();
                    final navValues = navPoints.map((n) => n.nav).toList();
                    final minNav = navValues.reduce((a, b) => a < b ? a : b);
                    final maxNav = navValues.reduce((a, b) => a > b ? a : b);
                    final isUp = navValues.last >= navValues.first;
                    final lineColor = isUp
                        ? AppStyles.gain(context)
                        : AppStyles.loss(context);

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Spacing.lg),
                          decoration: BoxDecoration(
                            color: AppStyles.getCardColor(context),
                            borderRadius: BorderRadius.circular(Radii.md),
                            border: Border.all(
                                color: lineColor.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'NAV History (90 days)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: TypeScale.subhead,
                                      color: AppStyles.getTextColor(context),
                                    ),
                                  ),
                                  Text(
                                    '₹${navValues.last.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: TypeScale.body,
                                      color: lineColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Spacing.md),
                              SizedBox(
                                height: 80,
                                child: CustomPaint(
                                  size: const Size(double.infinity, 80),
                                  painter: _SparklinePainter(
                                    values: navValues,
                                    minVal: minNav,
                                    maxVal: maxNav,
                                    color: lineColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: Spacing.sm),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Low: ₹${minNav.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                  Text(
                                    'High: ₹${maxNav.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: TypeScale.caption,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Spacing.xl),
                      ],
                    );
                  },
                ),

              // Details Section
              Text(
                'Investment Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: TypeScale.headline,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const SizedBox(height: Spacing.md),
              _buildDetailRow(
                  'Units',
                  (metadata['units'] as num?)?.toDouble().toStringAsFixed(4) ??
                      '-'),
              _buildDetailRow('NAV @ Purchase',
                  '₹${(metadata['investmentNAV'] as num?)?.toDouble().toStringAsFixed(2) ?? '-'}'),
              _buildDetailRow('Current NAV',
                  '₹${(metadata['currentNAV'] as num?)?.toDouble().toStringAsFixed(2) ?? '-'}',
                  labelSuffix: const JargonTooltip.nav()),
              if (metadata['navDate'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'NAV as of: ${_formatDate(metadata['navDate'] as String)}',
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.caption,
                      ),
                    ),
                  ),
                ),
              _buildDetailRow(
                  'Scheme Type', metadata['schemeType'] as String? ?? '-'),
              _buildDetailRow(
                  'Scheme Code', metadata['schemeCode'] as String? ?? '-'),

              if (metadata['investmentDate'] != null) ...[
                _buildDetailRow(
                  'Investment Date',
                  _formatDate(metadata['investmentDate'] as String),
                ),
              ],

              if (metadata['sipActive'] == true) ...[
                const SizedBox(height: Spacing.xl),
                Text(
                  'SIP Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.headline,
                    color: AppStyles.getTextColor(context),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Container(
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: SemanticColors.investments.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: SemanticColors.investments.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'This investment has an active SIP setup.',
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.footnote,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: Spacing.xl),

              Text(
                'Actions',
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const SizedBox(height: Spacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  const cols = 2;
                  const spacing = Spacing.lg;
                  final itemW = (constraints.maxWidth - (cols - 1) * spacing) / cols;
                  return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: itemW / (itemW * 1.3),
                children: [
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.plus_circle_fill,
                    label: 'Buy More',
                    color: AppStyles.gain(context),
                    onTap: () => _showBuyMoreWizard(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.minus_circle_fill,
                    label: 'Sell',
                    color: AppStyles.loss(context),
                    onTap: () => _showSellWizard(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.repeat,
                    label: 'SIP',
                    color: CupertinoColors.systemBlue,
                    onTap: () => _handleSIPAction(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.pencil_circle_fill,
                    label: 'Edit',
                    color: CupertinoColors.systemOrange,
                    onTap: () => _showEditModal(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.money_dollar_circle_fill,
                    label: 'Dividend',
                    color: CupertinoColors.systemBrown,
                    onTap: () => _showDividendModal(context),
                  ),
                  _buildActionButton(
                    context,
                    icon: CupertinoIcons.trash_circle_fill,
                    label: 'Delete',
                    color: AppStyles.loss(context),
                    onTap: () => _showDeleteConfirmation(context),
                  ),
                ],
                  );
                },
              ),

              const SizedBox(height: Spacing.xl),

              // Activity Log
              _buildActivityLog(),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityLog() {
    final activityLog = (investment.metadata?['activityLog'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];
    if (activityLog.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activity',
            style: AppStyles.titleStyle(context).copyWith(fontSize: TypeScale.headline)),
        const SizedBox(height: Spacing.lg),
        ...activityLog.reversed.map((entry) => _buildActivityEntry(entry)),
      ],
    );
  }

  Widget _buildActivityEntry(Map<String, dynamic> entry) {
    final type = entry['type'] as String? ?? 'buy';
    final amount = (entry['amount'] as num?)?.toDouble() ?? 0.0;
    final description = entry['description'] as String? ?? '';
    final accountName = entry['accountName'] as String? ?? '';
    final dateStr = entry['date'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

    final isSell = type == 'sell' || type == 'decrease' || type == 'redeem';
    final isDividend = type == 'dividend';
    final color = isDividend
        ? const Color(0xFFFFB800)
        : isSell ? AppStyles.gain(context) : CupertinoColors.systemIndigo;
    final icon = isDividend
        ? CupertinoIcons.money_dollar_circle_fill
        : isSell ? CupertinoIcons.arrow_up_circle_fill : CupertinoIcons.arrow_down_circle_fill;

    final label = isDividend ? 'Dividend' : isSell ? 'Redeemed' : description.isNotEmpty ? description : 'Invested';

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: AppStyles.cardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: TypeScale.subhead,
                            color: AppStyles.getTextColor(context),
                          )),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '${isSell || isDividend ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: TypeScale.subhead,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (date != null) ...[
                  const SizedBox(height: Spacing.xs),
                  Text(
                    DateFormatter.format(date),
                    style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.footnote,
                    ),
                  ),
                ],
                if (accountName.isNotEmpty) ...[
                  const SizedBox(height: Spacing.xs),
                  Row(
                    children: [
                      Icon(CupertinoIcons.creditcard_fill,
                          size: 12, color: AppStyles.getSecondaryTextColor(context)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(accountName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppStyles.getSecondaryTextColor(context),
                              fontSize: TypeScale.footnote,
                            )),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {Widget? labelSuffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: TypeScale.subhead),
              ),
              if (labelSuffix != null) ...[
                const SizedBox(width: 3),
                labelSuffix,
              ],
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: TypeScale.subhead,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    return date != null ? DateFormatter.format(date) : isoDate;
  }

  void _showBuyMoreWizard(BuildContext context) =>
      _launchMFWizard(context, MFWizardMode.buyMore);

  void _showSellWizard(BuildContext context) =>
      _launchMFWizard(context, MFWizardMode.sell);

  void _handleSIPAction(BuildContext context) {
    final metadata = investment.metadata ?? {};
    final sipActive = metadata['sipActive'] == true;

    if (!sipActive) {
      _openSIPWizard(context);
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (_) => RLayout.tabletConstrain(
        _,
        CupertinoActionSheet(
        title: const Text('SIP Options'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Edit SIP'),
            onPressed: () {
              Navigator.pop(context);
              final account = _resolveSIPAccount(context, metadata);
              _openSIPWizard(
                context,
                initialData: metadata['sipData'] as Map<String, dynamic>?,
                initialAccount: account,
              );
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Stop SIP'),
            onPressed: () {
              Navigator.pop(context);
              _stopSIP(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      ),
    );
  }

  Future<void> _openSIPWizard(
    BuildContext context, {
    Map<String, dynamic>? initialData,
    Account? initialAccount,
  }) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      FadeScalePageRoute(
        page: SIPWizard(
          initialData: initialData,
          initialAccount: initialAccount,
        ),
      ),
    );
    if (result == null) return;

    final controller =
        Provider.of<InvestmentsController>(context, listen: false);
    final metadata = Map<String, dynamic>.from(investment.metadata ?? {});
    metadata['sipActive'] = true;
    metadata['sipData'] = result;
    metadata['sipUpdatedAt'] = DateTime.now().toIso8601String();
    final nowIso = DateTime.now().toIso8601String();
    metadata['sipLastExecutionDate'] = nowIso;
    metadata['sipStartDate'] = metadata['sipStartDate'] ?? nowIso;
    final executionLog =
        (metadata['sipExecutionLog'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    executionLog.add({
      'action': 'updated',
      'date': nowIso,
      'amount': result['sipAmount'],
      'frequency': result['frequency'],
    });
    metadata['sipExecutionLog'] = executionLog;

    final updatedInvestment = investment.copyWith(metadata: metadata);
    controller.updateInvestment(updatedInvestment);
    if (context.mounted) {
      toast.showSuccess('SIP configuration saved');
    }
  }

  void _stopSIP(BuildContext context) {
    final metadata = Map<String, dynamic>.from(investment.metadata ?? {});
    if (metadata['sipActive'] != true) return;

    metadata['sipActive'] = false;
    metadata.remove('sipData');
    metadata.remove('sipLinkedAccount');
    metadata.remove('sipFrequency');
    metadata.remove('sipStartDate');
    metadata.remove('sipLastExecutionDate');
    metadata.remove('sipExecutionLog');

    final updatedInvestment = investment.copyWith(metadata: metadata);
    Provider.of<InvestmentsController>(context, listen: false)
        .updateInvestment(updatedInvestment);
    if (context.mounted) {
      toast.showSuccess('SIP stopped for this fund');
    }
  }

  void _showEditModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => RLayout.tabletConstrain(
        _,
        _EditMFModal(investment: investment),
      ),
    );
  }

  void _showDividendModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => RLayout.tabletConstrain(
        _,
        _MFDividendModal(investment: investment),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Investment'),
        content: const Text(
            'Are you sure you want to delete this mutual fund investment?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Provider.of<InvestmentsController>(context, listen: false)
                  .removeInvestment(investment.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
              toast.showSuccess('Investment deleted');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchMFWizard(BuildContext context, MFWizardMode mode) async {
    final metadata = investment.metadata ?? {};
    final mutualFund = _buildMutualFund(metadata);
    final nav = _extractNav(metadata);
    final units = (metadata['units'] as num?)?.toDouble();
    final account = _resolveLinkedAccount(context, metadata);
    final sipActive = metadata['sipActive'] == true;

    final intent = MFWizardIntent(
      mode: mode,
      mutualFund: mutualFund,
      transactionAmount: 0,
      transactionNav: nav,
      transactionDate: DateTime.now(),
      targetInvestment: investment,
      account: account,
      transactionUnits: mode == MFWizardMode.sell ? units : null,
      initialStep: 3,
      sipActive: sipActive,
    );

    await Navigator.of(context).push(
      FadeScalePageRoute(page: MFWizard(intent: intent)),
    );
  }

  MutualFund _buildMutualFund(Map<String, dynamic> metadata) {
    return MutualFund(
      schemeCode: metadata['schemeCode'] as String? ?? investment.id,
      schemeName: metadata['schemeName'] as String? ?? investment.name,
      schemeType: metadata['schemeType'] as String?,
      fundHouse: metadata['fundHouse'] as String?,
      nav: (metadata['currentNAV'] as num?)?.toDouble() ??
          (metadata['investmentNAV'] as num?)?.toDouble(),
    );
  }

  double _extractNav(Map<String, dynamic> metadata) {
    return (metadata['currentNAV'] as num?)?.toDouble() ??
        (metadata['investmentNAV'] as num?)?.toDouble() ??
        0;
  }

  Account? _resolveSIPAccount(
      BuildContext context, Map<String, dynamic> metadata) {
    final accountId = (metadata['sipData']
            as Map<String, dynamic>?)?['deductionAccountId'] as String? ??
        metadata['sipLinkedAccount'] as String?;
    if (accountId == null) return null;
    final accounts =
        Provider.of<AccountsController>(context, listen: false).accounts;
    for (final account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }

  Account? _resolveLinkedAccount(
      BuildContext context, Map<String, dynamic> metadata) {
    final accountId = metadata['accountId'] as String?;
    if (accountId == null) return null;
    final accounts =
        Provider.of<AccountsController>(context, listen: false).accounts;
    for (final account in accounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppStyles.cardDecoration(context),
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: TypeScale.body,
                color: AppStyles.getTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MFDividendModal extends StatefulWidget {
  final Investment investment;

  const _MFDividendModal({required this.investment});

  @override
  State<_MFDividendModal> createState() => _MFDividendModalState();
}

class _MFDividendModalState extends State<_MFDividendModal> {
  late TextEditingController _amountController;
  DateTime _dividendDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _dividendDate,
      maximumDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dividendDate = picked);
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    final controller = Provider.of<InvestmentsController>(
      context,
      listen: false,
    );
    await controller.recordInvestmentActivity(
      investmentId: widget.investment.id,
      type: 'dividend',
      amount: amount,
      description: 'Dividend from ${widget.investment.name}',
      dateTime: _dividendDate,
    );
    if (!mounted) return;
    toast.showSuccess('Dividend ₹${amount.toStringAsFixed(2)} recorded');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ModalHandle(),
            const SizedBox(height: Spacing.lg),
            Text(
              'Dividend',
              style: AppStyles.titleStyle(context)
                  .copyWith(fontSize: RT.title1(context)),
            ),
            const SizedBox(height: Spacing.xxxl),
            _buildField(context, 'Amount', prefix: '₹'),
            const SizedBox(height: Spacing.lg),
            _buildDateField(context),
            const SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: _submit,
                child: const Text('Record Dividend'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, String label, {String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: Spacing.xs),
        CupertinoTextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          prefix: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(prefix,
                      style: TextStyle(color: AppStyles.getTextColor(context))),
                )
              : null,
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
      ],
    );
  }

  Widget _buildDateField(BuildContext context) {
    final label =
        '${_dividendDate.day}/${_dividendDate.month}/${_dividendDate.year}';
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: AppStyles.getBackground(context),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Dividend Date',
                style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600)),
            Text(label,
                style:
                    TextStyle(color: AppStyles.getSecondaryTextColor(context))),
          ],
        ),
      ),
    );
  }
}

class _EditMFModal extends StatefulWidget {
  final Investment investment;

  const _EditMFModal({required this.investment});

  @override
  State<_EditMFModal> createState() => _EditMFModalState();
}

class _EditMFModalState extends State<_EditMFModal> {
  late TextEditingController _amountController;
  late TextEditingController _navController;
  late TextEditingController _unitsController;

  @override
  void initState() {
    super.initState();
    final metadata = widget.investment.metadata ?? {};
    _amountController = TextEditingController(
      text: (metadata['investmentAmount'] as num?)?.toStringAsFixed(2) ??
          widget.investment.amount.toStringAsFixed(2),
    );
    _navController = TextEditingController(
      text: (metadata['investmentNAV'] as num?)?.toStringAsFixed(4) ?? '',
    );
    _unitsController = TextEditingController(
      text: (metadata['units'] as num?)?.toStringAsFixed(4) ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _navController.dispose();
    _unitsController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final investmentAmount =
        double.tryParse(_amountController.text) ?? widget.investment.amount;
    final investmentNav = double.tryParse(_navController.text) ??
        (widget.investment.metadata?['investmentNAV'] as num?)?.toDouble() ??
        0;
    final units = double.tryParse(_unitsController.text) ??
        (widget.investment.metadata?['units'] as num?)?.toDouble() ??
        0;

    final metadata =
        Map<String, dynamic>.from(widget.investment.metadata ?? {});
    metadata['investmentAmount'] = investmentAmount;
    metadata['investmentNAV'] = investmentNav;
    metadata['units'] = units;
    metadata['currentValue'] = investmentNav * units;

    final updatedInvestment = widget.investment
        .copyWith(amount: investmentAmount, metadata: metadata);

    try {
      await Provider.of<InvestmentsController>(context, listen: false)
          .updateInvestment(updatedInvestment);
      if (!mounted) return;
      toast.showSuccess('Mutual fund updated');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        toast.showError('Failed to save changes: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ModalHandle(),
              const SizedBox(height: Spacing.lg),
              Text(
                'Edit Mutual Fund',
                style: AppStyles.titleStyle(context)
                    .copyWith(fontSize: RT.title1(context)),
              ),
              const SizedBox(height: Spacing.xxxl),
              _buildInputField(context, 'Investment Amount', _amountController,
                  prefix: '₹'),
              const SizedBox(height: Spacing.lg),
              _buildInputField(context, 'Average NAV', _navController),
              const SizedBox(height: Spacing.lg),
              _buildInputField(context, 'Units', _unitsController),
              const SizedBox(height: Spacing.xl),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _saveChanges,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: Spacing.sm),
        CupertinoTextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: '0.00',
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.getBackground(context),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          prefix: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(prefix,
                      style: TextStyle(color: AppStyles.getTextColor(context))),
                )
              : null,
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final double minVal;
  final double maxVal;
  final Color color;

  _SparklinePainter({
    required this.values,
    required this.minVal,
    required this.maxVal,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final range = maxVal - minVal;
    if (range == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    const double x0 = 0;
    final double y0 = size.height - ((values[0] - minVal) / range) * size.height;
    path.moveTo(x0, y0);
    fillPath.moveTo(x0, size.height);
    fillPath.lineTo(x0, y0);

    for (int i = 1; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minVal) / range) * size.height;
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      values != oldDelegate.values || color != oldDelegate.color;
}
