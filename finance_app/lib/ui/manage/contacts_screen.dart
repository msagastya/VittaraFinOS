import 'package:flutter/cupertino.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as device_contacts;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/contact_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart' as toast_lib;

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _searchQuery = '';
  bool _sortAlpha = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'People',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _sortAlpha = !_sortAlpha),
              child: Icon(
                _sortAlpha
                    ? CupertinoIcons.sort_down_circle_fill
                    : CupertinoIcons.sort_down_circle,
                color: _sortAlpha
                    ? AppStyles.accentBlue
                    : AppStyles.getSecondaryTextColor(context),
                size: 22,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showAddContactOptions(
                context,
                context.read<ContactsController>(),
              ),
              child: const Icon(
                CupertinoIcons.plus_circle_fill,
                color: AppStyles.accentBlue,
                size: 24,
              ),
            ),
          ],
        ),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: Consumer<ContactsController>(
        builder: (context, contactsController, child) {
          final contacts = contactsController.contacts;
          final q = _searchQuery.toLowerCase();
          final filtered = q.isEmpty
              ? contacts.toList()
              : contacts.where((c) {
                  return c.name.toLowerCase().contains(q) ||
                      (c.phoneNumber?.toLowerCase().contains(q) ?? false);
                }).toList();
          if (_sortAlpha) {
            filtered.sort((a, b) => a.name.compareTo(b.name));
          }

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
                            _showAddContactOptions(context, contactsController),
                      )
                    : Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.fromLTRB(
                                Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: CupertinoSearchTextField(
                              placeholder: 'Search People',
                              backgroundColor: CupertinoColors.systemFill
                                  .resolveFrom(context),
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                            ),
                          ),
                          Expanded(
                            child: filtered.isEmpty
                                ? EmptyStateView(
                                    icon: CupertinoIcons.search,
                                    title: 'No results',
                                    subtitle:
                                        'No contacts match "$_searchQuery"',
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(Spacing.lg,
                                        Spacing.sm, Spacing.lg, 100),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final contact = filtered[index];
                                      return StaggeredItem(
                                        index: index,
                                        child: _buildContactCard(contact,
                                            context, contactsController),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
              ),
              // Add Button
              Positioned(
                right: Spacing.lg,
                bottom: Spacing.xxxl,
                child: FadingFAB(
                  onPressed: () =>
                      _showAddContactOptions(context, contactsController),
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
        margin: const EdgeInsets.only(bottom: Spacing.md),
        decoration: AppStyles.cardDecoration(context).copyWith(
          border: Border.all(
            color: SemanticColors.contacts
                .withValues(alpha: Opacities.borderSubtle),
            width: 1,
          ),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
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
                  style: const TextStyle(
                    color: SemanticColors.contacts,
                    fontWeight: FontWeight.w600,
                    fontSize: TypeScale.title3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
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
              final deletedContact = contact;
              Haptics.delete();
              controller.removeContact(contact.id);
              toast_lib.toast.showSuccess(
                '"${contact.name}" removed',
                actionLabel: 'Undo',
                onAction: () => controller.addContact(deletedContact),
              );
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

  void _showAddContactOptions(
      BuildContext context, ContactsController controller) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Add Contact'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _showAddContactDialog(context, controller);
            },
            child: const Text('Manual Entry'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _pickFromPhoneContacts(controller);
            },
            child: const Text('From Phone Contacts'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _pickFromPhoneContacts(ContactsController controller) async {
    final permissionStatus = await Permission.contacts.request();
    if (!permissionStatus.isGranted) {
      toast_lib.toast.showError('Contacts permission is required');
      return;
    }

    List<device_contacts.Contact> rawContacts;
    try {
      rawContacts = await device_contacts.FlutterContacts.getContacts(
          withProperties: true);
    } catch (_) {
      toast_lib.toast.showError('Unable to load phone contacts');
      return;
    }
    final seenNames = <String>{};
    final mappedContacts = <Contact>[];
    for (final contact in rawContacts) {
      final name = contact.displayName.trim();
      if (name.isEmpty) continue;
      final normalized = name.toLowerCase();
      if (seenNames.contains(normalized)) continue;
      seenNames.add(normalized);
      final phone =
          contact.phones.isNotEmpty ? contact.phones.first.number.trim() : null;
      mappedContacts.add(
        Contact(
          id: contact.id,
          name: name,
          phoneNumber: phone?.isNotEmpty == true ? phone : null,
          createdDate: DateTime.now(),
        ),
      );
    }
    mappedContacts.sort((a, b) => a.name.compareTo(b.name));

    if (mappedContacts.isEmpty) {
      toast_lib.toast.showInfo('No phone contacts available');
      return;
    }

    if (!mounted) return;
    final selected = await showCupertinoModalPopup<Contact>(
      context: context,
      builder: (ctx) => _PhoneContactsPickerSheet(contacts: mappedContacts),
    );

    if (!mounted || selected == null) return;
    final alreadyExists = controller.contacts.any(
      (contact) => contact.name.toLowerCase() == selected.name.toLowerCase(),
    );
    controller.addContact(selected);
    if (alreadyExists) {
      toast_lib.toast.showInfo('Contact already exists in My People');
      return;
    }
    toast_lib.toast.showSuccess('Added ${selected.name}');
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
            const SizedBox(height: Spacing.lg),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Name',
              maxLength: 60,
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: Spacing.md),
            CupertinoTextField(
              controller: phoneController,
              placeholder: 'Phone Number (Optional)',
              keyboardType: TextInputType.phone,
              padding: const EdgeInsets.all(Spacing.md),
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
              if (nameController.text.trim().isNotEmpty) {
                final contact = Contact(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  phoneNumber: phoneController.text.trim().isNotEmpty
                      ? phoneController.text.trim()
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
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
    });
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
            const SizedBox(height: Spacing.lg),
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Name',
              maxLength: 60,
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: AppStyles.getCardColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: Spacing.md),
            CupertinoTextField(
              controller: phoneController,
              placeholder: 'Phone Number (Optional)',
              keyboardType: TextInputType.phone,
              padding: const EdgeInsets.all(Spacing.md),
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
              if (nameController.text.trim().isNotEmpty) {
                final updatedContact = contact.copyWith(
                  name: nameController.text.trim(),
                  phoneNumber: phoneController.text.trim().isNotEmpty
                      ? phoneController.text.trim()
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
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
    });
  }
}

class _PhoneContactsPickerSheet extends StatefulWidget {
  final List<Contact> contacts;

  const _PhoneContactsPickerSheet({required this.contacts});

  @override
  State<_PhoneContactsPickerSheet> createState() =>
      _PhoneContactsPickerSheetState();
}

class _PhoneContactsPickerSheetState extends State<_PhoneContactsPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredContacts = widget.contacts.where((contact) {
      if (query.isEmpty) return true;
      return contact.name.toLowerCase().contains(query) ||
          (contact.phoneNumber?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: AppStyles.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Phone contacts',
                    style: AppStyles.titleStyle(context)
                        .copyWith(fontSize: TypeScale.title2),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search contacts',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Expanded(
              child: filteredContacts.isEmpty
                  ? Center(
                      child: Text(
                        'No matching contacts',
                        style: TextStyle(
                          color: AppStyles.getSecondaryTextColor(context),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount: filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = filteredContacts[index];
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, contact),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(Spacing.md),
                            decoration: BoxDecoration(
                              color: AppStyles.getBackground(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemBlue
                                        .withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      contact.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: CupertinoColors.systemBlue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Spacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.name,
                                        style: TextStyle(
                                          color:
                                              AppStyles.getTextColor(context),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (contact.phoneNumber?.isNotEmpty ??
                                          false)
                                        Text(
                                          contact.phoneNumber!,
                                          style: TextStyle(
                                            color:
                                                AppStyles.getSecondaryTextColor(
                                                    context),
                                            fontSize: TypeScale.footnote,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(CupertinoIcons.chevron_right),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
