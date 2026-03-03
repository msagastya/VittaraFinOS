import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Comprehensive form validation utilities
class FormValidators {
  FormValidators._();

  /// Validate required field
  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate numeric input
  static String? numeric(
    String? value, {
    String fieldName = 'Value',
    double? min,
    double? max,
    bool allowNegative = false,
    bool required = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$fieldName is required' : null;
    }

    final number = double.tryParse(value.trim());
    if (number == null) {
      return '$fieldName must be a valid number';
    }

    if (!allowNegative && number < 0) {
      return '$fieldName cannot be negative';
    }

    if (min != null && number < min) {
      return '$fieldName must be at least $min';
    }

    if (max != null && number > max) {
      return '$fieldName must not exceed $max';
    }

    return null;
  }

  /// Validate integer input
  static String? integer(
    String? value, {
    String fieldName = 'Value',
    int? min,
    int? max,
    bool allowNegative = false,
    bool required = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$fieldName is required' : null;
    }

    final number = int.tryParse(value.trim());
    if (number == null) {
      return '$fieldName must be a whole number';
    }

    if (!allowNegative && number < 0) {
      return '$fieldName cannot be negative';
    }

    if (min != null && number < min) {
      return '$fieldName must be at least $min';
    }

    if (max != null && number > max) {
      return '$fieldName must not exceed $max';
    }

    return null;
  }

  /// Validate decimal places
  static String? decimalPlaces(
    String? value, {
    String fieldName = 'Value',
    int maxDecimals = 2,
    bool required = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$fieldName is required' : null;
    }

    final number = double.tryParse(value.trim());
    if (number == null) {
      return '$fieldName must be a valid number';
    }

    final parts = value.trim().split('.');
    if (parts.length > 1 && parts[1].length > maxDecimals) {
      return '$fieldName can have maximum $maxDecimals decimal places';
    }

    return null;
  }

  /// Validate currency amount
  static String? currency(
    String? value, {
    String fieldName = 'Amount',
    double? min,
    double? max,
    int maxDecimals = 2,
    bool required = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$fieldName is required' : null;
    }

    // Remove currency symbols and commas
    final cleaned = value.trim().replaceAll(RegExp(r'[₹$,\s]'), '');

    final number = double.tryParse(cleaned);
    if (number == null) {
      return '$fieldName must be a valid amount';
    }

    if (number < 0) {
      return '$fieldName cannot be negative';
    }

    if (min != null && number < min) {
      return '$fieldName must be at least ₹$min';
    }

    if (max != null && number > max) {
      return '$fieldName must not exceed ₹$max';
    }

    // Check decimal places
    final parts = cleaned.split('.');
    if (parts.length > 1 && parts[1].length > maxDecimals) {
      return '$fieldName can have maximum $maxDecimals decimal places';
    }

    return null;
  }

  /// Validate percentage
  static String? percentage(
    String? value, {
    String fieldName = 'Percentage',
    double? min,
    double? max,
    int maxDecimals = 2,
    bool required = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$fieldName is required' : null;
    }

    final cleaned = value.trim().replaceAll('%', '');
    final number = double.tryParse(cleaned);

    if (number == null) {
      return '$fieldName must be a valid percentage';
    }

    if (number < 0) {
      return '$fieldName cannot be negative';
    }

    final minValue = min ?? 0;
    final maxValue = max ?? 100;

    if (number < minValue) {
      return '$fieldName must be at least $minValue%';
    }

    if (number > maxValue) {
      return '$fieldName must not exceed $maxValue%';
    }

    // Check decimal places
    final parts = cleaned.split('.');
    if (parts.length > 1 && parts[1].length > maxDecimals) {
      return '$fieldName can have maximum $maxDecimals decimal places';
    }

    return null;
  }

  /// Validate text length
  static String? textLength(
    String? value, {
    String fieldName = 'Text',
    int? minLength,
    int? maxLength,
    bool required = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$fieldName is required' : null;
    }

    final length = value.trim().length;

    if (minLength != null && length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    if (maxLength != null && length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }

    return null;
  }

  /// Validate email
  static String? email(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Email is required' : null;
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }

  /// Validate phone number (Indian format)
  static String? phoneNumber(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Phone number is required' : null;
    }

    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Indian mobile: 10 digits starting with 6-9
    final mobileRegex = RegExp(r'^[6-9]\d{9}$');

    // With +91 country code
    final withCountryCode = RegExp(r'^\+91[6-9]\d{9}$');

    if (!mobileRegex.hasMatch(cleaned) && !withCountryCode.hasMatch(cleaned)) {
      return 'Enter a valid 10-digit phone number';
    }

    return null;
  }

  /// Validate PAN (Permanent Account Number)
  static String? pan(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'PAN is required' : null;
    }

    final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

    if (!panRegex.hasMatch(value.trim().toUpperCase())) {
      return 'Enter a valid PAN (e.g., ABCDE1234F)';
    }

