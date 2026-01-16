import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class BanksScreen extends StatefulWidget {
  const BanksScreen({super.key});

  @override
  State<BanksScreen> createState() => _BanksScreenState();
}

class _BanksScreenState extends State<BanksScreen> {
  final AppLogger logger = AppLogger();
  String _searchQuery = '';
  bool _isAscending = true; // Sorting state
  
  late List<Map<String, dynamic>> _banks;

  @override
  void initState() {
    super.initState();
    _banks = _generateBankList();
  }

  List<Map<String, dynamic>> _generateBankList() {
    final banks = [
      // Major Indian Banks
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
      {'name': 'Punjab & Sind Bank', 'color': const Color(0xFFFFD200)},
      {'name': 'Indian Overseas Bank', 'color': const Color(0xFF005B9F)},
      {'name': 'South Indian Bank', 'color': const Color(0xFFDA2128)},
      {'name': 'Karur Vysya Bank', 'color': const Color(0xFFB51F24)},
      {'name': 'Karnataka Bank', 'color': const Color(0xFFB51F24)},
      {'name': 'RBL Bank', 'color': const Color(0xFF005B9F)},
      {'name': 'Jammu & Kashmir Bank', 'color': const Color(0xFF00964A)},
      {'name': 'City Union Bank', 'color': const Color(0xFFB51F24)},
      {'name': 'Tamilnad Mercantile Bank', 'color': const Color(0xFFD41367)},
      {'name': 'Bandhan Bank', 'color': const Color(0xFFED1C24)},
      {'name': 'CSB Bank', 'color': const Color(0xFF005B9F)},
      {'name': 'Dhanlaxmi Bank', 'color': const Color(0xFFB51F24)},
      {'name': 'Nainital Bank', 'color': const Color(0xFF005B9F)},
      
      // Small Finance Banks
      {'name': 'AU Small Finance Bank', 'color': const Color(0xFF6A2C91)},
      {'name': 'Equitas Small Finance Bank', 'color': const Color(0xFF005B9F)},
      {'name': 'Ujjivan Small Finance Bank', 'color': const Color(0xFF005B9F)},
      {'name': 'Suryoday Small Finance Bank', 'color': const Color(0xFFF37021)},
      {'name': 'ESAF Small Finance Bank', 'color': const Color(0xFF005B9F)},
      {'name': 'Fincare Small Finance Bank', 'color': const Color(0xFF6A2C91)},
      {'name': 'Jana Small Finance Bank', 'color': const Color(0xFFF37021)},
      {'name': 'North East Small Finance Bank', 'color': const Color(0xFF00964A)},
      {'name': 'Shivalik Small Finance Bank', 'color': const Color(0xFFF37021)},
      {'name': 'Utkarsh Small Finance Bank', 'color': const Color(0xFF6A2C91)},
      {'name': 'Unity Small Finance Bank', 'color': const Color(0xFF005B9F)},
      {'name': 'Capital Small Finance Bank', 'color': const Color(0xFF005B9F)},
      
      // Payments Banks
      {'name': 'Paytm Payments Bank', 'color': const Color(0xFF002E6E)},
      {'name': 'Airtel Payments Bank', 'color': const Color(0xFFED1C24)},
      {'name': 'India Post Payments Bank', 'color': const Color(0xFFDA2128)},
      {'name': 'Fino Payments Bank', 'color': const Color(0xFF6A2C91)},
      {'name': 'Jio Payments Bank', 'color': const Color(0xFF005B9F)},
      {'name': 'NSDL Payments Bank', 'color': const Color(0xFF005B9F)},
      
      // Wallets & Fintech
      {'name': 'Paytm Wallet', 'color': const Color(0xFF00BAF2)},
      {'name': 'PhonePe', 'color': const Color(0xFF5F259F)},
      {'name': 'Google Pay', 'color': const Color(0xFF4285F4)},
      {'name': 'Amazon Pay', 'color': const Color(0xFFF4B400)},
      {'name': 'Bhim UPI', 'color': const Color(0xFF00964A)},
      {'name': 'Mobikwik', 'color': const Color(0xFF005B9F)},
      {'name': 'Freecharge', 'color': const Color(0xFFF37021)},
      {'name': 'Cred', 'color': const Color(0xFF000000)},
      {'name': 'Slice', 'color': const Color(0xFF6A2C91)},
      {'name': 'Uni', 'color': const Color(0xFFF37021)},
      {'name': 'OneCard', 'color': const Color(0xFF005B9F)},
      {'name': 'LazyPay', 'color': const Color(0xFFF37021)},
      {'name': 'Simpl', 'color': const Color(0xFF00964A)},
      {'name': 'ZestMoney', 'color': const Color(0xFF00964A)},
      {'name': 'Ola Money', 'color': const Color(0xFF005B9F)},
      {'name': 'JioMoney', 'color': const Color(0xFF005B9F)},
      {'name': 'Airtel Money', 'color': const Color(0xFFED1C24)},
      {'name': 'HDFC PayZapp', 'color': const Color(0xFF004C8F)},
      {'name': 'ICICI Pockets', 'color': const Color(0xFFF37E20)},
      {'name': 'SBI Buddy', 'color': const Color(0xFF007DCC)},
      
      // Global Majors (Sample)
      {'name': 'JPMorgan Chase', 'color': const Color(0xFF005B9F)},
      {'name': 'Bank of America', 'color': const Color(0xFFED1C24)},
      {'name': 'Citi', 'color': const Color(0xFF003B70)},
      {'name': 'Wells Fargo', 'color': const Color(0xFFCD1409)},
      {'name': 'HSBC', 'color': const Color(0xFFDB0011)},
      {'name': 'Barclays', 'color': const Color(0xFF00AEEF)},
      {'name': 'Standard Chartered', 'color': const Color(0xFF00964A)},
      {'name': 'DBS Bank', 'color': const Color(0xFFED1C24)},
    ];

    banks.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return banks.map((bank) {
      return {
        'id': (bank['name'] as String).replaceAll(' ', '_').toLowerCase(),
        'name': bank['name'],
        'color': bank['color'],
        'isEnabled': false, // Default to off
        'senderIds': <String>[], // Initialize empty list for Sender IDs
      };
    }).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _banks.removeAt(oldIndex);
      _banks.insert(newIndex, item);
    });
  }

  void _toggleBank(int index, bool value) {
    setState(() {
      _banks[index]['isEnabled'] = value;
    });
    logger.info('Toggled ${_banks[index]['name']} to $value', context: 'BanksScreen');
  }

  void _deleteBank(int index) {
    final name = _banks[index]['name'];
    setState(() {
      _banks.removeAt(index);
    });
    logger.info('Deleted bank: $name', context: 'BanksScreen');
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

  void _showAddBankDialog() {
    final nameController = TextEditingController();
    final senderIdController = TextEditingController();
    List<String> tempSenderIds = [];

    showCupertinoDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text('Add Bank'),
              content: Column(
                children: [
                  const SizedBox(height: 16),
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: 'Bank Name',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: senderIdController,
                          placeholder: 'Sender ID (Optional)',
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Icon(CupertinoIcons.add_circled),
                        onPressed: () {
                          if (senderIdController.text.isNotEmpty) {
                            if (tempSenderIds.length < 10) {
                              setDialogState(() {
                                tempSenderIds.add(senderIdController.text.toUpperCase());
                                senderIdController.clear();
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (tempSenderIds.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tempSenderIds.map((id) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CupertinoColors.systemBlue),
                        ),
                        child: Text(
                          id, 
                          style: const TextStyle(fontSize: 12, color: CupertinoColors.systemBlue),
                        ),
                      )).toList(),
                    ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      setState(() {
                        _banks.add({
                          'id': nameController.text.replaceAll(' ', '_').toLowerCase(),
                          'name': nameController.text,
                          'color': CupertinoColors.systemGrey, // Default color
                          'isEnabled': false,
                          'senderIds': tempSenderIds,
                        });
                        // Re-sort if needed, or just append
                        if (_isAscending) {
                           _banks.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
                        }
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBanks = _banks.where((bank) {
      return bank['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Banks'),
        previousPageTitle: 'Manage',
        backgroundColor: const Color(0xFFF2F2F7),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _sortBanks,
          child: Icon(
            _isAscending ? CupertinoIcons.sort_down : CupertinoIcons.sort_up,
            size: 24,
          ),
        ),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Search Bar (Elevated)
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CupertinoSearchTextField(
                    backgroundColor: Colors.transparent,
                    placeholder: 'Search Banks & Wallets',
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),

                // Bank List
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // Extra bottom padding for FAB
                    itemCount: filteredBanks.length,
                    onReorder: _onReorder,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (BuildContext context, Widget? child) {
                          final double animValue = Curves.easeInOut.transform(animation.value);
                          final double elevation = lerpDouble(0, 10, animValue)!;
                          final double scale = lerpDouble(1, 1.05, animValue)!;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha:0.2),
                                    blurRadius: elevation * 2,
                                    offset: Offset(0, elevation),
                                  ),
                                ],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: child,
                      );
                    },
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
          
          // Floating Action Button
          Positioned(
            right: 16,
            bottom: 32,
            child: FadingFloatingActionButton(
              onPressed: _showAddBankDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DBankCard(Map<String, dynamic> bank, int index) {
    return Container(
      key: ValueKey(bank['id']),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Level 1 Shadow: The Card itself
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha:0.08),
            offset: const Offset(0, 8),
            blurRadius: 16,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: const Color(0xFFFFFFFF),
            offset: const Offset(0, -1),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Icon (Level 2 Depth: Embedded)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (bank['color'] as Color).withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (bank['color'] as Color).withValues(alpha:0.2), width: 1),
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.building_2_fill,
                  color: bank['color'],
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank['name'],
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.3,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if ((bank['senderIds'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${(bank['senderIds'] as List).length} Sender IDs',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.systemGrey,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Actions (Level 2 Depth: Floating)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle (Level 2 Depth)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.05),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Transform.scale(
                    scale: 0.75,
                    child: CupertinoSwitch(
                      value: bank['isEnabled'],
                      activeTrackColor: CupertinoColors.activeGreen,
                      onChanged: (bool value) {
                        _toggleBank(index, value);
                      },
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Context Menu Button
                Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    popupMenuTheme: PopupMenuThemeData(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 10,
                      color: Colors.white,
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, 40),
                    icon: const Icon(
                      Icons.more_vert,
                      color: CupertinoColors.systemGrey,
                    ),
                    onSelected: (String result) {
                      if (result == 'edit') {
                        logger.info('Edit Sender IDs for ${bank['name']}', context: 'BanksScreen');
                        // Logic to open edit dialog would go here
                      } else if (result == 'delete') {
                        _deleteBank(index);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.pencil, size: 18, color: CupertinoColors.activeBlue),
                            SizedBox(width: 12),
                            Text('Edit Sender IDs', style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.trash, size: 18, color: CupertinoColors.destructiveRed),
                            SizedBox(width: 12),
                            Text('Delete', style: TextStyle(color: CupertinoColors.destructiveRed, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Reorder Handle
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(
                    CupertinoIcons.line_horizontal_3,
                    color: CupertinoColors.systemGrey4,
                    size: 20,
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

// Smart Fading FAB
class FadingFloatingActionButton extends StatefulWidget {
  final VoidCallback onPressed;

  const FadingFloatingActionButton({super.key, required this.onPressed});

  @override
  State<FadingFloatingActionButton> createState() => _FadingFloatingActionButtonState();
}

class _FadingFloatingActionButtonState extends State<FadingFloatingActionButton>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.1).animate(_controller);
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    _timer?.cancel();
    // Reset to full opacity if hidden
    if (_controller.value > 0) {
      _controller.reverse();
    }
    
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.forward(); // Fade to 0.1
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: GestureDetector(
            // When user touches, reset timer and opacity
            onTapDown: (_) => _startInactivityTimer(),
            onTap: () {
              _startInactivityTimer();
              widget.onPressed();
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemBlue.withValues(alpha:0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.add,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}