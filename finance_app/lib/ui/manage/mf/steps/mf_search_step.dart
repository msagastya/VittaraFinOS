import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/models/mutual_fund_model.dart';
import 'package:vittara_fin_os/services/mf_database_service.dart';
import 'package:vittara_fin_os/ui/manage/mf/mf_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class MFSearchStep extends StatefulWidget {
  const MFSearchStep({super.key});

  @override
  State<MFSearchStep> createState() => _MFSearchStepState();
}

class _MFSearchStepState extends State<MFSearchStep> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<MutualFund> _results = [];
  bool _isLoading = false;
  String _error = '';
  String? _selectedSchemeType;
  List<String> _schemeTypes = [];

  @override
  void initState() {
    super.initState();
    _loadSchemeTypes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSchemeTypes() async {
    final mfService = MFDatabaseService();
    final types = await mfService.getDistinctSchemeTypes();
    if (mounted) {
      setState(() {
        _schemeTypes = types;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty || _selectedSchemeType != null) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
          _error = '';
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final mfService = MFDatabaseService();
      final results = await mfService.searchMutualFunds(
        query,
        schemeType: _selectedSchemeType,
      );

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load mutual funds. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSchemeTypeChanged(String? type) {
    setState(() {
      _selectedSchemeType = type;
    });
    _performSearch(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MFWizardController>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search Mutual Fund',
                style: AppStyles.titleStyle(context),
              ),
              const SizedBox(height: 12),
              CupertinoSearchTextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                placeholder: 'Search by scheme name...',
                style: TextStyle(color: AppStyles.getTextColor(context)),
              ),
            ],
          ),
        ),
        // Scheme Type Filter Chips
        if (_schemeTypes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _onSchemeTypeChanged(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedSchemeType == null
                            ? SemanticColors.investments
                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'All',
                        style: TextStyle(
                          color: _selectedSchemeType == null
                              ? Colors.white
                              : AppStyles.getTextColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ..._schemeTypes.map((type) {
                    final isSelected = _selectedSchemeType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () => _onSchemeTypeChanged(type),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? SemanticColors.investments
                                : (isDark ? Colors.grey[800] : Colors.grey[200]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppStyles.getTextColor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        // Search Results
        Expanded(
          child: _buildContent(context, controller),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, MFWizardController controller) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    } else if (_error.isNotEmpty) {
      return Center(
        child: Text(
          _error,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    } else if (_results.isEmpty && _searchController.text.isEmpty && _selectedSchemeType == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 48,
              color: AppStyles.getSecondaryTextColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for a mutual fund',
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    } else if (_results.isEmpty) {
      return Center(
        child: Text(
          'No mutual funds found',
          style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
        ),
      );
    } else {
      return ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final mf = _results[index];
          final isSelected = controller.selectedMF?.schemeCode == mf.schemeCode;

          return GestureDetector(
            onTap: () {
              controller.selectMutualFund(mf);
              FocusScope.of(context).unfocus();
              // Auto-proceed to next step
              Future.delayed(const Duration(milliseconds: 300), () {
                controller.nextPage();
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? SemanticColors.investments.withOpacity(0.1)
                    : AppStyles.getCardColor(context),
                border: isSelected
                    ? Border.all(color: SemanticColors.investments)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: SemanticColors.investments.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            mf.schemeName.isNotEmpty
                                ? mf.schemeName.substring(0, 1).toUpperCase()
                                : 'M',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: SemanticColors.investments,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mf.schemeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppStyles.titleStyle(context).copyWith(fontSize: 14),
                            ),
                            Text(
                              '${mf.fundHouse ?? "Unknown"} • ${mf.schemeType ?? "N/A"}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          CupertinoIcons.check_mark_circled_solid,
                          color: SemanticColors.investments,
                        ),
                    ],
                  ),
                  if (mf.nav != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'NAV: ₹${mf.nav!.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
}
