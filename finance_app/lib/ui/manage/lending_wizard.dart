import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/contacts_controller.dart';
import 'package:vittara_fin_os/logic/lending_borrowing_model.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

class LendingWizard extends StatefulWidget {
  final LendingType type;
  final Function(LendingBorrowing) onSave;

  const LendingWizard({
    super.key,
    required this.type,
    required this.onSave,
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
  bool _useContact = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedDueDate;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _nextStep() {
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
    final personName = _useContact ? (_selectedPersonName ?? 'Unknown') : _nameController.text;
    final record = LendingBorrowing(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      personName: personName,
      amount: double.parse(_amountController.text),
      type: widget.type,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      date: _selectedDate,
      dueDate: _selectedDueDate,
    );
    widget.onSave(record);
    Navigator.pop(context);
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _useContact ? _selectedPersonId != null : _nameController.text.isNotEmpty;
      case 1:
        return _amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null;
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
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isLent ? 'Lent Money' : 'Borrowed Money',
          style: TextStyle(color: AppStyles.getTextColor(context)),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _prevStep,
          child: Icon(_currentStep == 0 ? CupertinoIcons.xmark : CupertinoIcons.back),
        ),
        backgroundColor: AppStyles.getBackground(context),
        border: null,
      ),
      child: SafeArea(
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
            _buildFooter(color),
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
                color: isActive ? color : CupertinoColors.systemGrey.withValues(alpha: 0.2),
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
        final contacts = contactsController.contacts;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Who did you ${widget.type == LendingType.lent ? "lend" : "borrow"} from?',
                style: AppStyles.titleStyle(context).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Select from your contacts or enter manually',
                style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
              ),
              const SizedBox(height: 24),

              // Toggle between Contacts and Manual entry
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useContact = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _useContact ? CupertinoColors.systemBlue.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _useContact ? CupertinoColors.systemBlue : CupertinoColors.systemGrey,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'From Contacts',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _useContact ? CupertinoColors.systemBlue : AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _useContact = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_useContact ? CupertinoColors.systemBlue.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: !_useContact ? CupertinoColors.systemBlue : CupertinoColors.systemGrey,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Manual Entry',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: !_useContact ? CupertinoColors.systemBlue : AppStyles.getSecondaryTextColor(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Contacts List or Manual Entry
              if (_useContact)
                contacts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No contacts yet',
                            style: TextStyle(color: AppStyles.getSecondaryTextColor(context)),
                          ),
                        ),
                      )
                    : Column(
                        children: contacts.map((contact) {
                          final isSelected = _selectedPersonId == contact.id;
                          final contactName = contact.name.isNotEmpty ? contact.name : 'Unknown';
                          final firstLetter = contactName.isNotEmpty ? contactName[0].toUpperCase() : '?';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppStyles.getCardColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? CupertinoColors.systemBlue : CupertinoColors.systemGrey.withValues(alpha: 0.2),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              onPressed: () {
                                setState(() {
                                  _selectedPersonId = contact.id;
                                  _selectedPersonName = contactName;
                                });
                              },
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemBlue.withValues(alpha: 0.15),
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
                                            color: AppStyles.getTextColor(context),
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
                                  if (isSelected)
                                    const Icon(CupertinoIcons.checkmark, color: CupertinoColors.systemBlue),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Person Name', style: AppStyles.headerStyle(context)),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _nameController,
                      placeholder: 'Enter person name',
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      style: TextStyle(color: AppStyles.getTextColor(context)),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Text('Mobile Number (Optional)', style: AppStyles.headerStyle(context)),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _phoneController,
                      placeholder: 'Enter mobile number',
                      keyboardType: TextInputType.phone,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppStyles.getBackground(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      style: TextStyle(color: AppStyles.getTextColor(context)),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmountStep(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'How much did you ${widget.type == LendingType.lent ? "lend" : "borrow"}?',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the amount in rupees',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context), fontSize: 14),
          ),
          const SizedBox(height: 64),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '₹',
                  style: AppStyles.titleStyle(context).copyWith(fontSize: 40, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                IntrinsicWidth(
                  child: CupertinoTextField(
                    controller: _amountController,
                    placeholder: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: BoxDecoration(
                      color: AppStyles.getCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppStyles.accentBlue.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    style: AppStyles.titleStyle(context).copyWith(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anything else?',
            style: AppStyles.titleStyle(context).copyWith(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Add notes and important dates',
            style: TextStyle(color: AppStyles.getSecondaryTextColor(context), fontSize: 14),
          ),
          const SizedBox(height: 40),

          // Description Box
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What was it for?',
                style: TextStyle(
                  fontSize: 16,
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
                    color: AppStyles.getSecondaryTextColor(context).withValues(alpha: 0.2),
                  ),
                ),
                style: TextStyle(color: AppStyles.getTextColor(context), fontSize: 14),
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
                  fontSize: 16,
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
                  fontSize: 16,
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
                          _selectedDueDate == null ? '📅 Tap to set' : _formatDate(_selectedDueDate!),
                          style: TextStyle(
                            color: _selectedDueDate == null ? AppStyles.getSecondaryTextColor(context) : CupertinoColors.systemRed,
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
                                fontSize: 11,
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
    final personName = _useContact ? (_selectedPersonName ?? 'Unknown') : _nameController.text;
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
          if (_selectedDueDate != null) _buildReviewItem(context, 'Due Date', _formatDate(_selectedDueDate!)),
          if (_descriptionController.text.isNotEmpty) _buildReviewItem(context, 'Description', _descriptionController.text),
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
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppStyles.getTextColor(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap Save to add this transaction',
                  style: TextStyle(fontSize: 12, color: AppStyles.getSecondaryTextColor(context)),
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
              fontSize: 14,
              color: AppStyles.getSecondaryTextColor(context),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
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
                style: TextStyle(color: AppStyles.getTextColor(context), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoButton(
              color: _canProceed() ? color : CupertinoColors.systemGrey.withValues(alpha: 0.3),
              onPressed: _canProceed() ? _nextStep : null,
              child: Text(
                _currentStep == _totalSteps - 1 ? 'Save' : 'Next',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
          initialDateTime: isDueDate ? (_selectedDueDate ?? DateTime.now()) : _selectedDate,
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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }
}
