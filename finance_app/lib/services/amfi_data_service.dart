import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:vittara_fin_os/models/mutual_fund_model.dart';

class AMFIDataService {
  static const String amfiUrl = 'https://www.amfiindia.com/spages/NAVAll.txt';
  static final Logger _logger = Logger();

  static Future<List<MutualFund>> fetchAndParseAMFIData() async {
    try {
      final response = await http.get(Uri.parse(amfiUrl)).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('AMFI request timeout');
        },
      );

      if (response.statusCode == 200) {
        return _parseAMFIData(response.body);
      } else {
        throw Exception('Failed to load AMFI data: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error fetching AMFI data: $e');
      rethrow;
    }
  }

  static List<MutualFund> _parseAMFIData(String rawData) {
    final List<MutualFund> mutualFunds = [];
    final lines = rawData.split('\n');
    int failCount = 0;
    int totalDataLines = 0;

    for (String line in lines) {
      if (line.trim().isEmpty) continue;
      totalDataLines++;

      try {
        final mf = _parseLine(line);
        if (mf != null) {
          mutualFunds.add(mf);
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
        _logger.w('Error parsing AMFI line: $line, Error: $e');
        continue;
      }
    }

    if (totalDataLines > 0) {
      final failRate = failCount / totalDataLines;
      if (failRate > 0.5) {
        _logger.w('[AMFI] WARNING: ${(failRate * 100).round()}% of lines failed to parse');
      }
    }

    _logger.i('Parsed ${mutualFunds.length} mutual funds from AMFI data');
    return mutualFunds;
  }

  static MutualFund? _parseLine(String line) {
    final parts = line.split(';');
    if (parts.length < 6) return null;

    final schemeCode = parts[0].trim();
    final isin = (parts[1].trim().isNotEmpty ? parts[1] : parts[2]).trim();
    final schemeName = parts[3].trim();
    final navString = parts[4].trim();
    final dateString = parts[5].trim();

    if (schemeCode.isEmpty || schemeName.isEmpty) return null;

    try {
      final nav = double.tryParse(navString);

      // Extract fund house, scheme type, and category from scheme name
      final (fundHouse, schemeType, category) =
          _extractMetadataFromName(schemeName);

      return MutualFund(
        schemeCode: schemeCode,
        schemeName: schemeName,
        isin: isin.isNotEmpty ? isin : null,
        schemeType: schemeType,
        fundHouse: fundHouse,
        nav: nav,
        lastUpdated: dateString,
        category: category,
        isActive: 1,
      );
    } catch (e) {
      throw Exception('Failed to parse line: $e');
    }
  }

  static (String?, String?, String?) _extractMetadataFromName(String name) {
    String? fundHouse;
    String? schemeType;
    String? category;

    // Extract fund house (first part before "-")
    final parts = name.split('-');
    if (parts.isNotEmpty) {
      fundHouse = parts[0].trim();
    }

    // Extract scheme type (case-insensitive matching)
    final schemeTypeKeywords = [
      'Equity',
      'Debt',
      'Hybrid',
      'Liquid',
      'Money Market',
      'Balanced Advantage',
      'Multi Asset',
      'Arbitrage',
      'Gold',
      'International',
    ];

    final nameLower = name.toLowerCase();
    for (var keyword in schemeTypeKeywords) {
      if (nameLower.contains(keyword.toLowerCase())) {
        schemeType = keyword;
        break;
      }
    }

    // Extract category (case-insensitive matching)
    final categoryKeywords = [
      'Large Cap',
      'Mid Cap',
      'Small Cap',
      'Multi Cap',
      'Focused',
      'Dividend Yield',
      'Value',
      'Contra',
      'ELSS',
    ];

    for (var keyword in categoryKeywords) {
      if (nameLower.contains(keyword.toLowerCase())) {
        category = keyword;
        break;
      }
    }

    return (fundHouse, schemeType, category);
  }
}
