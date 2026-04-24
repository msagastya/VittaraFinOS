import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vittara_fin_os/logic/accounts_controller.dart';
import 'package:vittara_fin_os/logic/budgets_controller.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/goals_controller.dart';
import 'package:vittara_fin_os/logic/investments_controller.dart';
import 'package:vittara_fin_os/logic/transactions_controller.dart';
import 'package:vittara_fin_os/logic/transaction_model.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/backup_restore_screen.dart';
import 'package:vittara_fin_os/ui/financial_calendar_screen.dart';
import 'package:vittara_fin_os/ui/manage/account_wizard.dart';
import 'package:vittara_fin_os/ui/manage/accounts_screen.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budgets_screen.dart';
import 'package:vittara_fin_os/ui/manage/categories_screen.dart';
import 'package:vittara_fin_os/ui/manage/goals/goals_screen.dart';
import 'package:vittara_fin_os/ui/manage/lending_borrowing_screen.dart';
import 'package:vittara_fin_os/ui/manage/transactions_archive_screen.dart';
import 'package:vittara_fin_os/ui/net_worth_page.dart';
import 'package:vittara_fin_os/ui/settings/csv_import_screen.dart';
import 'package:vittara_fin_os/ui/settings_screen.dart';
import 'package:vittara_fin_os/ui/spending_insights_screen.dart';
import 'package:vittara_fin_os/ui/transaction_history_screen.dart';
import 'package:vittara_fin_os/ui/widgets/transaction_details_content.dart';
import 'package:vittara_fin_os/ui/manage/budgets/budget_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/contacts_screen.dart';
import 'package:vittara_fin_os/ui/manage/goals/goal_details_screen.dart';
import 'package:vittara_fin_os/ui/manage/investments_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/logic/search/nl_search_engine.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

const String _kRecentSearchesKey = 'global_search_recent';
const int _kMaxRecentSearches = 10;

enum _ResultType { transaction, account, investment, goal, budget, contact, action }

class _SearchResult {
  final _ResultType type;
  final String id;
  final String title;
  final String subtitle;
  final double? amount;
  final IconData icon;
  final Color color;
  /// Called after the search overlay is dismissed.
  final VoidCallback onNavigate;

  const _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.amount,
    required this.icon,
    required this.color,
    required this.onNavigate,
  });
}

// ── NL Query Parser ────────────────────────────────────────────────────────────

class _ParsedQuery {
  final String displaySummary;
  final String? keyword;
  final DateTime? fromDate;
  final DateTime? toDate;
  final TransactionType? type;
  final double? minAmount;
  final double? maxAmount;
  final List<String> categoryHints;

  const _ParsedQuery({
    required this.displaySummary,
    this.keyword,
    this.fromDate,
    this.toDate,
    this.type,
    this.minAmount,
    this.maxAmount,
    this.categoryHints = const [],
  });
}

/// Flexible NL parser — understands English, Hindi, Hinglish, partial words,
/// multi-word synonyms ("friends & relatives" = "friends and relatives").
///
/// Strategy: normalise synonyms → match date/type/amount signals (longest
/// match wins) → category hints → anything left = keyword filter.
class _NLQueryParser {

  // ── Synonym normalisation — applied before everything else ────────────────
  static String _normaliseSynonyms(String q) {
    var s = q;
    // Symbol synonyms
    s = s.replaceAll(RegExp(r'\s*&\s*'), ' and ');
    s = s.replaceAll(RegExp(r'\s*\+\s*'), ' and ');
    // Currency words
    s = s.replaceAll(RegExp(r'\b(?:rupaye|rupaiye|rupaye|paisa|paise|rupe)\b'), 'rupees');
    // Devanagari digits → ASCII
    const d = ['०','१','२','३','४','५','६','७','८','९'];
    for (int i = 0; i < d.length; i++) s = s.replaceAll(d[i], '$i');
    return s;
  }

  // ── Category signals — English + Hindi + Hinglish ─────────────────────────
  static const _catMap = <String, List<String>>{
    'Food': [
      'food', 'eat', 'eating', 'ate', 'lunch', 'dinner', 'breakfast',
      'snack', 'snacks', 'cafe', 'coffee', 'chai', 'tea', 'restaurant',
      'dining', 'swiggy', 'zomato', 'dunzo', 'khaana', 'khana', 'bhojan',
      'khaya', 'nashta', 'pizza', 'burger', 'biryani', 'sandwich', 'hotel',
      'dhaba', 'tapri', 'dominos', 'kfc', 'mcdonalds', 'subway', 'starbucks',
      'chaayos', 'barbeque', 'mithai', 'sweets', 'juice', 'ice cream',
      'haldiram', 'bikanervala', 'wow momo', 'pizza hut', 'burger king',
    ],
    'Groceries': [
      'grocery', 'groceries', 'vegetables', 'veggies', 'sabzi', 'subzi',
      'fruits', 'milk', 'doodh', 'kiryana', 'kirana', 'ration', 'dal',
      'chawal', 'rice', 'atta', 'flour', 'oil', 'blinkit', 'zepto',
      'bigbasket', 'dmart', 'reliance fresh', 'more supermarket', 'grofers',
      'instamart', 'jiomart', 'smart bazaar',
    ],
    'Transport': [
      'transport', 'travel', 'uber', 'ola', 'rapido', 'cab', 'taxi', 'auto',
      'rickshaw', 'metro', 'bus', 'train', 'local', 'petrol', 'fuel',
      'diesel', 'cng', 'irctc', 'flight', 'airport', 'namma yatri',
      'yatri', 'gaadi', 'bike', 'ride', 'makemytrip', 'goibibo', 'cleartrip',
      'ixigo', 'redbus', 'abhibus', 'toll', 'fastag', 'indigo', 'air india',
      'spicejet', 'safar',
    ],
    'Shopping': [
      'shopping', 'shop', 'amazon', 'flipkart', 'myntra', 'meesho', 'ajio',
      'nykaa', 'tata cliq', 'snapdeal', 'shopsy', 'clothes', 'clothing',
      'shoes', 'kapde', 'dress', 'shirt', 'pant', 'jeans', 'kurta', 'saree',
      'watch', 'gadget', 'electronics', 'mobile', 'laptop', 'kharidna',
      'kharid',
    ],
    'Entertainment': [
      'entertainment', 'netflix', 'prime', 'hotstar', 'disney', 'spotify',
      'youtube', 'zee5', 'sonyliv', 'jiosaavn', 'wynk', 'movie', 'cinema',
      'film', 'pvr', 'inox', 'cinepolis', 'multiplex', 'bookmyshow',
      'game', 'gaming', 'play', 'concert', 'show', 'event', 'ticket',
      'tamaasha', 'timepass',
    ],
    'Health': [
      'health', 'medical', 'doctor', 'hospital', 'clinic', 'pharmacy',
      'medicine', 'dawa', 'dawai', 'davai', 'tablet', 'syrup', 'gym',
      'fitness', 'yoga', 'dentist', 'apollo', 'practo', 'medplus',
      'netmeds', '1mg', 'pharmeasy', 'wellness', 'cult fit', 'ilaj',
    ],
    'Utilities': [
      'electricity', 'light bill', 'bijli', 'water bill', 'internet', 'wifi',
      'broadband', 'mobile recharge', 'recharge', 'postpaid', 'prepaid',
      'dth', 'tata sky', 'airtel xstream', 'gas', 'cylinder', 'lpg',
      'utility', 'bill', 'jio', 'airtel', 'bsnl', 'bijli bill',
    ],
    'Rent': [
      'rent', 'kiraya', 'house rent', 'pg', 'hostel', 'maintenance',
      'society', 'housing', 'flat', 'room', 'makaan',
    ],
    'Insurance': [
      'insurance', 'lic', 'premium', 'policy', 'term plan', 'health insurance',
      'bima', 'mediclaim', 'life insurance',
    ],
    'Investment': [
      'invest', 'investment', 'sip', 'mutual fund', 'mf', 'stocks', 'shares',
      'nifty', 'zerodha', 'groww', 'upstox', 'angel', 'nps', 'ppf', 'elss',
      'fd', 'fixed deposit', 'gold', 'crypto', 'bitcoin', 'nivesh',
    ],
    'Subscription': [
      'subscription', 'subscribe', 'plan', 'renewal', 'annual', 'monthly plan',
      'membership', 'pass',
    ],
    'Education': [
      'school', 'college', 'fees', 'tuition', 'coaching', 'course', 'books',
      'stationery', 'udemy', 'coursera', 'byju', 'unacademy', 'vedantu',
      'padhai',
    ],
    'Personal Care': [
      'salon', 'parlour', 'haircut', 'spa', 'massage', 'beauty', 'nykaa',
      'shampoo', 'soap', 'toiletries', 'laundry', 'dhobi',
    ],
    'Friends and Relatives': [
      // All surface variants of this common user-created category
      'friends', 'relatives', 'family', 'dost', 'yaaron', 'yaar',
      'rishtedaar', 'bhai', 'behen', 'papa', 'mummy', 'mama', 'chacha',
      'maama', 'nana', 'nani', 'dada', 'dadi', 'gift', 'gifting',
      'birthday', 'anniversary', 'party',
    ],
    'Petrol': [
      'petrol', 'diesel', 'cng', 'pump', 'petrol pump', 'iocl', 'bpcl',
      'hpcl', 'indian oil', 'bharat petroleum', 'nayara',
    ],
    'EMI': [
      'emi', 'loan emi', 'home loan', 'car loan', 'bike emi',
      'installment', 'kist', 'kisht',
    ],
  };

