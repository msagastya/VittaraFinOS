import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/category_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/widgets/icon_picker.dart';

Future<Category?> showCreateCategoryModal(
  BuildContext context, {
  required CategoriesController controller,
}) {
  final nameController = TextEditingController();
  IconData selectedIcon = CupertinoIcons.tag_fill;
  Color selectedColor = const Color(0xFF007AFF);

  void createAndClose(BuildContext modalContext) {
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final newCategory = Category(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      color: selectedColor,
      icon: selectedIcon,
      isCustom: true,
    );

    controller.addCategory(newCategory);
    Navigator.pop(modalContext, newCategory);
  }

  return showCupertinoModalPopup<Category>(
    context: context,
    builder: (modalContext) => StatefulBuilder(
      builder: (stateContext, setModalState) {
        return Container(
          decoration: BoxDecoration(
            color: AppStyles.getCardColor(stateContext),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(stateContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey3,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Create Custom Category',
                    style: AppStyles.titleStyle(stateContext)
                        .copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: selectedColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            selectedIcon,
                            size: 40,
                            color: selectedColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CupertinoButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (newContext) => _IconPickerScreen(
                                onIconSelected: (icon) {
                                  setModalState(() => selectedIcon = icon);
                                  Navigator.of(newContext).pop();
                                },
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Choose Icon',
                          style: TextStyle(
                            color: AppStyles.accentBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Color',
                        style: AppStyles.headerStyle(stateContext),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Color(0xFFFF6B6B),
                            const Color(0xFF51CF66),
                            const Color(0xFF0099FF),
                            const Color(0xFFFF9800),
                            const Color(0xFF9C27B0),
                            const Color(0xFFE91E63),
                            const Color(0xFF00BCD4),
                            const Color(0xFF4CAF50),
                            const Color(0xFF8B4513),
                            const Color(0xFF607D8B),
                          ]
                              .map((color) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: GestureDetector(
                                      onTap: () => setModalState(
                                          () => selectedColor = color),
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selectedColor == color
                                                ? Colors.white
                                                : Colors.transparent,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Category Name',
                            style: AppStyles.headerStyle(stateContext)),
                        const SizedBox(height: 12),
                        CupertinoTextField(
                          controller: nameController,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => createAndClose(modalContext),
                          placeholder: 'Enter category name',
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppStyles.getBackground(stateContext),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          style: TextStyle(
                            color: AppStyles.getTextColor(stateContext),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            color: CupertinoColors.systemGrey3,
                            onPressed: () => Navigator.pop(modalContext),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppStyles.getTextColor(modalContext),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoButton(
                            color: AppStyles.accentBlue,
                            onPressed: () => createAndClose(modalContext),
                            child: const Text(
                              'Create',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ).whenComplete(nameController.dispose);
}

class _IconPickerScreen extends StatelessWidget {
  final Function(IconData) onIconSelected;

  const _IconPickerScreen({required this.onIconSelected});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      child: SafeArea(
        child: IconPickerModal(
          onIconSelected: onIconSelected,
        ),
      ),
    );
  }
}
