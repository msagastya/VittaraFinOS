import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/contact_model.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';
import 'package:vittara_fin_os/ui/widgets/common_widgets.dart';
import 'package:vittara_fin_os/utils/id_generator.dart';

class BillSplitScreen extends StatefulWidget {
  const BillSplitScreen({super.key});

  @override
  State<BillSplitScreen> createState() => _BillSplitScreenState();
}

class _BillSplitScreenState extends State<BillSplitScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _newContactController = TextEditingController();

  final Set<String> _selectedContactIds = {};
  bool _equalSplit = true;
  final Map<String, TextEditingController> _percentControllers = {};
  bool _submitted = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _newContactController.dispose();
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalAmount =>
      double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  List<Contact> get _selectedContacts {
    final contacts =
        Provider.of<ContactsController>(context, listen: false).contacts;
    return contacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();
  }

  double _percentForContact(String id) {
    if (_equalSplit) {
      return _selectedContactIds.isEmpty
          ? 0
          : 100 / _selectedContactIds.length;
    }
    return double.tryParse(_percentControllers[id]?.text ?? '0') ?? 0;
  }

  double get _totalPercent {
    if (_equalSplit) return 100;
    return _selectedContactIds.fold(
        0, (sum, id) => sum + _percentForContact(id));
  }

  bool get _canCreate {
    if (_totalAmount <= 0) return false;
    if (_selectedContactIds.isEmpty) return false;
    if (!_equalSplit) {
      final total = _totalPercent;
      return (total - 100).abs() < 0.01;
    }
    return true;
  }

  void _toggleContact(String id) {
    setState(() {
      if (_selectedContactIds.contains(id)) {
        _selectedContactIds.remove(id);
        _percentControllers[id]?.dispose();
        _percentControllers.remove(id);
      } else {
        _selectedContactIds.add(id);
        if (!_equalSplit) {
          _percentControllers[id] = TextEditingController();
        }
      }
    });
  }

  void _toggleEqualSplit(bool val) {
    setState(() {
      _equalSplit = val;
      if (!val) {
        // Initialise percent controllers for selected contacts
        for (final id in _selectedContactIds) {
          _percentControllers.putIfAbsent(
              id, () => TextEditingController());
        }
      }
    });
  }

  void _createSplit() {
    setState(() => _submitted = true);
    if (!_canCreate) return;

    final controller =
        Provider.of<LendingBorrowingController>(context, listen: false);
    final contacts = _selectedContacts;
    final now = DateTime.now();

    final List<Map<String, dynamic>> summary = [];

    for (final contact in contacts) {
      final pct = _percentForContact(contact.id);
      final share = _totalAmount * pct / 100;

      final record = LendingBorrowing(
        id: IdGenerator.next(),
        personName: contact.name,
        amount: share,
        type: LendingType.lent,
        description: _descriptionController.text.trim().isEmpty
            ? 'Bill split'
            : _descriptionController.text.trim(),
        date: now,
      );
      controller.addRecord(record);
      summary.add({'name': contact.name, 'amount': share});
    }

    _showSummarySheet(summary);
  }

  void _showSummarySheet(List<Map<String, dynamic>> summary) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(ctx),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
        padding: const EdgeInsets.all(Spacing.xl),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ModalHandle(),
              const SizedBox(height: Spacing.lg),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(Spacing.sm),
                    decoration: AppStyles.iconBoxDecoration(
                        ctx, SemanticColors.success),
                    child: const Icon(CupertinoIcons.checkmark_circle_fill,
                        color: SemanticColors.success, size: 22),
                  ),
                  const SizedBox(width: Spacing.md),
                  Text(
                    'Split Created!',
                    style: TextStyle(
                      color: AppStyles.getTextColor(ctx),
                      fontSize: TypeScale.title2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'You paid ₹${_totalAmount.toStringAsFixed(0)} — here\'s the breakdown:',
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(ctx),
                  fontSize: TypeScale.body,
                ),
              ),
              const SizedBox(height: Spacing.xl),
              ...summary.map((item) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: Spacing.md),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.person_circle,
                            color: SemanticColors.lending, size: 20),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Text(
                            item['name'] as String,
                            style: TextStyle(
                              color: AppStyles.getTextColor(ctx),
                              fontSize: TypeScale.body,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          'owes you ₹${(item['amount'] as double).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: SemanticColors.lending,
                            fontSize: TypeScale.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: Spacing.xl),
              SizedBox(
                width: double.infinity,
                child: BouncyButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: Spacing.md),
                    decoration: BoxDecoration(
                      color: SemanticColors.lending,
                      borderRadius: Radii.buttonRadius,
                    ),
                    child: const Center(
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewContact(BuildContext ctx) {
    final name = _newContactController.text.trim();
    if (name.isEmpty) return;
    final contactsController =
        Provider.of<ContactsController>(ctx, listen: false);
    contactsController.addOrGetContact(name);
    final contact = contactsController.getContactByName(name);
    if (contact != null) {
      _toggleContact(contact.id);
    }
    _newContactController.clear();
    Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppStyles.getBackground(context),
      navigationBar: AppStyles.isLandscape(context) ? null : CupertinoNavigationBar(
        middle: Text('Split Bill',
            style: TextStyle(color: AppStyles.getTextColor(context))),
        previousPageTitle: 'Back',
        backgroundColor: AppStyles.getBackground(context),
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _canCreate ? _createSplit : null,
          child: Text(
            'Create',
            style: TextStyle(
              color: _canCreate
                  ? SemanticColors.lending
                  : AppStyles.getSecondaryTextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount & description
              _buildSectionHeader('Bill Details'),
              Container(
                decoration: AppStyles.cardDecoration(context),
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  children: [
                    _buildAmountField(),
                    _buildDivider(),
                    _buildDescriptionField(),
                  ],
                ),
              ),

              const SizedBox(height: Spacing.xxl),

              // Participants
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('Participants'),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showAddContactSheet(),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.add_circled,
                            color: SemanticColors.lending, size: 18),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: SemanticColors.lending,
                            fontSize: TypeScale.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Consumer<ContactsController>(
                builder: (ctx, contactsCtrl, _) {
                  final contacts = contactsCtrl.contacts;
                  if (contacts.isEmpty) {
                    return Container(
                      decoration: AppStyles.cardDecoration(context),
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: Center(
                        child: Text(
                          'No contacts yet. Tap "Add" to create one.',
                          style: TextStyle(
                            color: AppStyles.getSecondaryTextColor(context),
                            fontSize: TypeScale.body,
                          ),
                        ),
                      ),
                    );
                  }
                  return Container(
                    decoration: AppStyles.cardDecoration(context),
                    child: Column(
                      children: contacts.asMap().entries.map((entry) {
                        final i = entry.key;
                        final contact = entry.value;
                        final selected =
                            _selectedContactIds.contains(contact.id);
                        return Column(
                          children: [
                            if (i > 0) _buildDivider(),
                            _buildContactRow(contact, selected),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),

              if (_submitted && _selectedContactIds.isEmpty) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  'Select at least one participant.',
                  style: TextStyle(
                    color: AppStyles.loss(context),
                    fontSize: TypeScale.caption,
                  ),
                ),
              ],

              const SizedBox(height: Spacing.xxl),

              // Split type
              _buildSectionHeader('Split Type'),
              Container(
                decoration: AppStyles.cardDecoration(context),
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg, vertical: Spacing.md),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.equal_circle,
                        color: SemanticColors.lending, size: 22),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Text('Equal Split',
                          style: AppStyles.titleStyle(context)),
                    ),
                    CupertinoSwitch(
                      value: _equalSplit,
                      activeTrackColor: SemanticColors.lending,
                      onChanged: _toggleEqualSplit,
                    ),
                  ],
                ),
              ),

              // Custom % inputs when not equal
              if (!_equalSplit && _selectedContactIds.isNotEmpty) ...[
                const SizedBox(height: Spacing.lg),
                _buildSectionHeader('Custom Percentages'),
                Container(
                  decoration: AppStyles.cardDecoration(context),
                  child: Column(
                    children: _selectedContacts.asMap().entries.map((entry) {
                      final i = entry.key;
                      final contact = entry.value;
                      return Column(
                        children: [
                          if (i > 0) _buildDivider(),
                          _buildCustomPercentRow(contact),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: ${_totalPercent.toStringAsFixed(1)}%'
                    '${(_totalPercent - 100).abs() < 0.01 ? ' ✓' : ' (must equal 100%)'}',
                    style: TextStyle(
                      color: (_totalPercent - 100).abs() < 0.01
                          ? SemanticColors.success
                          : AppStyles.loss(context),
                      fontSize: TypeScale.caption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              // Preview
              if (_totalAmount > 0 && _selectedContactIds.isNotEmpty) ...[
                const SizedBox(height: Spacing.xxl),
                _buildSectionHeader('Preview'),
                Container(
                  decoration: AppStyles.cardDecoration(context),
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You paid ₹${_totalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: AppStyles.getTextColor(context),
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      ..._selectedContacts.map((c) {
                        final pct = _percentForContact(c.id);
                        final share = _totalAmount * pct / 100;
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: Spacing.sm),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.arrow_right,
                                  size: 14, color: SemanticColors.lending),
                              const SizedBox(width: Spacing.sm),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: TextStyle(
                                      color:
                                          AppStyles.getTextColor(context),
                                      fontSize: TypeScale.body),
                                ),
                              ),
                              Text(
                                'owes ₹${share.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: SemanticColors.lending,
                                    fontSize: TypeScale.body,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: Spacing.xxxl),

              // Create button
              SizedBox(
                width: double.infinity,
                child: BouncyButton(
                  onPressed: _createSplit,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: Spacing.lg),
                    decoration: BoxDecoration(
                      color: _canCreate
                          ? SemanticColors.lending
                          : AppStyles.getSecondaryTextColor(context)
                              .withValues(alpha: 0.3),
                      borderRadius: Radii.buttonRadius,
                    ),
                    child: Center(
                      child: Text(
                        'Create Split',
                        style: TextStyle(
                          color: _canCreate
                              ? Colors.white
                              : AppStyles.getSecondaryTextColor(context),
                          fontSize: TypeScale.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: Spacing.sm),
      child: Text(
        title.toUpperCase(),
        style: AppStyles.headerStyle(context),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        height: 0.5,
        color: AppStyles.isDarkMode(context)
            ? const Color(0xFF2C2C2E)
            : CupertinoColors.systemGrey5,
      ),
    );
  }

  Widget _buildAmountField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        children: [
          Text(
            '₹',
            style: TextStyle(
              color: SemanticColors.lending,
              fontSize: TypeScale.title2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: CupertinoTextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9,.]'))
              ],
              placeholder: 'Total amount paid by you',
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontSize: TypeScale.title3,
                fontWeight: FontWeight.w600,
              ),
              placeholderStyle: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.body,
              ),
              decoration: const BoxDecoration(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_submitted && _totalAmount <= 0)
            Icon(CupertinoIcons.exclamationmark_circle,
                color: AppStyles.loss(context), size: 18),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: CupertinoTextField(
        controller: _descriptionController,
        placeholder: 'Description (e.g., Dinner, Trip, Groceries)',
        style:
            TextStyle(color: AppStyles.getTextColor(context), fontSize: TypeScale.body),
        placeholderStyle: TextStyle(
          color: AppStyles.getSecondaryTextColor(context),
          fontSize: TypeScale.body,
        ),
        decoration: const BoxDecoration(),
      ),
    );
  }

  Widget _buildContactRow(Contact contact, bool selected) {
    return BouncyButton(
      scaleFactor: 0.98,
      onPressed: () => _toggleContact(contact.id),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SemanticColors.lending.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  contact.name.isNotEmpty
                      ? contact.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: SemanticColors.lending,
                    fontWeight: FontWeight.bold,
                    fontSize: TypeScale.body,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                      style: AppStyles.titleStyle(context)),
                  if (contact.phoneNumber != null)
                    Text(
                      contact.phoneNumber!,
                      style: TextStyle(
                        color: AppStyles.getSecondaryTextColor(context),
                        fontSize: TypeScale.caption,
                      ),
                    ),
                ],
              ),
            ),
            CupertinoCheckbox(
              value: selected,
              activeColor: SemanticColors.lending,
              onChanged: (_) => _toggleContact(contact.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomPercentRow(Contact contact) {
    final ctrl = _percentControllers[contact.id] ??
        (_percentControllers[contact.id] = TextEditingController());
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg, vertical: Spacing.md),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SemanticColors.lending.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                contact.name.isNotEmpty
                    ? contact.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: SemanticColors.lending,
                  fontWeight: FontWeight.bold,
                  fontSize: TypeScale.caption,
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(contact.name,
                style: AppStyles.titleStyle(context)),
          ),
          SizedBox(
            width: 80,
            child: CupertinoTextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              placeholder: '0',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppStyles.getTextColor(context),
                fontSize: TypeScale.body,
                fontWeight: FontWeight.w600,
              ),
              placeholderStyle: TextStyle(
                color: AppStyles.getSecondaryTextColor(context),
                fontSize: TypeScale.body,
              ),
              suffix: Text(
                '%',
                style: TextStyle(
                  color: AppStyles.getSecondaryTextColor(context),
                  fontSize: TypeScale.body,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddContactSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppStyles.getCardColor(ctx),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
        padding: EdgeInsets.only(
          left: Spacing.xl,
          right: Spacing.xl,
          top: Spacing.xl,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + Spacing.xl,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ModalHandle(),
              const SizedBox(height: Spacing.lg),
              Text(
                'Add New Contact',
                style: TextStyle(
                  color: AppStyles.getTextColor(ctx),
                  fontSize: TypeScale.title2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              CupertinoTextField(
                controller: _newContactController,
                autofocus: true,
                placeholder: 'Contact name',
                style: TextStyle(
                  color: AppStyles.getTextColor(ctx),
                  fontSize: TypeScale.body,
                ),
                placeholderStyle: TextStyle(
                  color: AppStyles.getSecondaryTextColor(ctx),
                  fontSize: TypeScale.body,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: Spacing.md),
                decoration: BoxDecoration(
                  color: AppStyles.isDarkMode(ctx)
                      ? const Color(0xFF2C2C2E)
                      : CupertinoColors.systemGrey6,
                  borderRadius: Radii.inputRadius,
                ),
              ),
              const SizedBox(height: Spacing.lg),
              SizedBox(
                width: double.infinity,
                child: BouncyButton(
                  onPressed: () => _addNewContact(ctx),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: Spacing.md),
                    decoration: BoxDecoration(
                      color: SemanticColors.lending,
                      borderRadius: Radii.buttonRadius,
                    ),
                    child: const Center(
                      child: Text(
                        'Add Contact',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: TypeScale.body,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
