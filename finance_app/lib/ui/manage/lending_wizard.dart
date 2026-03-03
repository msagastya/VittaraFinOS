import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as flutter_contacts;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_model.dart';
import 'package:vittara_fin_os/logic/contact_model.dart' as app_contact;
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

class LendingWizard extends StatefulWidget {
  final LendingType type;
  final Function(LendingBorrowing) onSave;
  final LendingBorrowing? existingRecord;

  const LendingWizard({
    super.key,
    required this.type,
    required this.onSave,
    this.existingRecord,
  });

  @override
  State<LendingWizard> createState() => _LendingWizardState();
}

class _LendingWizardState extends State<LendingWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Form Data
  String? _selectedPersonName;
  String? _selectedPersonId;
  String _selectionMode = 'none'; // 'my-people', 'phone-contacts', 'manual'
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedDueDate;
  List<app_contact.Contact> _phoneContacts = [];
  final List<app_contact.Contact> _filteredPhoneContacts = [];
  bool _loadingPhoneContacts = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate fields if editing existing record
    if (widget.existingRecord != null) {
      final record = widget.existingRecord!;
      _selectedPersonName = record.personName;
      _nameController.text = record.personName;
      _amountController.text = record.amount.toStringAsFixed(0);
      _descriptionController.text = record.description ?? '';
      _selectedDate = record.date;
      _selectedDueDate = record.dueDate;
      _selectionMode = 'manual';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _nextStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep++);
    } else {
      _finishWizard();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _finishWizard() {
    final personName = _selectionMode == 'my-people'
        ? (_selectedPersonName ?? 'Unknown')
        : _selectionMode == 'phone-contacts'
            ? (_selectedPersonName ?? 'Unknown')
            : _nameController.text;
    final phoneNumber =
        _phoneController.text.isNotEmpty ? _phoneController.text : null;

    final record = LendingBorrowing(
      id: widget.existingRecord?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      personName: personName,
      amount: double.parse(_amountController.text),
      type: widget.type,
      description: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null,
      date: _selectedDate,
      dueDate: _selectedDueDate,
      isSettled: widget.existingRecord?.isSettled ?? false,
      settledDate: widget.existingRecord?.settledDate,
    );

    // Auto-save contact if not from 'my-people' mode
    if (_selectionMode != 'my-people') {
      Provider.of<ContactsController>(context, listen: false).addOrGetContact(
        personName,
        phoneNumber: phoneNumber,
      );
    }

    widget.onSave(record);
    Navigator.pop(context);
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        if (_selectionMode == 'my-people') {
          return _selectedPersonId != null;
        } else if (_selectionMode == 'phone-contacts') {
          return _selectedPersonName != null && _selectedPersonName!.isNotEmpty;
        } else if (_selectionMode == 'manual') {
          return _nameController.text.isNotEmpty;
        }
        return false;
      case 1:
        return _amountController.text.isNotEmpty &&
            double.tryParse(_amountController.text) != null;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLent = widget.type == LendingType.lent;
    final color = isLent ? AppStyles.accentBlue : CupertinoColors.systemRed;

    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      resizeToAvoidBottomInset: true,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.existingRecord != null
              ? 'Edit Record'
              : (isLent ? 'Lent Money' : 'Borrowed Money'),
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _prevStep,
          child: Icon(
              _currentStep == 0 ? CupertinoIcons.xmark : CupertinoIcons.back),
        ),
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildProgressBar(color),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPersonSelectionStep(context),
                  _buildAmountStep(context),
                  _buildDescriptionDateStep(context),
                  _buildReviewStep(context, color),
                ],
              ),
            ),
            SingleChildScrollView(
              child: _buildFooter(color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == _totalSteps - 1 ? 0 : 8),
              decoration: BoxDecoration(
                color: isActive
                    ? color
                    : CupertinoColors.systemGrey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPersonSelectionStep(BuildContext context) {
    return Consumer<ContactsController>(
      builder: (context, contactsController, child) {
        final appContacts = contactsController.contacts;

        // Show three options if no selection mode yet
        if (_selectionMode == 'none') {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Who did you ${widget.type == LendingType.lent ? "lend" : "borrow"} from?',
                  style: AppStyles.titleStyle(context)
                      .copyWith(fontSize: TypeScale.largeTitle, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose where to find this person',
                  style: TextStyle(
                      color: AppStyles.getSecondaryTextColor(context),
                      fontSize: TypeScale.body),
                ),
                const SizedBox(height: 40),
                _buildSelectionCard(
                  context,
                  title: 'My People',
                  subtitle: 'Select from saved contacts',
                  icon: CupertinoIcons.person_2_fill,
                  color: AppStyles.accentBlue,
                  onTap: () => setState(() => _selectionMode = 'my-people'),
                  badgeCount: appContacts.length,
                ),
                const SizedBox(height: 16),
                _buildSelectionCard(
                  context,
                  title: 'Phone Contacts',
                  subtitle: 'Browse device contacts',
                  icon: CupertinoIcons.phone_fill,
                  color: CupertinoColors.systemGreen,
                  onTap: () => _loadPhoneContactsAndSelect(),
                ),
                const SizedBox(height: 16),
                _buildSelectionCard(
                  context,
                  title: 'Manual Entry',
                  subtitle: 'Type name and phone',
                  icon: CupertinoIcons.pencil,
                  color: CupertinoColors.systemOrange,
                  onTap: () => setState(() => _selectionMode = 'manual'),
                ),
              ],
            ),
          );
        }

        // Show specific selection based on mode
        if (_selectionMode == 'my-people') {
          return _buildMyPeopleSelection(context, appContacts);
        } else if (_selectionMode == 'phone-contacts') {
          return _buildPhoneContactsSelection(context);
        } else {
          return _buildManualEntrySelection(context);
        }
      },
    );
  }

  Widget _buildSelectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 28, color: color),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: TypeScale.headline,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: TypeScale.footnote,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyPeopleSelection(
      BuildContext context, List<app_contact.Contact> contacts) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectionMode = 'none'),
                child: Icon(CupertinoIcons.back, color: AppStyles.accentBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'My People',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose from your saved contacts',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 24),
          if (contacts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(CupertinoIcons.person_add,
                        size: 48,
                        color: AppStyles.getSecondaryTextColor(context)),
                    const SizedBox(height: 12),
                    Text('No contacts yet',
                        style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context))),
                  ],
                ),
              ),
            )
          else
            Column(
              children: contacts.map((contact) {
                final isSelected = _selectedPersonId == contact.id;
                final contactName =
                    contact.name.isNotEmpty ? contact.name : 'Unknown';
                final firstLetter =
                    contactName.isNotEmpty ? contactName[0].toUpperCase() : '?';
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPersonId = contact.id;
                      _selectedPersonName = contactName;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppStyles.accentBlue
                            : CupertinoColors.systemGrey.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  AppStyles.accentBlue.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                firstLetter,
                                style: const TextStyle(
                                  color: CupertinoColors.systemBlue,
                                  fontWeight: FontWeight.w600,
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
                                      color: AppStyles.getTextColor(context)),
                                ),
                                if (contact.phoneNumber?.isNotEmpty ?? false)
                                  Text(
                                    contact.phoneNumber!,
                                    style: TextStyle(
                                        fontSize: TypeScale.footnote,
                                        color: AppStyles.getSecondaryTextColor(
                                            context)),
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(CupertinoIcons.checkmark,
                                color: CupertinoColors.systemBlue),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneContactsSelection(BuildContext context) {
    // Filter contacts based on search
    final displayContacts = _searchController.text.isEmpty
        ? _phoneContacts
        : _phoneContacts
            .where((contact) =>
                contact.name
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()) ||
                (contact.phoneNumber
                        ?.toLowerCase()
                        .contains(_searchController.text.toLowerCase()) ??
                    false))
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _selectionMode = 'none');
                  _searchController.clear();
                },
                child: Icon(CupertinoIcons.back, color: AppStyles.accentBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Phone Contacts',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select from your device contacts',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 24),
          // Search field
          CupertinoTextField(
            controller: _searchController,
            placeholder: 'Search contacts...',
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(CupertinoIcons.search,
                  color: AppStyles.accentBlue, size: 20),
            ),
            suffix: _searchController.text.isNotEmpty
                ? CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: () => setState(() => _searchController.clear()),
                    child: Icon(CupertinoIcons.xmark_circle_fill,
                        color: AppStyles.getSecondaryTextColor(context),
                        size: 18),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppStyles.accentBlue.withValues(alpha: 0.3),
                  width: 1.5),
            ),
            style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: TypeScale.body),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          if (_loadingPhoneContacts)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: CupertinoActivityIndicator(),
              ),
            )
          else if (_phoneContacts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(CupertinoIcons.phone,
                        size: 48,
                        color: AppStyles.getSecondaryTextColor(context)),
                    const SizedBox(height: 12),
                    Text('No contacts found',
                        style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context))),
                  ],
                ),
              ),
            )
          else if (displayContacts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(CupertinoIcons.search,
                        size: 48,
                        color: AppStyles.getSecondaryTextColor(context)),
                    const SizedBox(height: 12),
                    Text('No contacts match your search',
                        style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context))),
                  ],
                ),
              ),
            )
          else
            Column(
              children: displayContacts.map((contact) {
                final isSelected = _selectedPersonName == contact.name;
                final contactName =
                    contact.name.isNotEmpty ? contact.name : 'Unknown';
                final firstLetter =
                    contactName.isNotEmpty ? contactName[0].toUpperCase() : '?';
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPersonName = contactName;
                      if (contact.phoneNumber?.isNotEmpty ?? false) {
                        _phoneController.text = contact.phoneNumber ?? '';
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.systemGrey
                                .withValues(alpha: 0.15),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? CupertinoColors.systemGreen
                                  .withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.08),
                          blurRadius: isSelected ? 12 : 8,
                          offset: const Offset(0, 2),
                          spreadRadius: isSelected ? 1 : 0,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  CupertinoColors.systemGreen
                                      .withValues(alpha: 0.2),
                                  CupertinoColors.systemGreen
                                      .withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: CupertinoColors.systemGreen
                                    .withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                firstLetter,
                                style: const TextStyle(
                                  color: CupertinoColors.systemGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: TypeScale.title2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  contactName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppStyles.getTextColor(context),
                                    fontSize: TypeScale.callout,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                if (contact.phoneNumber?.isNotEmpty ??
                                    false) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    contact.phoneNumber!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: TypeScale.footnote,
                                      fontWeight: FontWeight.w500,
                                      color: AppStyles.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (isSelected)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: CupertinoColors.systemGreen
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(CupertinoIcons.checkmark,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildManualEntrySelection(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectionMode = 'none'),
                child: Icon(CupertinoIcons.back, color: AppStyles.accentBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Manual Entry',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter person details manually',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 32),
          Text('Person Name', style: AppStyles.headerStyle(context)),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _nameController,
            placeholder: 'Enter person name',
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppStyles.accentBlue.withValues(alpha: 0.2)),
            ),
            style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Text('Mobile Number (Optional)',
              style: AppStyles.headerStyle(context)),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _phoneController,
            placeholder: 'Enter mobile number',
            keyboardType: TextInputType.phone,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppStyles.getCardColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppStyles.accentBlue.withValues(alpha: 0.2)),
            ),
            style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPhoneContactsAndSelect() async {
    setState(() => _loadingPhoneContacts = true);
    try {
      if (await Permission.contacts.request().isGranted) {
        final contacts = await flutter_contacts.FlutterContacts.getContacts(
            withProperties: true);
        setState(() {
          _phoneContacts =
              contacts.where((c) => c.displayName.isNotEmpty).map((c) {
            final phone = c.phones.isNotEmpty ? c.phones.first.number : null;
            return app_contact.Contact(
              id: c.id,
              name: c.displayName,
              phoneNumber: phone,
              createdDate: DateTime.now(),
            );
          }).toList();
          _selectionMode = 'phone-contacts';
        });
      }
    } catch (e) {
      // Error loading contacts
    } finally {
      setState(() => _loadingPhoneContacts = false);
    }
  }

  Widget _buildAmountStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'How much did you ${widget.type == LendingType.lent ? "lend" : "borrow"}?',
            style: AppStyles.titleStyle(context)
                .copyWith(fontSize: TypeScale.largeTitle, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the amount in rupees',
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context), fontSize: TypeScale.body),
          ),
          const SizedBox(height: 64),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '₹',
                  style: AppStyles.titleStyle(context)
                      .copyWith(fontSize: TypeScale.hero, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                IntrinsicWidth(
                  child: CupertinoTextField(
                    controller: _amountController,
                    placeholder: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppStyles.accentBlue.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    style: AppStyles.titleStyle(context).copyWith(
                      fontSize: TypeScale.hero,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_amountController.text.isNotEmpty) {
                        _nextStep();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionDateStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anything else?',
            style: AppStyles.titleStyle(context)
                .copyWith(fontSize: TypeScale.largeTitle, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Add notes and important dates',
            style: TextStyle(
                color: AppStyles.getSecondaryTextColor(context), fontSize: TypeScale.body),
          ),
          const SizedBox(height: 40),

          // Description Box
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What was it for?',
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _descriptionController,
                placeholder: 'e.g. Dinner, Shopping, Flight tickets...',
                maxLines: 3,
                minLines: 2,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppStyles.getBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppStyles.getSecondaryTextColor(context)
                        .withValues(alpha: 0.2),
                  ),
                ),
                style: TextStyle(
                    color: AppStyles.getTextColor(context), fontSize: TypeScale.body),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Transaction Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When did it happen?',
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _selectDate(context, isDueDate: false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.accentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppStyles.accentBlue.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _formatDate(_selectedDate),
                      style: TextStyle(
                        color: AppStyles.accentBlue,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Due Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'When should it be repaid?',
                style: TextStyle(
                  fontSize: TypeScale.headline,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.getTextColor(context),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _selectDate(context, isDueDate: true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (_selectedDueDate == null)
                        ? CupertinoColors.systemGrey.withValues(alpha: 0.1)
                        : CupertinoColors.systemRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (_selectedDueDate == null)
                          ? CupertinoColors.systemGrey.withValues(alpha: 0.3)
                          : CupertinoColors.systemRed.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          _selectedDueDate == null
                              ? '📅 Tap to set'
                              : _formatDate(_selectedDueDate!),
                          style: TextStyle(
                            color: _selectedDueDate == null
                                ? AppStyles.getSecondaryTextColor(context)
                                : CupertinoColors.systemRed,
                            fontSize: _selectedDueDate == null ? 14 : 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (_selectedDueDate == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Optional - leave empty if no deadline',
                              style: TextStyle(
                                color: AppStyles.getSecondaryTextColor(context),
                                fontSize: TypeScale.caption,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(BuildContext context, Color color) {
    final personName = _selectionMode == 'my-people'
        ? (_selectedPersonName ?? 'Unknown')
        : _selectionMode == 'phone-contacts'
            ? (_selectedPersonName ?? 'Unknown')
            : _nameController.text;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirm your details',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
          ),
          const SizedBox(height: 32),
          _buildReviewItem(context, 'Person', personName),
          _buildReviewItem(context, 'Amount', '₹${_amountController.text}'),
          _buildReviewItem(context, 'Date', _formatDate(_selectedDate)),
          if (_selectedDueDate != null)
            _buildReviewItem(
                context, 'Due Date', _formatDate(_selectedDueDate!)),
          if (_descriptionController.text.isNotEmpty)
            _buildReviewItem(
                context, 'Description', _descriptionController.text),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to save?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppStyles.getTextColor(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap Save to add this transaction',
                  style: TextStyle(
                      fontSize: TypeScale.footnote,
                      color: AppStyles.getSecondaryTextColor(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: TypeScale.body,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: TypeScale.body,
              fontWeight: FontWeight.w600,
              color: AppStyles.getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Color color) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
              onPressed: _prevStep,
              child: Text(
                _currentStep == 0 ? 'Close' : 'Back',
                style: TextStyle(
                    color: AppStyles.getTextColor(context),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              color: _canProceed()
                  ? color
                  : CupertinoColors.systemGrey.withValues(alpha: 0.3),
              onPressed: _canProceed() ? _nextStep : null,
              child: Text(
                _currentStep == _totalSteps - 1 ? 'Save' : 'Next',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectDate(BuildContext context, {required bool isDueDate}) async {
    await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) => Container(
        height: 216,
        color: AppStyles.getCardColor(context),
        child: CupertinoDatePicker(
          initialDateTime:
              isDueDate ? (_selectedDueDate ?? DateTime.now()) : _selectedDate,
          mode: CupertinoDatePickerMode.date,
          onDateTimeChanged: (newDate) {
            if (isDueDate) {
              setState(() => _selectedDueDate = newDate);
            } else {
              setState(() => _selectedDate = newDate);
            }
          },
        ),
      ),
    );
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
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }
}