  // ── Date signals (multi-word first, then single) ───────────────────────────
  static final _dateSignals = <String, String>{
    // Multi-word — must come before single-word
    'day before yesterday': 'daybeforeyesterday',
    'this week': 'thisweek',
    'is hafte': 'thisweek',
    'is week': 'thisweek',
    'last week': 'lastweek',
    'pichle hafte': 'lastweek',
    'pichhle hafte': 'lastweek',
    'pichle week': 'lastweek',
    'this month': 'thismonth',
    'is mahine': 'thismonth',
    'is month': 'thismonth',
    'last month': 'lastmonth',
    'pichle mahine': 'lastmonth',
    'pichhle mahine': 'lastmonth',
    'previous month': 'lastmonth',
    'last 7 days': 'last7',
    'last seven days': 'last7',
    'pichhle 7 din': 'last7',
    'last 14 days': 'last14',
    'last 30 days': 'last30',
    'last 3 months': 'last3m',
    'last three months': 'last3m',
    'past 3 months': 'last3m',
    'pichle 3 mahine': 'last3m',
    'last 6 months': 'last6m',
    'pichle 6 mahine': 'last6m',
    'last year': 'lastyear',
    'pichle saal': 'lastyear',
    'this year': 'thisyear',
    'is saal': 'thisyear',
    // Single-word
    'today': 'today',
    'aaj': 'today',
    'yesterday': 'yesterday',
    'parso': 'daybeforeyesterday',
    'parson': 'daybeforeyesterday',
  };

  // ── Type signals ──────────────────────────────────────────────────────────
  static const _expenseWords = [
    // English active
    'expense', 'expenses', 'spent', 'spend', 'spending', 'paid', 'pay',
    'debit', 'debited', 'outgoing', 'charged', 'deducted', 'purchased',
    // English passive
    'was charged', 'was deducted', 'got charged', 'got deducted',
    'was debited', 'got debited', 'has been deducted',
    // Hindi active
    'kharcha', 'kharch', 'diya', 'diye', 'liya', 'khaaya', 'khaya',
    'kharcha kiya', 'kharch kiya',
    // Hindi passive (money went out)
    'bahar gaya', 'nikal', 'cut', 'kat gaya', 'kat gayi', 'kat gaye',
    'cut ho gaya', 'deduct hua', 'nikla', 'nikle', 'paise gaye',
    'paisa gaya', 'gaye paise', 'kharch ho gaya',
  ];
  static const _incomeWords = [
    // English
    'income', 'received', 'receive', 'credited', 'credit', 'earnings',
    'earned', 'salary', 'incoming', 'refund', 'cashback', 'bonus',
    'dividend', 'interest',
    // Hindi
    'mila', 'mili', 'mile', 'aaya', 'aayi', 'aaye', 'paise aaye',
    'paisa aaya', 'salary aayi', 'jama hua', 'aa gaya',
  ];
  static const _transferWords = [
    'transfer', 'transfers', 'transferred', 'sent', 'send', 'moved',
    'bheja', 'bhejo', 'bhej diya', 'upi transfer',
  ];

