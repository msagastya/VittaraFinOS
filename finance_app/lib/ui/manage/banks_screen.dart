import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vittara_fin_os/logic/banks_controller.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;
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

  void _onReorder(int oldIndex, int newIndex, BanksController banksController) {
    banksController.reorderBanks(oldIndex, newIndex);
  }

  void _toggleBank(String bankId, bool value, BanksController banksController) {
    banksController.toggleBank(bankId, value);
  }

  void _deleteBank(String bankId, BanksController banksController) {
    final bank = banksController.banks.firstWhere(
      (b) => b['id'] == bankId,
      orElse: () => <String, dynamic>{},
    );
    if (bank.isEmpty) return;

    showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Bank'),
        content: Text('Remove "${bank['name']}" from your list?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      Haptics.delete();
      banksController.deleteBank(bankId);
      toast_lib.toast.showSuccess(
        '"${bank['name']}" removed',
        actionLabel: 'Undo',
        onAction: () => banksController.addBank(bank),
      );
    });
  }

  void _sortBanks(BanksController banksController) {
    _isAscending = !_isAscending;
    banksController.sortBanks(_isAscending);
  }

  void _showBankBottomSheet({Map<String, dynamic>? existingBank}) {
    final nameController =
        TextEditingController(text: existingBank?['name'] ?? '');
    final senderIdController = TextEditingController();
    final List<String> tempSenderIds =
        List<String>.from(existingBank?['senderIds'] ?? []);
    final isEditMode = existingBank != null;

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Consumer<BanksController>(
          builder: (context, banksController, child) {
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
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Container(
                                width: 36,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey3,
                                    borderRadius: BorderRadius.circular(2.5)),
                              ),
                            ),
                            const SizedBox(height: Spacing.lg),
                            Text(
                              isEditMode ? 'Edit Bank' : 'Add Bank',
                              style: AppStyles.titleStyle(context)
                                  .copyWith(fontSize: TypeScale.title2),
                            ),
                            const SizedBox(height: Spacing.lg),
                            Container(
                              height: 1,
                              color: isDark
                                  ? Colors.grey[800]
                                  : CupertinoColors.systemGrey5,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            const SizedBox(height: Spacing.lg),
                            Expanded(
                              child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel(context, 'Bank Name'),
                                    const SizedBox(height: Spacing.sm),
                                    CupertinoTextField(
                                      controller: nameController,
                                      enabled: !isEditMode,
                                      placeholder: 'Bank Name',
                                      style: TextStyle(
                                          color:
                                              AppStyles.getTextColor(context)),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF2C2C2E)
                                            : CupertinoColors.systemGrey6,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                    ),
                                    const SizedBox(height: Spacing.xxl),
                                    _buildLabel(context,
                                        'Sender IDs (${tempSenderIds.length})'),
                                    const SizedBox(height: Spacing.sm),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: CupertinoTextField(
                                            controller: senderIdController,
                                            placeholder: 'Enter Sender ID',
                                            style: TextStyle(
                                                color: AppStyles.getTextColor(
                                                    context)),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF2C2C2E)
                                                  : CupertinoColors.systemGrey6,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                          ),
                                        ),
                                        const SizedBox(width: Spacing.sm),
                                        CupertinoButton(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          color: CupertinoColors.systemBlue,
                                          child: const Text('Add',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            if (senderIdController
                                                .text.isNotEmpty) {
                                              setDialogState(() {
                                                tempSenderIds.add(
                                                    senderIdController.text
                                                        .toUpperCase());
                                                senderIdController.clear();
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: Spacing.lg),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: tempSenderIds
                                          .map((id) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: CupertinoColors
                                                      .systemBlue
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: CupertinoColors
                                                          .systemBlue),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(id,
                                                        style: const TextStyle(
                                                            color:
                                                                CupertinoColors
                                                                    .systemBlue,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500)),
                                                    const SizedBox(width: 6),
                                                    GestureDetector(
                                                      onTap: () =>
                                                          setDialogState(() =>
                                                              tempSenderIds
                                                                  .remove(id)),
                                                      child: const Icon(
                                                          CupertinoIcons
                                                              .xmark_circle_fill,
                                                          size: 16,
                                                          color: CupertinoColors
                                                              .systemBlue),
                                                    ),
                                                  ],
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(Spacing.lg),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CupertinoButton(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : CupertinoColors.systemGrey5,
                                      child: Text('Cancel',
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black)),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: CupertinoButton(
                                      color: CupertinoColors.systemBlue,
                                      child: Text(isEditMode ? 'Update' : 'Add',
                                          style: const TextStyle(
                                              color: Colors.white)),
                                      onPressed: () {
                                        if (isEditMode) {
                                          final updated =
                                              Map<String, dynamic>.from(
                                                  existingBank);
                                          updated['senderIds'] = tempSenderIds;
                                          banksController.updateBank(updated);
                                          Navigator.pop(context);
                                        } else {
                                          final error =
                                              banksController.addNewBank(
                                                  nameController.text,
                                                  tempSenderIds);
                                          if (error != null) {
                                            showCupertinoDialog(
                                              context: context,
                                              builder: (ctx) =>
                                                  CupertinoAlertDialog(
                                                title: const Text(
                                                    'Cannot Add Bank'),
                                                content: Text(error),
                                                actions: [
                                                  CupertinoDialogAction(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: const Text('OK'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            return;
                                          }
                                          Navigator.pop(context);
                                          toast_lib.toast
                                              .showSuccess('Bank added');
                                        }
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
      },
    ).whenComplete(() {
      nameController.dispose();
      senderIdController.dispose();
    });
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: TypeScale.body,
        fontWeight: FontWeight.w500,
        color: AppStyles.isDarkMode(context)
            ? Colors.grey[400]
            : CupertinoColors.systemGrey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BanksController>(
      builder: (context, banksController, child) {
        final filteredBanks = banksController.banks.where((bank) {
          return bank['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
        }).toList();

        return CupertinoPageScaffold(
          backgroundColor: AppStyles.getBackground(context),
          navigationBar: CupertinoNavigationBar(
            middle: Text('Banks',
                style: TextStyle(color: AppStyles.getTextColor(context))),
            previousPageTitle: 'Manage',
            backgroundColor: AppStyles.getBackground(context),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _sortBanks(banksController),
              child: Icon(
                _isAscending
                    ? CupertinoIcons.sort_down
                    : CupertinoIcons.sort_up,
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
                      margin: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CupertinoSearchTextField(
                        backgroundColor: Colors.transparent,
                        style:
                            TextStyle(color: AppStyles.getTextColor(context)),
                        placeholder: 'Search Banks',
                        placeholderStyle: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context)),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: filteredBanks.length,
                        onReorder: (oldIndex, newIndex) {
                          HapticFeedback.mediumImpact();
                          _onReorder(oldIndex, newIndex, banksController);
                        },
                        proxyDecorator: (child, index, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) => Transform.scale(
                              scale: 1.02,
                              child: Container(
                                decoration: AppStyles.cardDecoration(context),
                                child: child,
                              ),
                            ),
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final bank = filteredBanks[index];
                          return StaggeredItem(
                            key: ValueKey(bank['id']),
                            index: index,
                            child: _build3DBankCard(bank, banksController),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 32,
                child: FadingFloatingActionButton(
                    onPressed: () => _showBankBottomSheet()),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _build3DBankCard(
      Map<String, dynamic> bank, BanksController banksController) {
    return Slidable(
      key: ValueKey('slide_${bank['id']}'),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              _showBankBottomSheet(existingBank: bank);
            },
            backgroundColor: CupertinoColors.systemBlue,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.pencil,
            label: 'Edit',
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(12)),
          ),
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.heavyImpact();
              _deleteBank(bank['id'], banksController);
            },
            backgroundColor: CupertinoColors.destructiveRed,
            foregroundColor: Colors.white,
            icon: CupertinoIcons.trash,
            label: 'Delete',
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ],
      ),
      child: _buildBankCardContent(bank, banksController),
    );
  }

  Widget _buildBankCardContent(
      Map<String, dynamic> bank, BanksController banksController) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppStyles.cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: AppStyles.iconBoxDecoration(context, bank['color']),
              child: Center(
                  child: Icon(CupertinoIcons.building_2_fill,
                      color: bank['color'], size: 24)),
            ),
            const SizedBox(width: Spacing.lg),
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
                        style: TextStyle(
                            fontSize: TypeScale.footnote,
                            color: AppStyles.getSecondaryTextColor(context)),
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
                    activeTrackColor: CupertinoColors.activeGreen,
                    onChanged: (bool value) =>
                        _toggleBank(bank['id'], value, banksController),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: AppStyles.getCardColor(context),
                      textStyle:
                          TextStyle(color: AppStyles.getTextColor(context)),
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(CupertinoIcons.ellipsis_vertical,
                        color: AppStyles.getSecondaryTextColor(context)),
                    onSelected: (String result) {
                      if (result == 'edit') {
                        _showBankBottomSheet(existingBank: bank);
                      } else if (result == 'delete') {
                        _deleteBank(bank['id'], banksController);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Edit Sender IDs',
                            style: TextStyle(
                                color: AppStyles.getTextColor(context))),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(
                                color: CupertinoColors.destructiveRed)),
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
  State<FadingFloatingActionButton> createState() =>
      _FadingFloatingActionButtonState();
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
        vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 1.0, end: 0.1).animate(_controller);
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    _timer?.cancel();
    if (_controller.value > 0) _controller.reverse();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) _controller.forward();
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
                      color: CupertinoColors.systemBlue.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child:
                  const Icon(CupertinoIcons.add, color: Colors.white, size: 28),
            ),
          ),
        );
      },
    );
  }
}
