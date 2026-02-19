import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/categories_controller.dart';
import 'package:vittara_fin_os/logic/category_model.dart';
import 'package:vittara_fin_os/ui/manage/categories/category_creation_modal.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
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
    final controller =
        Provider.of<CategoriesController>(context, listen: false);
    showCreateCategoryModal(context, controller: controller).then((category) {
      if (category != null) {
        logger.info(
          'Created custom category: ${category.name}',
          context: 'CategoriesScreen',
        );
      }
    });
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
