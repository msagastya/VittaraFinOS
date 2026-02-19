import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/category_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/icon_picker.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';
import 'package:vittara_fin_os/utils/logger.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final AppLogger logger = AppLogger();
  String _searchQuery = '';

  void _showAddCategoryModal(BuildContext context) {
    final nameController = TextEditingController();
    IconData selectedIcon = CupertinoIcons.tag_fill;
    Color selectedColor = const Color(0xFF007AFF);

    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => StatefulBuilder(
        builder: (stateContext, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(stateContext),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
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
                    // Handle bar
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

                    // Title
                    Text(
                      'Create Custom Category',
                      style: AppStyles.titleStyle(stateContext)
                          .copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 24),

                    // Icon Preview (Centered)
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

                    // Color Picker (Centered)
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

                    // Category Name (Centered)
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
                            placeholder: 'Enter category name',
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppStyles.getBackground(stateContext),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            style: TextStyle(
                                color: AppStyles.getTextColor(stateContext)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton(
                              color: CupertinoColors.systemGrey3,
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppStyles.getTextColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CupertinoButton(
                              color: AppStyles.accentBlue,
                              onPressed: () {
                                if (nameController.text.isNotEmpty) {
                                  final newCategory = Category(
                                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                                    name: nameController.text,
                                    color: selectedColor,
                                    icon: selectedIcon,
                                    isCustom: true,
                                  );
                                  Provider.of<CategoriesController>(context,
                                          listen: false)
                                      .addCategory(newCategory);
                                  Navigator.pop(context);
                                  logger.info(
                                    'Created custom category: ${newCategory.name}',
                                    context: 'CategoriesScreen',
                                  );
                                }
                              },
                              child: const Text(
                                'Create',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text('Categories',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<CategoriesController>(
        builder: (context, categoriesController, child) {
          final filteredCategories =
              categoriesController.categories.where((cat) {
            return cat.name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          final defaultCats =
              filteredCategories.where((cat) => !cat.isCustom).toList();
          final customCats =
              filteredCategories.where((cat) => cat.isCustom).toList();

          return Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    // Search Bar
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppStyles.getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CupertinoSearchTextField(
                        backgroundColor: Colors.transparent,
                        style:
                            TextStyle(color: AppStyles.getTextColor(context)),
                        placeholder: 'Search Categories',
                        placeholderStyle: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context)),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    // Categories List
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Default Categories
                            if (defaultCats.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 8, top: 16, bottom: 12),
                                child: Text(
                                  'Built-in Categories (${defaultCats.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                              ),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1,
                                ),
                                itemCount: defaultCats.length,
                                itemBuilder: (context, index) {
                                  final category = defaultCats[index];
                                  return StaggeredItem(
                                    index: index,
                                    child: _buildCategoryCard(category, context,
                                        categoriesController),
                                  );
                                },
                              ),
                            ],
                            // Custom Categories
                            if (customCats.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 8, top: 24, bottom: 12),
                                child: Text(
                                  'Your Custom Categories (${customCats.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.getSecondaryTextColor(
                                        context),
                                  ),
                                ),
                              ),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1,
                                ),
                                itemCount: customCats.length,
                                itemBuilder: (context, index) {
                                  final category = customCats[index];
                                  return StaggeredItem(
                                    index: index + defaultCats.length,
                                    child: _buildCategoryCard(
                                      category,
                                      context,
                                      categoriesController,
                                      isCustom: true,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl,
                child: FadingFAB(
                  onPressed: () => _showAddCategoryModal(context),
                  color: SemanticColors.categories,
                  heroTag: 'categories_fab',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(
    Category category,
    BuildContext context,
    CategoriesController controller, {
    bool isCustom = false,
  }) {
    return BouncyButton(
      onPressed: () {
        logger.info('Tapped category: ${category.name}',
            context: 'CategoriesScreen');
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: category.color.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Icon in Center
                Expanded(
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: category.color.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          category.icon,
                          size: 32,
                          color: category.color,
                        ),
                      ),
                    ),
                  ),
                ),
                // Category Name at Bottom
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                ),
              ],
            ),
            if (isCustom)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    Haptics.delete();
                    final deletedName = category.name;
                    final deletedCategory = category;
                    controller.removeCategory(category.id);
                    logger.info('Deleted category: $deletedName',
                        context: 'CategoriesScreen');
                    toast.showSuccess(
                      '"$deletedName" deleted',
                      actionLabel: 'Undo',
                      onAction: () {
                        controller.addCategory(deletedCategory);
                        toast.showInfo('Category restored');
                      },
                    );
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: SemanticColors.error,
                      shape: BoxShape.circle,
                      boxShadow: Shadows.iconGlow(SemanticColors.error),
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