  static _ParsedQuery? parse(String rawInput) {
    if (rawInput.trim().isEmpty) return null;

    // Normalise synonyms first
    final q = _normaliseSynonyms(rawInput.toLowerCase().trim());

    DateTime? from, to;
    TransactionType? txType;
    double? minAmt, maxAmt;
    final catHints = <String>[];
    final tags = <String>[];
    var residual = q;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── 1. "N days/din ago" relative date ─────────────────────────────────────
    final daysAgoRx = RegExp(r'\b(\d+)\s+(?:days?\s+ago|din\s+(?:pehle|pahle))\b');
    final daysAgoM = daysAgoRx.firstMatch(q);
    if (daysAgoM != null) {
      final n = int.tryParse(daysAgoM.group(1)!) ?? 0;
      if (n > 0 && n <= 365) {
        final d = today.subtract(Duration(days: n));
        from = d;
        to = DateTime(d.year, d.month, d.day, 23, 59, 59);
        tags.add('$n days ago');
        residual = residual.replaceAll(daysAgoM.group(0)!, '');
      }
    }

    // ── 2. Multi-word date signals (longest match wins) ───────────────────────
    if (from == null) {
      String? dateKey;
      final sortedKeys = _dateSignals.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final key in sortedKeys) {
        if (q.contains(key)) {
          dateKey = _dateSignals[key];
          residual = residual.replaceAll(key, '');
          break;
        }
      }

      // Month name matching (English + Hindi)
      if (dateKey == null) {
        const months = [
          'january', 'february', 'march', 'april', 'may', 'june',
          'july', 'august', 'september', 'october', 'november', 'december',
        ];
        const shortMonths = [
          'jan', 'feb', 'mar', 'apr', 'may', 'jun',
          'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
        ];
        const hindiMonths = [
          'january', 'february', 'march', 'april', 'may', 'june',
          'july', 'august', 'september', 'october', 'november', 'december',
          // Hindi month names (approximate common usage)
          'janvari', 'farvari', 'march', 'april', 'mai', 'june',
          'july', 'august', 'september', 'october', 'november', 'december',
        ];
        for (int i = 0; i < months.length; i++) {
          if (q.contains(months[i]) || q.contains(shortMonths[i])) {
            dateKey = 'month:${i + 1}';
            residual = residual
                .replaceAll(months[i], '')
                .replaceAll(shortMonths[i], '');
            break;
          }
        }
        // Hindi months
        const hm = ['janvari', 'farvari', 'march', 'april', 'mai', 'june',
            'july', 'august', 'september', 'october', 'november', 'december'];
        if (dateKey == null) {
          for (int i = 0; i < hm.length; i++) {
            if (q.contains(hm[i])) {
              dateKey = 'month:${i + 1}';
              residual = residual.replaceAll(hm[i], '');
              break;
            }
          }
        }
      }

      if (dateKey != null) {
        switch (dateKey) {
          case 'today':
            from = today; to = now; tags.add('Today');
            break;
          case 'yesterday':
            final y = today.subtract(const Duration(days: 1));
            from = y;
            to = DateTime(y.year, y.month, y.day, 23, 59, 59);
            tags.add('Yesterday');
            break;
          case 'daybeforeyesterday':
            final d = today.subtract(const Duration(days: 2));
            from = d;
            to = DateTime(d.year, d.month, d.day, 23, 59, 59);
            tags.add('Day before yesterday');
            break;
          case 'thisweek':
            from = today.subtract(Duration(days: today.weekday - 1));
            to = now; tags.add('This week');
            break;
          case 'lastweek':
            final sw = today.subtract(Duration(days: today.weekday - 1));
            from = sw.subtract(const Duration(days: 7));
            to = sw.subtract(const Duration(seconds: 1));
            tags.add('Last week');
            break;
          case 'thismonth':
            from = DateTime(now.year, now.month, 1); to = now;
            tags.add('This month');
            break;
          case 'lastmonth':
            final lm = DateTime(now.year, now.month - 1, 1);
            from = lm;
            to = DateTime(lm.year, lm.month + 1, 1).subtract(const Duration(seconds: 1));
            tags.add('Last month');
            break;
          case 'last7':
            from = today.subtract(const Duration(days: 7)); to = now;
            tags.add('Last 7 days');
            break;
          case 'last14':
            from = today.subtract(const Duration(days: 14)); to = now;
            tags.add('Last 14 days');
            break;
          case 'last30':
            from = today.subtract(const Duration(days: 30)); to = now;
            tags.add('Last 30 days');
            break;
          case 'last3m':
            from = DateTime(now.year, now.month - 3, 1); to = now;
            tags.add('Last 3 months');
            break;
          case 'last6m':
            from = DateTime(now.year, now.month - 6, 1); to = now;
            tags.add('Last 6 months');
            break;
          case 'thisyear':
            from = DateTime(now.year, 1, 1); to = now;
            tags.add('This year');
            break;
          case 'lastyear':
            from = DateTime(now.year - 1, 1, 1);
            to = DateTime(now.year - 1, 12, 31, 23, 59, 59);
            tags.add('Last year');
            break;
          default:
            if (dateKey.startsWith('month:')) {
              final mi = int.parse(dateKey.split(':')[1]);
              int yr = now.year;
              if (mi > now.month) yr--;
              from = DateTime(yr, mi, 1);
              to = DateTime(yr, mi + 1, 1).subtract(const Duration(seconds: 1));
              const mn = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
              tags.add(mn[mi - 1]);
            }
        }
      }
    }

    // ── 3. Transaction type ────────────────────────────────────────────────────
    if (_expenseWords.any((w) => q.contains(w))) {
      txType = TransactionType.expense;
      tags.add('Expenses');
      for (final w in _expenseWords) residual = residual.replaceAll(w, '');
    } else if (_incomeWords.any((w) => q.contains(w))) {
      txType = TransactionType.income;
      tags.add('Income');
      for (final w in _incomeWords) residual = residual.replaceAll(w, '');
    } else if (_transferWords.any((w) => q.contains(w))) {
      txType = TransactionType.transfer;
      tags.add('Transfers');
      for (final w in _transferWords) residual = residual.replaceAll(w, '');
    }

    // ── 4. Amount range ────────────────────────────────────────────────────────
    // Handles: "above 500", "more than 1k", "zyada 500", "500 se upar",
    //          "below 200", "kam 200", "200 se kam", "between 100 and 500"
    final aboveRx = RegExp(
      r'(?:above|more than|greater than|over|>\s*|zyada\s+than?|'
      r'(?:(?:₹|rs\.?\s*)?\d[\d,]*\s*(?:k|lakh|l|cr)?\s+se\s+(?:zyada|upar|adhik)))',
      caseSensitive: false,
    );
    final aboveNumRx = RegExp(
      r'(?:above|more than|greater than|over|zyada|upar|>\s*)[\s]*(?:₹|rs\.?\s*)?(\d[\d,]*)[\s]*(k|lakh|l|cr|hazaar|hazar)?',
      caseSensitive: false,
    );
    final seUparRx = RegExp(
      r'(?:₹|rs\.?\s*)?(\d[\d,]*)[\s]*(k|lakh|l|cr|hazaar|hazar)?[\s]+se[\s]+(?:zyada|upar|adhik|bada)',
      caseSensitive: false,
    );
    final belowNumRx = RegExp(
      r'(?:below|less than|under|kam|neeche|<\s*)[\s]*(?:₹|rs\.?\s*)?(\d[\d,]*)[\s]*(k|lakh|l|cr|hazaar|hazar)?',
      caseSensitive: false,
    );
    final seKamRx = RegExp(
      r'(?:₹|rs\.?\s*)?(\d[\d,]*)[\s]*(k|lakh|l|cr|hazaar|hazar)?[\s]+se[\s]+(?:kam|neeche|chota)',
      caseSensitive: false,
    );
    final betweenRx = RegExp(
      r'between[\s]+(?:₹|rs\.?\s*)?(\d[\d,]*)[\s]+and[\s]+(?:₹|rs\.?\s*)?(\d[\d,]*)',
      caseSensitive: false,
    );
    final seSeRx = RegExp(
      r'(?:₹|rs\.?\s*)?(\d[\d,]*)[\s]+se[\s]+(?:₹|rs\.?\s*)?(\d[\d,]*)[\s]+(?:ke beech|beech mein)',
      caseSensitive: false,
    );

