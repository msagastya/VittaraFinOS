import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/contact_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'People',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        previousPageTitle: 'Manage',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<ContactsController>(
        builder: (context, contactsController, child) {
          final contacts = contactsController.contacts;

          return Stack(
            children: [
              SafeArea(
                child: contacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.person_add,
                              size: 48,
                              color: AppStyles.getSecondaryTextColor(context),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No contacts yet',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add people you frequently transact with',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return _buildContactCard(contact, context, contactsController);
                        },
                      ),
              ),
              // Add Button
              Positioned(
                right: 16,
                bottom: 32,
                child: FadingFloatingActionButton(
                  onPressed: () => _showAddContactDialog(context, contactsController),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContactCard(
    Contact contact,
    BuildContext context,
    ContactsController controller,
  ) {
    final contactName = contact.name.isNotEmpty ? contact.name : 'Unknown';
    final firstLetter = contactName.isNotEmpty ? contactName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppStyles.accentBlue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onPressed: () => _showContactOptions(context, contact, controller),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppStyles.accentBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    color: CupertinoColors.systemBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contactName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context),
                      fontSize: 14,
                    ),
                  ),
                  if (contact.phoneNumber?.isNotEmpty ?? false)
                    Text(
                      contact.phoneNumber!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.info_circle,
              size: 20,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactOptions(
    BuildContext context,
    Contact contact,
    ContactsController controller,
  ) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showEditContactDialog(context, contact, controller);
            },
            child: const Text('Edit Contact'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              controller.removeContact(contact.id);
            },
            child: const Text('Delete Contact'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, ContactsController controller) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Name',
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: phoneController,
              placeholder: 'Phone Number (Optional)',
              keyboardType: TextInputType.phone,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
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
                final contact = Contact(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  phoneNumber: phoneController.text.isNotEmpty ? phoneController.text : null,
                  createdDate: DateTime.now(),
                );
                controller.addContact(contact);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditContactDialog(
    BuildContext context,
    Contact contact,
    ContactsController controller,
  ) {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phoneNumber);

    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Edit Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Name',
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: phoneController,
              placeholder: 'Phone Number (Optional)',
              keyboardType: TextInputType.phone,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
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
                final updatedContact = contact.copyWith(
                  name: nameController.text,
                  phoneNumber: phoneController.text.isNotEmpty ? phoneController.text : null,
                );
                controller.removeContact(contact.id);
                controller.addContact(updatedContact);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
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