    return null;
  }

  /// Validate Aadhaar number
  static String? aadhaar(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Aadhaar is required' : null;
    }

    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-]'), '');

    if (cleaned.length != 12 || int.tryParse(cleaned) == null) {
      return 'Enter a valid 12-digit Aadhaar number';
    }

    return null;
  }

  /// Validate IFSC code
  static String? ifsc(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'IFSC code is required' : null;
    }

    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

    if (!ifscRegex.hasMatch(value.trim().toUpperCase())) {
      return 'Enter a valid IFSC code (e.g., SBIN0001234)';
    }

    return null;
  }

  /// Validate date is in the past
  static String? pastDate(
    DateTime? value, {
    String fieldName = 'Date',
    bool required = true,
  }) {
    if (value == null) {
      return required ? '$fieldName is required' : null;
    }

    if (value.isAfter(DateTime.now())) {
      return '$fieldName cannot be in the future';
    }

    return null;
  }

  /// Validate date is in the future
  static String? futureDate(
    DateTime? value, {
    String fieldName = 'Date',
    bool required = true,
  }) {
    if (value == null) {
      return required ? '$fieldName is required' : null;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(value.year, value.month, value.day);

    if (selectedDate.isBefore(today)) {
      return '$fieldName cannot be in the past';
    }

    return null;
  }

  /// Validate date range
  static String? dateRange(
    DateTime? value, {
    String fieldName = 'Date',
    DateTime? minDate,
    DateTime? maxDate,
    bool required = true,
  }) {
    if (value == null) {
      return required ? '$fieldName is required' : null;
    }

    if (minDate != null && value.isBefore(minDate)) {
      return '$fieldName must be after ${_formatDate(minDate)}';
    }

    if (maxDate != null && value.isAfter(maxDate)) {
      return '$fieldName must be before ${_formatDate(maxDate)}';
    }

    return null;
  }

  /// Validate account number
  static String? accountNumber(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Account number is required' : null;
    }

    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-]'), '');

    if (cleaned.length < 9 || cleaned.length > 18) {
      return 'Account number must be 9-18 digits';
    }

    if (int.tryParse(cleaned) == null) {
      return 'Account number must contain only digits';
    }

    return null;
  }

  /// Validate UPI ID
  static String? upiId(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'UPI ID is required' : null;
    }

    final upiRegex = RegExp(r'^[a-zA-Z0-9.\-_]+@[a-zA-Z0-9]+$');

    if (!upiRegex.hasMatch(value.trim())) {
      return 'Enter a valid UPI ID (e.g., user@bank)';
    }

    return null;
  }

  /// Validate GST number
  static String? gstin(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'GSTIN is required' : null;
    }

    final gstRegex = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
    );

    if (!gstRegex.hasMatch(value.trim().toUpperCase())) {
      return 'Enter a valid GSTIN (15 characters)';
    }

    return null;
  }

  /// Validate PIN code
  static String? pinCode(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'PIN code is required' : null;
    }

    final pinRegex = RegExp(r'^[1-9][0-9]{5}$');

    if (!pinRegex.hasMatch(value.trim())) {
      return 'Enter a valid 6-digit PIN code';
    }

    return null;
  }

  /// Composite validator - combines multiple validators
  static String? Function(String?) combine(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }

  /// Format date for error messages
  static String _formatDate(DateTime date) {
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
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Extension on TextEditingController for validation
extension TextEditingControllerValidation on TextEditingController {
  /// Validate with a validator function
  String? validate(String? Function(String?) validator) {
    return validator(text);
  }

  /// Get numeric value with validation
  double? getNumericValue({double? min, double? max}) {
    final error = FormValidators.numeric(
      text,
      min: min,
      max: max,
      required: false,
    );
    if (error != null) return null;
    return double.tryParse(text.trim());
  }

  /// Get currency value with validation
  double? getCurrencyValue({double? min, double? max}) {
    final error = FormValidators.currency(
      text,
      min: min,
      max: max,
      required: false,
    );
    if (error != null) return null;
    final cleaned = text.trim().replaceAll(RegExp(r'[₹$,\s]'), '');
    return double.tryParse(cleaned);
  }
}

/// Form validation helper widget
class ValidatedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String? label;
  final String? placeholder;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool obscureText;
  final Widget? prefix;
  final Widget? suffix;
  final void Function(String)? onChanged;

  const ValidatedTextField({
    super.key,
    required this.controller,
    required this.validator,
    this.label,
    this.placeholder,
    this.keyboardType,
    this.maxLength,
    this.obscureText = false,
    this.prefix,
    this.suffix,
    this.onChanged,
  });

  @override
  State<ValidatedTextField> createState() => _ValidatedTextFieldState();
}

class _ValidatedTextFieldState extends State<ValidatedTextField> {
  String? _errorText;

  void _validate() {
    setState(() {
      _errorText = widget.validator(widget.controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              widget.label!,
              style: const TextStyle(
                fontSize: TypeScale.body,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        CupertinoTextField(
          controller: widget.controller,
          placeholder: widget.placeholder,
          keyboardType: widget.keyboardType,
          maxLength: widget.maxLength,
          obscureText: widget.obscureText,
          prefix: widget.prefix,
          suffix: widget.suffix,
          onChanged: (value) {
            _validate();
            widget.onChanged?.call(value);
          },
          decoration: BoxDecoration(
            border: Border.all(
              color: _errorText != null
                  ? CupertinoColors.systemRed
                  : CupertinoColors.systemGrey4,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        if (_errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 4.0),
            child: Text(
              _errorText!,
              style: const TextStyle(
                fontSize: TypeScale.footnote,
                color: CupertinoColors.systemRed,
              ),
            ),
          ),
      ],
    );
  }
}