    var amountMatched = false;
    final am = aboveNumRx.firstMatch(q);
    final seUpar = seUparRx.firstMatch(q);
    final bm = belowNumRx.firstMatch(q);
    final seKam = seKamRx.firstMatch(q);
    final btm = betweenRx.firstMatch(q);
    final btmHindi = seSeRx.firstMatch(q);

    if (seUpar != null) {
      minAmt = _parseAmt(seUpar.group(1)!, seUpar.group(2));
      tags.add('>₹${_short(minAmt)}');
      residual = residual.replaceAll(seUpar.group(0)!, '');
      amountMatched = true;
    } else if (am != null) {
      minAmt = _parseAmt(am.group(1)!, am.group(2));
      tags.add('>₹${_short(minAmt)}');
      residual = residual.replaceAll(am.group(0)!, '');
      amountMatched = true;
    }
    if (seKam != null) {
      maxAmt = _parseAmt(seKam.group(1)!, seKam.group(2));
      tags.add('<₹${_short(maxAmt)}');
      residual = residual.replaceAll(seKam.group(0)!, '');
      amountMatched = true;
    } else if (bm != null && !amountMatched) {
      maxAmt = _parseAmt(bm.group(1)!, bm.group(2));
      tags.add('<₹${_short(maxAmt)}');
      residual = residual.replaceAll(bm.group(0)!, '');
    }
    if (btmHindi != null) {
      minAmt = _parseAmt(btmHindi.group(1)!, null);
      maxAmt = _parseAmt(btmHindi.group(2)!, null);
      tags.add('₹${_short(minAmt!)}–₹${_short(maxAmt!)}');
      residual = residual.replaceAll(btmHindi.group(0)!, '');
    } else if (btm != null && minAmt == null && maxAmt == null) {
      minAmt = _parseAmt(btm.group(1)!, null);
      maxAmt = _parseAmt(btm.group(2)!, null);
      tags.add('₹${_short(minAmt!)}–₹${_short(maxAmt!)}');
      residual = residual.replaceAll(btm.group(0)!, '');
    }

    // ── 5. Category hints ─────────────────────────────────────────────────────
    for (final entry in _catMap.entries) {
      for (final kw in entry.value) {
        if (q.contains(kw)) {
          if (!catHints.contains(entry.key)) {
            catHints.add(entry.key);
            tags.add(entry.key);
          }
          residual = residual.replaceAll(kw, '');
          break;
        }
      }
    }

