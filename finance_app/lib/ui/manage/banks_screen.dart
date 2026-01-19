import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class BanksScreen extends StatefulWidget {
  const BanksScreen({super.key});

  @override
  State<BanksScreen> createState() => _BanksScreenState();
}

class _BanksScreenState extends State<BanksScreen> {
  final AppLogger logger = AppLogger();
  String _searchQuery = '';
  bool _isAscending = true;
  
  late List<Map<String, dynamic>> _banks;

  @override
  void initState() {
    super.initState();
    _banks = _generateBankList();
  }

  List<Map<String, dynamic>> _generateBankList() {
    final banks = [
      {'name': 'State Bank of India (SBI)', 'color': const Color(0xFF007DCC)}, 
      {'name': 'HDFC Bank', 'color': const Color(0xFF004C8F)}, 
      {'name': 'ICICI Bank', 'color': const Color(0xFFF37E20)}, 
      {'name': 'Axis Bank', 'color': const Color(0xFF97144D)}, 
      {'name': 'Kotak Mahindra Bank', 'color': const Color(0xFFED1C24)}, 
      {'name': 'Punjab National Bank (PNB)', 'color': const Color(0xFFA20A3E)},
      {'name': 'Bank of Baroda', 'color': const Color(0xFFF26522)},
      {'name': 'Canara Bank', 'color': const Color(0xFFF37021)},
      {'name': 'Union Bank of India', 'color': const Color(0xFFE21F25)},
      {'name': 'IndusInd Bank', 'color': const Color(0xFF981C26)},
      {'name': 'IDBI Bank', 'color': const Color(0xFF007548)},
      {'name': 'Yes Bank', 'color': const Color(0xFF00539B)},
      {'name': 'IDFC First Bank', 'color': const Color(0xFF9D1D27)},
      {'name': 'Federal Bank', 'color': const Color(0xFFE87722)},
      {'name': 'Indian Bank', 'color': const Color(0xFF005494)},
      {'name': 'Bank of India', 'color': const Color(0xFFF68D2E)},
      {'name': 'Central Bank of India', 'color': const Color(0xFF005B98)},
      {'name': 'UCO Bank', 'color': const Color(0xFF005B9F)},
      {'name': 'Bank of Maharashtra', 'color': const Color(0xFFED1C24)},
      {'name': 'Paytm Payments Bank', 'color': const Color(0xFF002E6E)},
      {'name': 'Airtel Payments Bank', 'color': const Color(0xFFED1C24)},
      {'name': 'Google Pay', 'color': const Color(0xFF4285F4)},
      {'name': 'Amazon Pay', 'color': const Color(0xFFF4B400)},
      {'name': 'PhonePe', 'color': const Color(0xFF5F259F)},
      {'name': 'Cred', 'color': const Color(0xFF000000)},
    ];

    banks.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return banks.map((bank) {
      return {
        'id': (bank['name'] as String).replaceAll(' ', '_').toLowerCase(),
        'name': bank['name'],
        'color': bank['color'],
        'isEnabled': false, 
        'senderIds': <String>[],
      };
    }).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _banks.removeAt(oldIndex);
      _banks.insert(newIndex, item);
    });
  }

  void _toggleBank(int index, bool value) {
    setState(() {
      _banks[index]['isEnabled'] = value;
    });
  }

  void _deleteBank(int index) {
    setState(() {
      _banks.removeAt(index);
    });
  }

  void _sortBanks() {
    setState(() {
      _isAscending = !_isAscending;
      _banks.sort((a, b) {
        return _isAscending
            ? (a['name'] as String).compareTo(b['name'] as String)
            : (b['name'] as String).compareTo(a['name'] as String);
      });
    });
  }

  void _showBankBottomSheet({Map<String, dynamic>? existingBank, int? bankIndex}) {
    final nameController = TextEditingController(text: existingBank?['name'] ?? '');
    final senderIdController = TextEditingController();
    List<String> tempSenderIds = List<String>.from(existingBank?['senderIds'] ?? []);
    final isEditMode = existingBank != null;

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            final isDark = AppStyles.isDarkMode(context);

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Container(
                            width: 36, height: 5,
                            decoration: BoxDecoration(color: CupertinoColors.systemGrey3, borderRadius: BorderRadius.circular(2.5)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isEditMode ? 'Edit Bank' : 'Add Bank',
                          style: AppStyles.titleStyle(context).copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 1,
                          color: isDark ? Colors.grey[800] : CupertinoColors.systemGrey5,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context, 'Bank Name'),
                                const SizedBox(height: 8),
                                CupertinoTextField(
                                  controller: nameController,
                                  enabled: !isEditMode,
                                  placeholder: 'Bank Name',
                                  style: TextStyle(color: AppStyles.getTextColor(context)),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey6,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                const SizedBox(height: 24),
                                _buildLabel(context, 'Sender IDs (${tempSenderIds.length})'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: CupertinoTextField(
                                        controller: senderIdController,
                                        placeholder: 'Enter Sender ID',
                                        style: TextStyle(color: AppStyles.getTextColor(context)),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.systemGrey6,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    CupertinoButton(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      color: CupertinoColors.systemBlue,
                                      child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        if (senderIdController.text.isNotEmpty) {
                                          setDialogState(() {
                                            tempSenderIds.add(senderIdController.text.toUpperCase());
                                            senderIdController.clear();
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8, runSpacing: 8,
                                  children: tempSenderIds.map((id) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemBlue.withValues(alpha:0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: CupertinoColors.systemBlue),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(id, style: const TextStyle(color: CupertinoColors.systemBlue, fontWeight: FontWeight.w500)),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => setDialogState(() => tempSenderIds.remove(id)),
                                          child: const Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: CupertinoColors.systemBlue),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  color: isDark ? Colors.grey[800] : CupertinoColors.systemGrey5,
                                  child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CupertinoButton(
                                  color: CupertinoColors.systemBlue,
                                  child: Text(isEditMode ? 'Update' : 'Add', style: const TextStyle(color: Colors.white)),
                                  onPressed: () {
                                    setState(() {
                                      if (isEditMode) {
                                        _banks[bankIndex!]['senderIds'] = tempSenderIds;
                                      } else {
                                        _banks.add({
                                          'id': nameController.text.replaceAll(' ', '_').toLowerCase(),
                                          'name': nameController.text,
                                          'color': CupertinoColors.systemGrey,
                                          'isEnabled': false,
                                          'senderIds': tempSenderIds,
                                        });
                                      }
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppStyles.isDarkMode(context) ? Colors.grey[400] : CupertinoColors.systemGrey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBanks = _banks.where((bank) {
      return bank['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Banks', style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _sortBanks,
          child: Icon(
            _isAscending ? CupertinoIcons.sort_down : CupertinoIcons.sort_up,
            size: 24,
            color: AppStyles.accentBlue,
          ),
        ),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoSearchTextField(
                    backgroundColor: Colors.transparent,
                    style: TextStyle(color: AppStyles.getTextColor(context)),
                    placeholder: 'Search Banks',
                    placeholderStyle: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: filteredBanks.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final bank = filteredBanks[index];
                      final originalIndex = _banks.indexOf(bank);
                      return _build3DBankCard(bank, originalIndex);
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16, bottom: 32,
            child: FadingFloatingActionButton(onPressed: () => _showBankBottomSheet()),
          ),
        ],
      ),
    );
  }

  Widget _build3DBankCard(Map<String, dynamic> bank, int index) {
    return Container(
      key: ValueKey(bank['id']),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppStyles.cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: AppStyles.iconBoxDecoration(context, bank['color']),
              child: Center(child: Icon(CupertinoIcons.building_2_fill, color: bank['color'], size: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bank['name'], style: AppStyles.titleStyle(context)),
                  if ((bank['senderIds'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${(bank['senderIds'] as List).length} Sender IDs',
                        style: TextStyle(fontSize: 12, color: AppStyles.getSecondaryTextColor(context)),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 0.8,
                  child: CupertinoSwitch(
                    value: bank['isEnabled'],
                    activeColor: CupertinoColors.activeGreen,
                    onChanged: (bool value) => _toggleBank(index, value),
                  ),
                ),
                const SizedBox(width: 8),
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: AppStyles.getCardColor(context),
                      textStyle: TextStyle(color: AppStyles.getTextColor(context)),
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AppStyles.getSecondaryTextColor(context)),
                    onSelected: (String result) {
                      if (result == 'edit') _showBankBottomSheet(existingBank: bank, bankIndex: index);
                      else if (result == 'delete') _deleteBank(index);
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Edit Sender IDs', style: TextStyle(color: AppStyles.getTextColor(context))),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: CupertinoColors.destructiveRed)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Keeping FadingFloatingActionButton...
class FadingFloatingActionButton extends StatefulWidget {
  final VoidCallback onPressed;
  const FadingFloatingActionButton({super.key, required this.onPressed});
  @override
  State<FadingFloatingActionButton> createState() => _FadingFloatingActionButtonState();
}

class _FadingFloatingActionButtonState extends State<FadingFloatingActionButton> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _controller;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 1.0, end: 0.1).animate(_controller);
    _startInactivityTimer();
  }
  void _startInactivityTimer() {
    _timer?.cancel();
    if (_controller.value > 0) _controller.reverse();
    _timer = Timer(const Duration(seconds: 4), () { if (mounted) _controller.forward(); });
  }
  @override
  void dispose() { _timer?.cancel(); _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: GestureDetector(
            onTapDown: (_) => _startInactivityTimer(),
            onTap: () { _startInactivityTimer(); widget.onPressed(); },
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: CupertinoColors.systemBlue.withValues(alpha:0.4), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Icon(CupertinoIcons.add, color: Colors.white, size: 28),
            ),
          ),
        );
      },
    );
  }
}