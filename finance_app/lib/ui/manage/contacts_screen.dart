import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/contact_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';

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
                    ? EmptyStateView(
                        icon: CupertinoIcons.person_add,
                        title: 'No contacts yet',
                        subtitle: 'Add people you frequently transact with',
                        actionLabel: 'Add Contact',
                        onAction: () =>
                            _showAddContactDialog(context, contactsController),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                            Spacing.lg, Spacing.md, Spacing.lg, 100),
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return StaggeredItem(
                            index: index,
                            child: _buildContactCard(
                                contact, context, contactsController),
                          );
                        },
                      ),
              ),
              // Add Button
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl,
                child: FadingFAB(
                  onPressed: () =>
                      _showAddContactDialog(context, contactsController),
                  color: SemanticColors.contacts,
                  heroTag: 'contacts_fab',
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
    final firstLetter =
        contactName.isNotEmpty ? contactName[0].toUpperCase() : '?';

    return BouncyButton(
      onPressed: () {
        Haptics.light();
        _showContactOptions(context, contact, controller);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: Spacing.md),
        decoration: AppStyles.cardDecoration(context).copyWith(
          border: Border.all(
            color: SemanticColors.contacts
                .withValues(alpha: Opacities.borderSubtle),
            width: 1,
          ),
        ),
        padding:
            EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
        child: Row(
          children: [
            Container(
              width: ComponentSizes.avatarMedium,
              height: ComponentSizes.avatarMedium,
              decoration: BoxDecoration(
                color: SemanticColors.contacts
                    .withValues(alpha: Opacities.iconBackground),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  firstLetter,
                  style: TextStyle(
                    color: SemanticColors.contacts,
                    fontWeight: FontWeight.w600,
                    fontSize: TypeScale.title3,
                  ),
                ),
              ),
            ),
            SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contactName,
                    style: AppStyles.titleStyle(context).copyWith(
                      fontSize: TypeScale.body,
                    ),
                  ),
                  if (contact.phoneNumber?.isNotEmpty ?? false)
                    Text(
                      contact.phoneNumber!,
                      style: TextStyle(
                        fontSize: TypeScale.footnote,
                        color: AppStyles.getSecondaryTextColor(context),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: IconSizes.sm,
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

  void _showAddContactDialog(
      BuildContext context, ContactsController controller) {
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
                  phoneNumber: phoneController.text.isNotEmpty
                      ? phoneController.text
                      : null,
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
                  phoneNumber: phoneController.text.isNotEmpty
                      ? phoneController.text
                      : null,
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
