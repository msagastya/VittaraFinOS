import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/services/stock_api_service.dart';
import 'package:vittara_fin_os/ui/manage/stocks/stocks_wizard_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class StockSearchStep extends StatefulWidget {
  const StockSearchStep({super.key});

  @override
  State<StockSearchStep> createState() => _StockSearchStepState();
}

class _StockSearchStepState extends State<StockSearchStep> {
  final StockApiService _apiService = StockApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<StockSearchResult> _results = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length > 1) {
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
      final results = await _apiService.searchStocks(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load stocks. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<StocksWizardController>(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: CupertinoSearchTextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            placeholder: 'Search for stocks (e.g. AAPL, RELIANCE)',
            style: TextStyle(color: AppStyles.getTextColor(context)),
          ),
        ),
        if (_isLoading)
          const Expanded(child: Center(child: CupertinoActivityIndicator()))
        else if (_error.isNotEmpty)
          Expanded(
              child: Center(
                  child:
                      Text(_error, style: const TextStyle(color: CupertinoColors.systemRed))))
        else
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final stock = _results[index];
                final isSelected =
                    controller.selectedStock?.symbol == stock.symbol;

                return GestureDetector(
                  onTap: () {
                    controller.selectStock(stock);
                    FocusScope.of(context).unfocus(); // Dismiss keyboard
                    // Auto-proceed to next step
                    Future.delayed(const Duration(milliseconds: 300), () {
                      controller.nextPage();
                    });
                  },
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? SemanticColors.investments.withValues(alpha: 0.1)
                          : AppStyles.getCardColor(context),
                      border: isSelected
                          ? Border.all(color: SemanticColors.investments)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: SemanticColors.investments
                                .withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              stock.symbol.substring(0, 1),
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
                                stock.symbol,
                                style: AppStyles.titleStyle(context)
                                    .copyWith(fontSize: TypeScale.headline),
                              ),
                              Text(
                                '${stock.name} • ${stock.exchange}',
                                style: TextStyle(
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                  fontSize: TypeScale.footnote,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(CupertinoIcons.check_mark_circled_solid,
                              color: SemanticColors.investments),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
