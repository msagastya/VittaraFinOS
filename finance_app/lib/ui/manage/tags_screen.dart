import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/tags_controller.dart';
import 'package:vittara_fin_os/logic/tag_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

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
                        style: AppStyles.titleStyle(context).copyWith(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Organize transactions with custom labels',
                        style: TextStyle(color: AppStyles.getSecondaryTextColor(context), fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      if (tags.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                          decoration: BoxDecoration(
                            color: AppStyles.accentBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppStyles.accentBlue.withValues(alpha: 0.2), width: 2),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppStyles.accentBlue.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(CupertinoIcons.tag, size: 32, color: AppStyles.accentBlue),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tags created yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyles.getTextColor(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the + button to create your first tag',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppStyles.getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppStyles.accentBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppStyles.accentBlue.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.info_circle, size: 20, color: AppStyles.accentBlue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${tags.length} tag${tags.length > 1 ? 's' : ''} created',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppStyles.accentBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: tags.map((tag) => _buildTagChip(tag, context, tagsController)).toList(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              // Add Button
              Positioned(
                right: 16,
                bottom: 32,
                child: FadingFloatingActionButton(
                  onPressed: () => _showCreateTagWizard(context, tagsController),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTagChip(Tag tag, BuildContext context, TagsController controller) {
    return GestureDetector(
      onLongPress: () => _showTagOptions(context, tag, controller),
      onTap: () => _showTagDetailsSheet(context, tag, controller),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: tag.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tag.color.withValues(alpha: 0.3), width: 1.5),
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
            const SizedBox(width: 8),
            Text(
              tag.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tag.color,
                fontSize: 13,
              ),
            ),
          ],
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
              const SizedBox(height: 12),
              Text(
                'Create New Tag',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Give it a name and choose a color',
                style: TextStyle(
                  fontSize: 13,
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
                  padding: const EdgeInsets.all(12),
                  maxLength: 20,
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: selectedColor.withValues(alpha: 0.3)),
                  ),
                  style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pick a color:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.getTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: Tag.colorPalette.map((color) {
                        final isSelected = selectedColor.value == color.value;
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = color),
                          child: Container(
                            width: 52,
                            height: 52,
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
                                    child: Icon(CupertinoIcons.checkmark, color: Colors.white, size: 24),
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

  void _showTagDetailsSheet(BuildContext context, Tag tag, TagsController controller) {
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
            const SizedBox(height: 12),
            Text(
              tag.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppStyles.getTextColor(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Created ${_formatDate(tag.createdDate)}',
              style: TextStyle(
                fontSize: 12,
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

  void _showEditTagSheet(BuildContext context, Tag tag, TagsController controller) {
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tag.color.withValues(alpha: 0.3)),
            ),
            style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600),
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

  void _showColorPickerSheet(BuildContext context, Tag tag, TagsController controller) {
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
            const SizedBox(height: 4),
            Text(
              'Choose a new color for this tag',
              style: TextStyle(
                fontSize: 12,
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
              final isSelected = tag.color.value == color.value;
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
                          child: Icon(CupertinoIcons.checkmark, color: Colors.white, size: 28),
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

  void _showTagOptions(BuildContext context, Tag tag, TagsController controller) {
    _showTagDetailsSheet(context, tag, controller);
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class FadingFloatingActionButton extends StatefulWidget {
  final VoidCallback onPressed;
  const FadingFloatingActionButton({super.key, required this.onPressed});

  @override
  State<FadingFloatingActionButton> createState() => _FadingFloatingActionButtonState();
}

class _FadingFloatingActionButtonState extends State<FadingFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(_controller);
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    if (_controller.value > 0) _controller.reverse();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
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
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.add, color: Colors.white, size: 28),
            ),
          ),
        );
      },
    );
  }
}
