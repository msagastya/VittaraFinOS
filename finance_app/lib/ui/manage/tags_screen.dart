import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/tags_controller.dart';
import 'package:vittara_fin_os/logic/tag_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Tags',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<TagsController>(
        builder: (context, tagsController, child) {
          final tags = tagsController.tags;

          return Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Tags',
                        style: AppStyles.titleStyle(context).copyWith(
                            fontSize: TypeScale.largeTitle, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        'Organize transactions with custom labels',
                        style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.body),
                      ),
                      const SizedBox(height: Spacing.xxxl),
                      if (tags.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 60, horizontal: 24),
                          decoration: BoxDecoration(
                            color: AppStyles.accentBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    AppStyles.accentBlue.withValues(alpha: 0.2),
                                width: 2),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppStyles.accentBlue
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(CupertinoIcons.tag,
                                      size: 32, color: AppStyles.accentBlue),
                                ),
                              ),
                              const SizedBox(height: Spacing.lg),
                              Text(
                                'No tags created yet',
                                style: TextStyle(
                                  fontSize: TypeScale.headline,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              const SizedBox(height: Spacing.sm),
                              Text(
                                'Tap the + button to create your first tag',
                                style: TextStyle(
                                  fontSize: TypeScale.subhead,
                                  color:
                                      AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(Spacing.lg),
                              decoration: BoxDecoration(
                                color: AppStyles.accentBlue
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppStyles.accentBlue
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.info_circle,
                                      size: 20, color: AppStyles.accentBlue),
                                  const SizedBox(width: Spacing.md),
                                  Expanded(
                                    child: Text(
                                      '${tags.length} tag${tags.length > 1 ? 's' : ''} created',
                                      style: TextStyle(
                                        fontSize: TypeScale.subhead,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.accentBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: Spacing.xxl),
                            Wrap(
                              spacing: Spacing.md,
                              runSpacing: Spacing.md,
                              children: tags
                                  .asMap()
                                  .entries
                                  .map((entry) => _buildTagChip(entry.value,
                                      context, tagsController, entry.key))
                                  .toList(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              // Add Button
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl,
                child: FadingFAB(
                  onPressed: () =>
                      _showCreateTagWizard(context, tagsController),
                  color: SemanticColors.tags,
                  heroTag: 'tags_fab',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTagChip(
      Tag tag, BuildContext context, TagsController controller, int index) {
    return StaggeredItem(
      index: index,
      child: BouncyButton(
        onPressed: () {
          Haptics.light();
          _showTagDetailsSheet(context, tag, controller);
        },
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.md),
          decoration: BoxDecoration(
            color: tag.color.withValues(alpha: 0.12),
            borderRadius: Radii.pillRadius,
            border:
                Border.all(color: tag.color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: tag.color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: Spacing.sm),
              Text(
                tag.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tag.color,
                  fontSize: TypeScale.subhead,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateTagWizard(BuildContext context, TagsController controller) {
    final nameController = TextEditingController();
    Color selectedColor = Tag.colorPalette[0];

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CupertinoActionSheet(
          title: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: selectedColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'Create New Tag',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Give it a name and choose a color',
                style: TextStyle(
                  fontSize: TypeScale.subhead,
                  color: AppStyles.getSecondaryTextColor(context),
                ),
              ),
            ],
          ),
          message: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoTextField(
                  controller: nameController,
                  placeholder: 'Tag name (max 20 characters)',
                  padding: const EdgeInsets.all(Spacing.md),
                  maxLength: 20,
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: selectedColor.withValues(alpha: 0.3)),
                  ),
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: TypeScale.body,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: Spacing.xl),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pick a color:',
                      style: TextStyle(
                        fontSize: TypeScale.subhead,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: Tag.colorPalette.map((color) {
                        final isSelected =
                            selectedColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 4,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Center(
                                    child: Icon(CupertinoIcons.checkmark,
                                        color: Colors.white, size: 24),
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (nameController.text.isNotEmpty)
              CupertinoActionSheetAction(
                isDefaultAction: true,
                onPressed: () {
                  final tag = Tag(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    color: selectedColor,
                    createdDate: DateTime.now(),
                  );
                  controller.addTag(tag);
                  Navigator.pop(context);
                },
                child: Text(
                  'Create Tag',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppStyles.accentBlue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTagDetailsSheet(
      BuildContext context, Tag tag, TagsController controller) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tag.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: tag.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              tag.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppStyles.getTextColor(context),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Created ${_formatDate(tag.createdDate)}',
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showEditTagSheet(context, tag, controller);
            },
            child: const Text('Edit Name'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showColorPickerSheet(context, tag, controller);
            },
            child: const Text('Change Color'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              controller.removeTag(tag.id);
            },
            child: const Text('Delete Tag'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ),
    );
  }

  void _showEditTagSheet(
      BuildContext context, Tag tag, TagsController controller) {
    final nameController = TextEditingController(text: tag.name);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          'Edit Tag Name',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppStyles.getTextColor(context),
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: 'Tag name',
            maxLength: 20,
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tag.color.withValues(alpha: 0.3)),
            ),
            style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                controller.updateTag(tag.id, nameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showColorPickerSheet(
      BuildContext context, Tag tag, TagsController controller) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Column(
          children: [
            Text(
              'Select Color',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppStyles.getTextColor(context),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Choose a new color for this tag',
              style: TextStyle(
                fontSize: TypeScale.footnote,
                color: AppStyles.getSecondaryTextColor(context),
              ),
            ),
          ],
        ),
        message: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: Tag.colorPalette.map((color) {
              final isSelected = tag.color.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () {
                  controller.updateTagColor(tag.id, color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 4,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Center(
                          child: Icon(CupertinoIcons.checkmark,
                              color: Colors.white, size: 28),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ),
    );
  }

  void _showTagOptions(
      BuildContext context, Tag tag, TagsController controller) {
    _showTagDetailsSheet(context, tag, controller);
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