    // ── 5. Clean up residual — strip noise words ───────────────────────────────
    residual = residual
        .replaceAll(RegExp(
            r'\b(?:show|me|all|my|the|in|for|on|of|from|to|with|a|an|'
            r'transactions?|entries?|records?|history|list|find|search|get|'
            r'dikhao|dikha|batao|bata)\b'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // If residual has a number that wasn't caught as amount range, strip it too
    if (minAmt == null && maxAmt == null) {
      // Don't strip — might be useful as keyword match
    } else {
      residual = residual
          .replaceAll(RegExp(r'\b\d[\d,]*(?:\.\d+)?\s*(?:k|l|lakh|cr)?\b'), '')
          .trim();
    }

    // ── Return ─────────────────────────────────────────────────────────────────
    if (tags.isEmpty && residual.isEmpty) return null;
    // If the only "signal" is the residual keyword → treat as plain search
    if (tags.isEmpty && residual == q.trim()) return null;

    return _ParsedQuery(
      displaySummary: tags.isEmpty ? 'Filtered' : tags.join(' · '),
      keyword: residual.isEmpty ? null : residual,
      fromDate: from,
      toDate: to,
      type: txType,
      minAmount: minAmt,
      maxAmount: maxAmt,
      categoryHints: catHints,
    );
  }

  static double _parseAmt(String digits, String? suffix) {
    double v = double.tryParse(digits.replaceAll(',', '')) ?? 0;
    final s = suffix?.toLowerCase() ?? '';
    if (s == 'k') v *= 1000;
    if (s == 'l' || s == 'lakh') v *= 100000;
    if (s == 'cr') v *= 10000000;
    return v;
  }

  static String _short(double v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Entry point ───────────────────────────────────────────────────────────────

/// Opens the global search overlay.
Future<void> showGlobalSearch(BuildContext context) async {
  // Lock orientation for the duration of the search overlay so keyboard
  // appearance and rotation events don't collapse or scramble the layout.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Search',
    barrierColor: Colors.black.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _GlobalSearchPage(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
          parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, -0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
  // Restore all orientations once the overlay is gone.
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
}

class _GlobalSearchPage extends StatefulWidget {
  const _GlobalSearchPage();

  @override
  State<_GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<_GlobalSearchPage>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<_SearchResult> _results = [];
  List<String> _recentSearches = [];
  bool _searching = false;
  String _query = '';
  _ParsedQuery? _parsedQuery;
  // ML Kit enhancement state
  bool _mlkitActive = false;
  String? _mlkitQueryTag;

  // Voice
  final _stt = SpeechToText();
  bool _sttReady = false;
  bool _isListening = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadRecentSearches();
    _initStt();
    // Warm up ML Kit entity extractor in the background — doesn't block UI
    NLSearchEngine.instance.warmUp();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize(onError: (_) {
      if (mounted) setState(() => _isListening = false);
    });
    if (mounted) setState(() => _sttReady = ok);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pulseCtrl.dispose();
    _controller.dispose();
    _focus.dispose();
    _stt.stop();
    super.dispose();
  }

  // ── Voice ────────────────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    HapticFeedback.lightImpact();
    if (_isListening) {
      await _stt.stop();
      setState(() => _isListening = false);
      return;
    }
    if (!_sttReady) {
      final ok = await _stt.initialize();
      if (!ok || !mounted) return;
      setState(() => _sttReady = ok);
    }
    setState(() => _isListening = true);
    await _stt.listen(
      onResult: (result) {
        if (!mounted) return;
        final text = result.recognizedWords;
        _controller.text = text;
        _onQueryChanged(text);
        if (result.finalResult) {
          setState(() => _isListening = false);
        }
      },
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(milliseconds: 2500),
      cancelOnError: true,
      partialResults: true,
      localeId: 'en_IN',
    );
  }

  // ── Recent searches ───────────────────────────────────────────────────────

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kRecentSearchesKey) ?? [];
    if (mounted) setState(() => _recentSearches = raw);
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = [
      query,
      ..._recentSearches.where((r) => r != query),
    ].take(_kMaxRecentSearches).toList();
    await prefs.setStringList(_kRecentSearchesKey, updated);
    if (mounted) setState(() => _recentSearches = updated);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearchesKey);
    if (mounted) setState(() => _recentSearches = []);
  }

  // ── Search logic ──────────────────────────────────────────────────────────

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
        _parsedQuery = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(value));
  }

  void _runSearch(String q) {
    if (!mounted) return;
    final raw = q.toLowerCase().trim();
    final results = <_SearchResult>[];

    // Pass 1 — rule-based NL parse (synchronous, immediate)
    final parsed = _NLQueryParser.parse(raw);

    // Pass 2 — ML Kit entity enhancement (async, fires in background)
    // If ML Kit extracts dates/amounts the regex missed, re-runs the search.
    _mlkitEnhance(q, raw, parsed);

    final txCtrl = context.read<TransactionsController>();
    final accCtrl = context.read<AccountsController>();
    final invCtrl = context.read<InvestmentsController>();
    final goalCtrl = context.read<GoalsController>();
    final budgetCtrl = context.read<BudgetsController>();
    final contactCtrl = context.read<ContactsController>();

    // ── Transactions ──────────────────────────────────────────────────────────
    for (final tx in txCtrl.transactions) {
      if (results.where((r) => r.type == _ResultType.transaction).length >= 20) break;

      if (parsed != null) {
        // NL filter mode
        if (!_matchesParsed(tx, parsed, raw)) continue;
      } else {
        // Plain keyword mode
        final desc = tx.description.toLowerCase();
        final amt = tx.amount.toString();
        final cat = (tx.metadata?['categoryName'] as String? ?? '').toLowerCase();
        final merchant = (tx.metadata?['merchant'] as String? ?? '').toLowerCase();
        final tags = (tx.metadata?['tags'] as List? ?? [])
            .map((t) => t.toString().toLowerCase())
            .join(' ');
        final accName = (tx.sourceAccountName ?? '').toLowerCase();
        if (!desc.contains(raw) &&
            !amt.contains(raw) &&
            !cat.contains(raw) &&
            !merchant.contains(raw) &&
            !tags.contains(raw) &&
            !accName.contains(raw)) continue;
      }

      final isIncome = tx.type == TransactionType.income ||
          tx.type == TransactionType.cashback;
      final merchant = (tx.metadata?['merchant'] as String? ?? '').trim();
      final cat = (tx.metadata?['categoryName'] as String? ?? '').trim();
      final capturedTx = tx;
      results.add(_SearchResult(
        type: _ResultType.transaction,
        id: tx.id,
        title: merchant.isNotEmpty ? merchant : tx.description,
        subtitle: [
          if (cat.isNotEmpty) cat,
          _fmtDate(tx.dateTime),
          if ((tx.sourceAccountName ?? '').isNotEmpty) tx.sourceAccountName!,
        ].join(' · '),
        amount: tx.amount,
        icon: isIncome
            ? CupertinoIcons.arrow_down_circle_fill
            : CupertinoIcons.arrow_up_circle_fill,
        color: isIncome ? AppStyles.gain(context) : AppStyles.loss(context),
        onNavigate: () => _showTransactionDetail(context, capturedTx),
      ));
    }

    // In NL mode, skip other result types (user asked about transactions only)
    if (parsed == null) {
      // ── Accounts ────────────────────────────────────────────────────────────
      for (final acc in accCtrl.accounts) {
        if (results.where((r) => r.type == _ResultType.account).length >= 5) break;
        final typeLabel = _accountTypeLabel(acc.type.name);
        if (!acc.name.toLowerCase().contains(raw) &&
            !acc.bankName.toLowerCase().contains(raw) &&
            !typeLabel.toLowerCase().contains(raw)) continue;
        final capturedAcc = acc;
        results.add(_SearchResult(
          type: _ResultType.account,
          id: acc.id,
          title: acc.name,
          subtitle: '${acc.bankName} · $typeLabel',
          amount: acc.balance,
          icon: CupertinoIcons.creditcard_fill,
          color: AppStyles.teal(context),
          onNavigate: () => showCupertinoModalPopup<void>(
            context: context,
            builder: (_) => AccountWizard(existingAccount: capturedAcc),
          ),
        ));
      }

      // ── Investments ──────────────────────────────────────────────────────────
      for (final inv in invCtrl.investments) {
        if (results.where((r) => r.type == _ResultType.investment).length >= 5) break;
        if (!inv.name.toLowerCase().contains(raw) &&
            !(inv.broker ?? '').toLowerCase().contains(raw) &&
            !inv.getTypeLabel().toLowerCase().contains(raw)) continue;
        results.add(_SearchResult(
          type: _ResultType.investment,
          id: inv.id,
          title: inv.name,
          subtitle: '${inv.getTypeLabel()}${inv.broker != null ? " · ${inv.broker}" : ""}',
          amount: inv.amount,
          icon: CupertinoIcons.chart_bar_square_fill,
          color: AppStyles.violet(context),
          onNavigate: () => Navigator.of(context, rootNavigator: true).push(
            FadeScalePageRoute(page: const InvestmentsScreen()),
          ),
        ));
      }

      // ── Goals ────────────────────────────────────────────────────────────────
      for (final goal in goalCtrl.goals) {
        if (results.where((r) => r.type == _ResultType.goal).length >= 5) break;
        if (!goal.name.toLowerCase().contains(raw)) continue;
        final capturedId = goal.id;
        results.add(_SearchResult(
          type: _ResultType.goal,
          id: goal.id,
          title: goal.name,
          subtitle: 'Goal · ${_fmt(goal.currentAmount)} / ${_fmt(goal.targetAmount)}',
          amount: goal.targetAmount,
          icon: CupertinoIcons.flag_fill,
          color: AppStyles.gold(context),
          onNavigate: () => Navigator.of(context, rootNavigator: true).push(
            FadeScalePageRoute(page: GoalDetailsScreen(goalId: capturedId)),
          ),
        ));
      }

      // ── Budgets ──────────────────────────────────────────────────────────────
      for (final budget in budgetCtrl.budgets) {
        if (results.where((r) => r.type == _ResultType.budget).length >= 5) break;
        if (!budget.name.toLowerCase().contains(raw) &&
            !(budget.categoryName ?? '').toLowerCase().contains(raw)) continue;
        final capturedId = budget.id;
        results.add(_SearchResult(
          type: _ResultType.budget,
          id: budget.id,
          title: budget.name,
          subtitle: 'Budget · ${_fmt(budget.spentAmount)} / ${_fmt(budget.limitAmount)}',
          amount: budget.limitAmount,
          icon: CupertinoIcons.chart_pie_fill,
          color: AppStyles.info(context),
          onNavigate: () => Navigator.of(context, rootNavigator: true).push(
            FadeScalePageRoute(page: BudgetDetailsScreen(budgetId: capturedId)),
          ),
        ));
      }

      // ── Contacts ─────────────────────────────────────────────────────────────
      for (final contact in contactCtrl.contacts) {
        if (results.where((r) => r.type == _ResultType.contact).length >= 5) break;
        if (!contact.name.toLowerCase().contains(raw) &&
            !(contact.phoneNumber ?? '').contains(raw)) continue;
        results.add(_SearchResult(
          type: _ResultType.contact,
          id: contact.id,
          title: contact.name,
          subtitle: contact.phoneNumber ?? 'Contact',
          icon: CupertinoIcons.person_circle_fill,
          color: AppStyles.info(context),
          onNavigate: () => Navigator.of(context, rootNavigator: true).push(
            FadeScalePageRoute(page: const ContactsScreen()),
          ),
        ));
      }
    }

    // ── Actions ───────────────────────────────────────────────────────────────
    final settingsCtrl = context.read<SettingsController>();
    results.insertAll(0, _buildActionResults(context, raw, settingsCtrl));

    if (mounted) {
      setState(() {
        _results = results;
        _parsedQuery = parsed;
        _searching = false;
        _mlkitActive = false;
        _mlkitQueryTag = null;
      });
    }
  }

  /// ML Kit pass — runs after the synchronous rule-based search.
  /// If ML Kit extracts date/amount entities the regex missed, we re-run
  /// the transaction filter and update the result list.
  Future<void> _mlkitEnhance(
    String originalQuery,
    String raw,
    _ParsedQuery? ruleBasedParsed,
  ) async {
    if (!mounted) return;
    setState(() => _mlkitActive = true);

    final hints = await NLSearchEngine.instance.extractHints(originalQuery);

    // Bail if query changed while ML Kit was running
    if (!mounted || _query != originalQuery) return;

    // ML Kit found a date the regex didn't catch
    final mlkitFromDate = hints.fromDate;
    final mlkitToDate = hints.toDate;
    final mlkitAmt = hints.amountMin;

    final bool addsDate = mlkitFromDate != null &&
        ruleBasedParsed?.fromDate == null;
    final bool addsAmt = mlkitAmt != null &&
        ruleBasedParsed?.minAmount == null;

    if (!addsDate && !addsAmt) {
      if (mounted) setState(() => _mlkitActive = false);
      return;
    }

    // Build an enhanced parsed query merging both passes
    final base = ruleBasedParsed;
    final enhanced = _ParsedQuery(
      displaySummary: [
        if (base?.displaySummary != null && base!.displaySummary.isNotEmpty)
          base.displaySummary,
        if (addsDate) 'AI date',
        if (addsAmt) 'AI amount',
      ].join(' · '),
      keyword: base?.keyword,
      fromDate: addsDate ? mlkitFromDate : base?.fromDate,
      toDate: addsDate ? mlkitToDate : base?.toDate,
      type: base?.type,
      minAmount: addsAmt ? mlkitAmt : base?.minAmount,
      maxAmount: base?.maxAmount,
      categoryHints: base?.categoryHints ?? const [],
    );

    // Re-filter transactions with the enhanced query
    final txCtrl = context.read<TransactionsController>();
    final enhancedResults = <_SearchResult>[];
    for (final tx in txCtrl.transactions) {
      if (enhancedResults.length >= 20) break;
      if (!_matchesParsed(tx, enhanced, raw)) continue;
      final isIncome = tx.type == TransactionType.income ||
          tx.type == TransactionType.cashback;
      final merchant = (tx.metadata?['merchant'] as String? ?? '').trim();
      final cat = (tx.metadata?['categoryName'] as String? ?? '').trim();
      final capturedTx = tx;
      enhancedResults.add(_SearchResult(
        type: _ResultType.transaction,
        id: tx.id,
        title: merchant.isNotEmpty ? merchant : tx.description,
        subtitle: [
          if (cat.isNotEmpty) cat,
          _fmtDate(tx.dateTime),
          if ((tx.sourceAccountName ?? '').isNotEmpty) tx.sourceAccountName!,
        ].join(' · '),
        amount: tx.amount,
        icon: isIncome
            ? CupertinoIcons.arrow_down_circle_fill
            : CupertinoIcons.arrow_up_circle_fill,
        color: isIncome ? AppStyles.gain(context) : AppStyles.loss(context),
        onNavigate: () => _showTransactionDetail(context, capturedTx),
      ));
    }

    if (mounted) {
      setState(() {
        _results = enhancedResults;
        _parsedQuery = enhanced;
        _mlkitActive = false;
        _mlkitQueryTag = addsDate
            ? 'AI: date extracted'
            : addsAmt
                ? 'AI: amount extracted'
                : null;
      });
    }
  }

  List<_SearchResult> _buildActionResults(
      BuildContext context, String raw, SettingsController settingsCtrl) {
    final actions = <_SearchResult>[];

    void action(String id, String title, String subtitle, IconData icon,
        Color color, List<String> keywords, VoidCallback onTap) {
      if (!keywords.any((k) => raw.contains(k))) return;
      actions.add(_SearchResult(
        type: _ResultType.action,
        id: id,
        title: title,
        subtitle: subtitle,
        icon: icon,
        color: color,
        onNavigate: onTap,
      ));
    }

    final isDark = settingsCtrl.themeMode == ThemeMode.dark;
    // ── Navigation ─────────────────────────────────────────────────────────────
    action('nav_investments', 'Open Investments', 'Stocks, MF, FD, Crypto…',
        CupertinoIcons.chart_bar_square_fill, const Color(0xFF6C63FF),
        ['invest', 'stock', 'portfolio', 'mutual fund', 'sip', 'fd', 'mf', 'crypto', 'gold', 'nps'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const InvestmentsScreen())));

    action('nav_goals', 'Open Goals', 'Your savings targets',
        CupertinoIcons.flag_fill, const Color(0xFFFFB300),
        ['goal', 'goals', 'saving for', 'target', 'dreams'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const GoalsScreen())));

    action('nav_budgets', 'Open Budgets', 'Monthly spending limits',
        CupertinoIcons.chart_pie_fill, const Color(0xFF26A69A),
        ['budget', 'budgets', 'limit', 'spending limit'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const BudgetsScreen())));

    action('nav_accounts', 'Open Accounts', 'Bank accounts & wallets',
        CupertinoIcons.creditcard_fill, AppStyles.teal(context),
        ['account', 'accounts', 'bank', 'wallet', 'my accounts', 'cards'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const AccountsScreen())));

    action('nav_history', 'Transaction History', 'All your transactions',
        CupertinoIcons.doc_text, AppStyles.teal(context),
        ['history', 'all transactions', 'transaction history', 'transactions list'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const TransactionHistoryScreen())));

    action('nav_networth', 'Net Worth', 'Total assets & liabilities',
        CupertinoIcons.sum, const Color(0xFF4CAF50),
        ['net worth', 'networth', 'wealth', 'total wealth', 'assets'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const NetWorthPage())));

    action('nav_insights', 'Spending Insights', 'Analytics & patterns',
        CupertinoIcons.sparkles, const Color(0xFF6C63FF),
        ['insight', 'insights', 'analysis', 'analytics', 'spending pattern', 'report', 'reports'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const SpendingInsightsScreen())));

    action('nav_calendar', 'Financial Calendar', 'Upcoming payments & events',
        CupertinoIcons.calendar, const Color(0xFF42A5F5),
        ['calendar', 'schedule', 'upcoming', 'planned', 'recurring'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const FinancialCalendarScreen())));

    action('nav_lending', 'Lending & Borrowing', 'Track money given or taken',
        CupertinoIcons.arrow_right_arrow_left_circle_fill, const Color(0xFFFF7043),
        ['lend', 'lending', 'borrow', 'loan', 'borrowed', 'owed', 'due'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const LendingBorrowingScreen())));

    action('nav_archive', 'Transaction Archive', 'Deleted & archived entries',
        CupertinoIcons.archivebox_fill, AppStyles.getSecondaryTextColor(context),
        ['archive', 'archived', 'deleted', 'old transaction', 'trash'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const TransactionsArchiveScreen())));

    action('nav_settings', 'Open Settings', 'Preferences & configuration',
        CupertinoIcons.settings_solid, AppStyles.getSecondaryTextColor(context),
        ['setting', 'settings', 'preferences', 'configure', 'configuration'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const SettingsScreen())));

    // ── Settings actions ───────────────────────────────────────────────────────
    action('act_theme', isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
        isDark ? 'Turn off AMOLED dark mode' : 'Turn on AMOLED dark mode',
        isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
        const Color(0xFF6C63FF),
        ['dark mode', 'light mode', 'theme', 'change theme', 'dark', 'night mode', 'amoled'],
        () => settingsCtrl.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark));

    action('act_backup', 'Backup & Restore', 'Export or import your data',
        CupertinoIcons.arrow_clockwise_circle_fill, const Color(0xFF26A69A),
        ['backup', 'restore', 'export data', 'import data', 'sync', 'save data'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const BackupRestoreScreen())));

    action('act_csv', 'Import CSV Statement', 'Import from bank CSV/Excel',
        CupertinoIcons.doc_text_fill, const Color(0xFF42A5F5),
        ['import csv', 'csv', 'excel', 'import statement', 'bank csv', 'upload statement'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const CsvImportScreen())));

    action('act_categories', 'Manage Categories', 'Add or edit categories',
        CupertinoIcons.tag_fill, const Color(0xFFFF9800),
        ['categor', 'categories', 'category', 'manage categories', 'tags'],
        () => Navigator.of(context, rootNavigator: true)
            .push(FadeScalePageRoute(page: const CategoriesScreen())));

    return actions;
  }

  bool _matchesParsed(Transaction tx, _ParsedQuery parsed, String rawQuery) {
    // Date range
    if (parsed.fromDate != null && tx.dateTime.isBefore(parsed.fromDate!)) return false;
    if (parsed.toDate != null && tx.dateTime.isAfter(parsed.toDate!)) return false;

    // Type
    if (parsed.type != null && tx.type != parsed.type) return false;

    // Amount
    if (parsed.minAmount != null && tx.amount < parsed.minAmount!) return false;
    if (parsed.maxAmount != null && tx.amount > parsed.maxAmount!) return false;

    // Category hints
    if (parsed.categoryHints.isNotEmpty) {
      final cat = (tx.metadata?['categoryName'] as String? ?? '').toLowerCase();
      final desc = tx.description.toLowerCase();
      final merchant = (tx.metadata?['merchant'] as String? ?? '').toLowerCase();
      // Normalise stored category name for fuzzy compare (& → and, etc.)
      final normCat = _NLQueryParser._normaliseSynonyms(cat);
      final normDesc = _NLQueryParser._normaliseSynonyms(desc);
      final normMerchant = _NLQueryParser._normaliseSynonyms(merchant);
      final matched = parsed.categoryHints.any((hint) {
        final hintNorm = _NLQueryParser._normaliseSynonyms(hint.toLowerCase());
        if (normCat.contains(hintNorm) || normDesc.contains(hintNorm) ||
            normMerchant.contains(hintNorm)) {
          return true;
        }
        // Check against the category's keyword list
        final kws = _NLQueryParser._catMap[hint] ?? [];
        return kws.any((kw) => normDesc.contains(kw) || normMerchant.contains(kw) || normCat.contains(kw));
      });
      if (!matched) return false;
    }

    // Residual keyword
    if (parsed.keyword != null && parsed.keyword!.isNotEmpty) {
      final kw = parsed.keyword!.toLowerCase();
      final desc = tx.description.toLowerCase();
      final merchant = (tx.metadata?['merchant'] as String? ?? '').toLowerCase();
      final cat = (tx.metadata?['categoryName'] as String? ?? '').toLowerCase();
      if (!desc.contains(kw) && !merchant.contains(kw) && !cat.contains(kw)) return false;
    }

    return true;
  }

  void _onResultTap(_SearchResult result) {
    _saveRecentSearch(_query);
    final nav = result.onNavigate;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => nav());
  }

  void _submitSearch(String q) {
    if (q.trim().length >= 2) _saveRecentSearch(q.trim());
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Container(
              margin: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md,
                  Spacing.md, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(Radii.xl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.search,
                      size: 18,
                      color: AppStyles.getSecondaryTextColor(context)),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _controller,
                      focusNode: _focus,
                      placeholder: 'Search, navigate, or ask naturally…',
                      placeholderStyle: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.callout,
                      ),
                      style: TextStyle(
                        color: AppStyles.getTextColor(context),
                        fontSize: TypeScale.callout,
                      ),
                      decoration: null,
                      onChanged: _onQueryChanged,
                      onSubmitted: _submitSearch,
                      autocorrect: false,
                      clearButtonMode: OverlayVisibilityMode.editing,
                    ),
                  ),
                  // Mic button
                  if (_sttReady || !_isListening) ...[
                    GestureDetector(
                      onTap: _toggleVoice,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Icon(
                            _isListening
                                ? CupertinoIcons.mic_fill
                                : CupertinoIcons.mic,
                            size: 18,
                            color: _isListening
                                ? const Color(0xFF6C63FF)
                                    .withValues(alpha: _pulseAnim.value)
                                : AppStyles.getSecondaryTextColor(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppStyles.getPrimaryColor(context),
                        fontSize: TypeScale.callout,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            // Listening banner
            if (_isListening) _buildListeningBanner(context),
            const SizedBox(height: Spacing.sm),
            // Results area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: Spacing.md),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                  borderRadius: BorderRadius.circular(Radii.xl),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.xl),
                  child: _buildBody(context),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningBanner(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(Spacing.md, Spacing.xs, Spacing.md, 0),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.12 * _pulseAnim.value + 0.06),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.mic_fill,
                size: 14,
                color: const Color(0xFF6C63FF).withValues(alpha: _pulseAnim.value)),
            const SizedBox(width: 6),
            Text(
              'Listening… speak your query',
              style: TextStyle(
                fontSize: TypeScale.caption,
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_searching) {
      return Center(
        child: CupertinoActivityIndicator(
          color: AppStyles.getPrimaryColor(context),
        ),
      );
    }

    if (_query.length >= 2 && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.search,
                size: 36,
                color: AppStyles.getSecondaryTextColor(context)),
            const SizedBox(height: Spacing.sm),
            Text(
              'No results for "$_query"',
              style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.callout,
              ),
            ),
            if (_parsedQuery != null) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                'Searched: ${_parsedQuery!.displaySummary}',
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.6),
                  fontSize: TypeScale.caption,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_query.length >= 2 && _results.isNotEmpty) {
      return _buildResults(context);
    }

    return _buildRecentSearches(context);
  }

  Widget _buildResults(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final byType = <_ResultType, List<_SearchResult>>{};
    for (final r in _results) {
      byType.putIfAbsent(r.type, () => []).add(r);
    }

    const typeLabels = {
      _ResultType.action: 'QUICK ACTIONS',
      _ResultType.transaction: 'TRANSACTIONS',
      _ResultType.account: 'ACCOUNTS',
      _ResultType.investment: 'INVESTMENTS',
      _ResultType.goal: 'GOALS',
      _ResultType.budget: 'BUDGETS',
      _ResultType.contact: 'CONTACTS',
    };

    final tiles = <Widget>[];

    // AI interpretation chip
    if (_parsedQuery != null) {
      final txCount = byType[_ResultType.transaction]?.length ?? 0;
      tiles.add(
        Container(
          margin: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, Spacing.xs),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withValues(alpha: isDark ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.sparkles,
                  size: 13, color: Color(0xFF6C63FF)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_parsedQuery!.displaySummary}  ·  $txCount result${txCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_mlkitActive)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFF6C63FF),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    for (final type in _ResultType.values) {
      final group = byType[type];
      if (group == null || group.isEmpty) continue;
      // Skip section header for transactions when NL mode (chip already explains)
      if (type != _ResultType.transaction || _parsedQuery == null) {
        tiles.add(Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md,
              Spacing.md, Spacing.xs),
          child: Text(typeLabels[type]!,
              style: TextStyle(
                  fontSize: TypeScale.caption,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppStyles.getSecondaryTextColor(context))),
        ));
      }
      for (final result in group) {
        tiles.add(_ResultTile(
          result: result,
          onTap: () => _onResultTap(result),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      children: tiles,
    );
  }

  Widget _buildRecentSearches(BuildContext context) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.search,
                  size: 36,
                  color: AppStyles.getSecondaryTextColor(context)
                      .withValues(alpha: 0.4)),
              const SizedBox(height: Spacing.md),
              Text(
                'Search or ask naturally',
                style: TextStyle(
                  color: AppStyles.getTextColor(context),
                  fontSize: TypeScale.callout,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                '"food expenses last month"\n"open investments" · "dark mode"\n"Swiggy this week" · "backup"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.footnote,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(Spacing.sm),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm, vertical: Spacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT SEARCHES',
                  style: TextStyle(
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppStyles.getSecondaryTextColor(context))),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _clearRecentSearches,
                child: Text('Clear',
                    style: TextStyle(
                        fontSize: TypeScale.caption,
                        color: AppStyles.getPrimaryColor(context))),
              ),
            ],
          ),
        ),
        ..._recentSearches.map((q) => _RecentSearchTile(
              query: q,
              onTap: () {
                _controller.text = q;
                _onQueryChanged(q);
              },
              onDelete: () {
                setState(() => _recentSearches.remove(q));
                SharedPreferences.getInstance().then((prefs) =>
                    prefs.setStringList(
                        _kRecentSearchesKey, _recentSearches));
              },
            )),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  String _accountTypeLabel(String typeName) {
    switch (typeName) {
      case 'savings': return 'Savings';
      case 'current': return 'Current';
      case 'credit': return 'Credit Card';
      case 'payLater': return 'Pay Later';
      case 'wallet': return 'Wallet';
      case 'cash': return 'Cash';
      case 'investment': return 'Investment';
      default: return typeName;
    }
  }

  // ── Transaction detail sheet (read-only) ─────────────────────────────────

  void _showTransactionDetail(BuildContext context, Transaction tx) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: AppStyles.isDarkMode(context)
                  ? const Color(0xFF0D0D0D)
                  : CupertinoColors.systemBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              controller: scrollCtrl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppStyles.getDividerColor(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  TransactionDetailsContent(transaction: tx),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Result tile ───────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  final VoidCallback onTap;

  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: result.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                alignment: Alignment.center,
                child: Icon(result.icon, size: 16, color: result.color),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: TypeScale.callout,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.getTextColor(context))),
                    Text(result.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: TypeScale.caption,
                            color: AppStyles.getSecondaryTextColor(context))),
                  ],
                ),
              ),
              if (result.amount != null) ...[
                const SizedBox(width: Spacing.sm),
                Text(
                  _fmt(result.amount!),
                  style: TextStyle(
                      fontSize: TypeScale.footnote,
                      fontWeight: FontWeight.w700,
                      color: result.type == _ResultType.transaction
                          ? result.color
                          : AppStyles.getTextColor(context)),
                ),
              ],
              const SizedBox(width: Spacing.xs),
              Icon(
                CupertinoIcons.chevron_right,
                size: 12,
                color: AppStyles.getSecondaryTextColor(context)
                    .withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

// ── Recent search tile ────────────────────────────────────────────────────────

class _RecentSearchTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentSearchTile({
    required this.query,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm),
          child: Row(
            children: [
              Icon(CupertinoIcons.clock,
                  size: 16,
                  color: AppStyles.getSecondaryTextColor(context)),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(query,
                    style: TextStyle(
                        fontSize: TypeScale.callout,
                        color: AppStyles.getTextColor(context))),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onDelete,
                child: Icon(CupertinoIcons.xmark,
                    size: 14,
                    color: AppStyles.getSecondaryTextColor(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
