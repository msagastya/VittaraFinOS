import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vittara_fin_os/logic/pin_recovery_controller.dart';
import 'package:vittara_fin_os/logic/settings_controller.dart';
import 'package:vittara_fin_os/ui/recovery_code_save_screen.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

/// Three-step recovery flow:
///   Step 1 — Enter recovery code
///   Step 2 — Set new PIN (if code verified)
///   Step 3 — Nuclear reset (if no code) — triple-confirm
class PinRecoveryScreen extends StatefulWidget {
  const PinRecoveryScreen({super.key});

  @override
  State<PinRecoveryScreen> createState() => _PinRecoveryScreenState();
}

class _PinRecoveryScreenState extends State<PinRecoveryScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _errorText;
  bool _lockedOut = false;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  // New PIN entry after recovery
  bool _showNewPin = false;
  final List<String> _newPinDigits = [];
  final List<String> _confirmPinDigits = [];
  bool _inConfirm = false;
  bool _pinError = false;
  bool _pinSuccess = false;

  // Nuclear reset flow
  bool _showNuclearReset = false;
  int _nuclearStep = 0; // 0=warn, 1=type confirm, 2=countdown
  final _nuclearController = TextEditingController();
  int _countdown = 10;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _checkLockout();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nuclearController.dispose();
    _lockoutTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final locked = await PinRecoveryController.instance.isLockedOut();
    if (locked) {
      final until = await PinRecoveryController.instance.lockoutRemaining();
      if (mounted) {
        setState(() {
          _lockedOut = true;
          _lockoutUntil =
              DateTime.now().add(until ?? const Duration(minutes: 1));
        });
        _startLockoutTimer();
      }
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final remaining = await PinRecoveryController.instance.lockoutRemaining();
      if (remaining == null) {
        setState(() => _lockedOut = false);
        _lockoutTimer?.cancel();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _loading = true;
      _errorText = null;
    });

    final result =
        await PinRecoveryController.instance.verifyRecoveryCode(code);

    if (!mounted) return;
    setState(() => _loading = false);

    switch (result.type) {
      case RecoveryResultType.success:
        Haptics.success();
        setState(() => _showNewPin = true);
      case RecoveryResultType.wrongCode:
        Haptics.error();
        final rem = result.remainingBeforeLockout ?? 0;
        setState(() => _errorText = rem > 0
            ? 'Incorrect code. $rem attempt${rem == 1 ? '' : 's'} before lockout.'
            : 'Incorrect code.');
      case RecoveryResultType.lockedOut:
        Haptics.error();
        setState(() {
          _lockedOut = true;
          _lockoutUntil = result.lockedUntil;
        });
        _startLockoutTimer();
      case RecoveryResultType.noCodeSet:
        setState(() =>
            _errorText = 'No recovery code found. Use the backup restore option below.');
    }
  }

  void _onNewPinDigit(String d) {
    final current = _inConfirm ? _confirmPinDigits : _newPinDigits;
    if (current.length >= 6) return;
    setState(() {
      current.add(d);
      _pinError = false;
    });
    if (current.length == 6) {
      if (!_inConfirm) {
        setState(() => _inConfirm = true);
      } else {
        if (_newPinDigits.join() == _confirmPinDigits.join()) {
          _finalizeReset();
        } else {
          Haptics.error();
          setState(() {
            _pinError = true;
            _confirmPinDigits.clear();
          });
        }
      }
    }
  }

  void _onNewPinBack() {
    final current = _inConfirm ? _confirmPinDigits : _newPinDigits;
    if (current.isEmpty) return;
    setState(() => current.removeLast());
  }

  Future<void> _finalizeReset() async {
    final settings =
        Provider.of<SettingsController>(context, listen: false);
    await settings.resetPinAfterRecovery(_newPinDigits.join());
    // Generate new recovery code
    final newCode =
        await PinRecoveryController.instance.generateAndStoreRecoveryCode();
    if (!mounted) return;
    Haptics.success();
    setState(() => _pinSuccess = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    // Show new recovery code save screen, then unlock
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (_) => _NewCodeAfterRecoveryScreen(
          recoveryCode: newCode,
          onDone: () {
            settings.authenticateAndUnlockWithPin();
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      ),
    );
  }

  void _startNuclearCountdown() {
    setState(() {
      _countdown = 10;
      _nuclearStep = 2;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _executeNuclearReset();
      }
    });
  }

  Future<void> _executeNuclearReset() async {
    final settings =
        Provider.of<SettingsController>(context, listen: false);
    await settings.nuclearReset();
    // Clear SQLite DB
    // The backup_restore_service already has a "reset all data" path — reuse it
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_showNuclearReset) return _buildNuclearReset(context);
    if (_showNewPin) return _buildNewPin(context);
    return _buildCodeEntry(context);
  }

  // ── Screen 1: Enter recovery code ───────────────────────────────────────────

  Widget _buildCodeEntry(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final bg = AppStyles.getBackground(context);
    final textColor = AppStyles.getTextColor(context);
    final subColor = AppStyles.getSecondaryTextColor(context);

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        middle:
            Text('Forgot PIN', style: TextStyle(color: textColor)),
        previousPageTitle: 'Back',
        backgroundColor: bg.withValues(alpha: 0.85),
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: Spacing.xl),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppStyles.aetherTeal.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.lock_open_fill,
                    color: AppStyles.aetherTeal, size: 30),
              ),
              const SizedBox(height: Spacing.xl),
              Text('Enter Recovery Code',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: TypeScale.title2,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  )),
              const SizedBox(height: Spacing.sm),
              Text(
                'Enter the emergency recovery code you saved\nwhen you set up your PIN.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: TypeScale.body, color: subColor, height: 1.5),
              ),
              const SizedBox(height: Spacing.xxl),

              if (_lockedOut) ...[
                _buildLockoutBanner(context),
              ] else ...[
                // Code input field
                CupertinoTextField(
                  controller: _codeController,
                  placeholder: 'VFOS-XXXX-XXXX-XXXX-XXXX-XXXX',
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 16,
                    letterSpacing: 1.5,
                    color: textColor,
                  ),
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: _errorText != null
                        ? Border.all(color: AppStyles.plasmaRed, width: 1.5)
                        : null,
                  ),
                  padding: const EdgeInsets.all(Spacing.md),
                  onChanged: (_) => setState(() => _errorText = null),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: Spacing.sm),
                  Text(_errorText!,
                      style: const TextStyle(
                          color: AppStyles.plasmaRed,
                          fontSize: TypeScale.caption)),
                ],
                const SizedBox(height: Spacing.xl),

                // Verify button
                BouncyButton(
                  onPressed: _loading ? () {} : _verifyCode,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        AppStyles.aetherTeal,
                        AppStyles.novaPurple,
                      ]),
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                    child: Center(
                      child: _loading
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : const Text('Verify & Reset PIN',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: TypeScale.body,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: Spacing.xxl),
              _buildDivider(subColor),
              const SizedBox(height: Spacing.xl),

              // No recovery code section
              Text('Lost your recovery code?',
                  style: TextStyle(
                      fontSize: TypeScale.subhead,
                      color: subColor,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: Spacing.sm),
              Text(
                'If you have a backup file, restore it after reinstalling the app.\nOtherwise you can erase all data and start fresh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: TypeScale.caption, color: subColor, height: 1.5),
              ),
              const SizedBox(height: Spacing.lg),
              BouncyButton(
                onPressed: () =>
                    setState(() => _showNuclearReset = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.xl, vertical: Spacing.sm + 2),
                  decoration: BoxDecoration(
                    color: AppStyles.plasmaRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(Radii.full),
                    border: Border.all(
                        color: AppStyles.plasmaRed.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Erase All Data & Start Fresh',
                      style: TextStyle(
                          color: AppStyles.plasmaRed,
                          fontSize: TypeScale.subhead,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: Spacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockoutBanner(BuildContext context) {
    final subColor = AppStyles.getSecondaryTextColor(context);
    return FutureBuilder<Duration?>(
      future: PinRecoveryController.instance.lockoutRemaining(),
      builder: (context, snap) {
        final rem = snap.data;
        final mins = rem?.inMinutes ?? 0;
        final secs = (rem?.inSeconds ?? 0) % 60;
        final label = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            color: AppStyles.plasmaRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(
                color: AppStyles.plasmaRed.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              const Icon(CupertinoIcons.lock_fill,
                  color: AppStyles.plasmaRed, size: 28),
              const SizedBox(height: Spacing.sm),
              const Text('Too many wrong attempts',
                  style: TextStyle(
                      color: AppStyles.plasmaRed,
                      fontWeight: FontWeight.w700,
                      fontSize: TypeScale.subhead)),
              const SizedBox(height: 4),
              Text('Try again in $label',
                  style:
                      TextStyle(color: subColor, fontSize: TypeScale.caption)),
            ],
          ),
        );
      },
    );
  }

  // ── Screen 2: Set new PIN ────────────────────────────────────────────────────

  Widget _buildNewPin(BuildContext context) {
    final bg = AppStyles.getBackground(context);
    final textColor = AppStyles.getTextColor(context);
    final subColor = AppStyles.getSecondaryTextColor(context);
    final isDark = AppStyles.isDarkMode(context);
    final current = _inConfirm ? _confirmPinDigits : _newPinDigits;
    final dotColor = _pinError ? AppStyles.plasmaRed : AppStyles.aetherTeal;

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        middle:
            Text('Set New PIN', style: TextStyle(color: textColor)),
        previousPageTitle: 'Back',
        backgroundColor: bg.withValues(alpha: 0.85),
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(CupertinoIcons.number_square_fill,
                size: 40, color: AppStyles.aetherTeal),
            const SizedBox(height: Spacing.md),
            Text(
              _pinSuccess
                  ? 'PIN Set!'
                  : _inConfirm
                      ? 'Confirm New PIN'
                      : 'Set New PIN',
              style: TextStyle(
                color: textColor,
                fontSize: TypeScale.title2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              _pinError
                  ? 'PINs do not match. Try again.'
                  : _inConfirm
                      ? 'Re-enter your 6-digit PIN'
                      : 'Choose a 6-digit PIN',
              style: TextStyle(
                color: _pinError ? AppStyles.plasmaRed : subColor,
                fontSize: TypeScale.body,
              ),
            ),
            const SizedBox(height: Spacing.xxl),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < current.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? dotColor : Colors.transparent,
                    border: Border.all(color: dotColor, width: 1.5),
                  ),
                );
              }),
            ),
            const Spacer(),
            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: Spacing.lg),
              child: Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['', '0', '⌫'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((label) {
                          if (label.isEmpty) return const SizedBox(width: 72);
                          return GestureDetector(
                            onTap: () => label == '⌫'
                                ? _onNewPinBack()
                                : _onNewPinDigit(label),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppStyles.getCardColor(context),
                              ),
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Screen 3: Nuclear reset ──────────────────────────────────────────────────

  Widget _buildNuclearReset(BuildContext context) {
    final bg = AppStyles.getBackground(context);
    final textColor = AppStyles.getTextColor(context);
    final subColor = AppStyles.getSecondaryTextColor(context);
    final isDark = AppStyles.isDarkMode(context);

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        middle: Text('Erase All Data', style: TextStyle(color: textColor)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => setState(() {
            _showNuclearReset = false;
            _nuclearStep = 0;
            _nuclearController.clear();
            _countdownTimer?.cancel();
          }),
          child: const Text('Cancel',
              style: TextStyle(color: AppStyles.aetherTeal)),
        ),
        backgroundColor: bg.withValues(alpha: 0.85),
        border: null,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: Spacing.xl),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppStyles.plasmaRed.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                    color: AppStyles.plasmaRed, size: 36),
              ),
              const SizedBox(height: Spacing.xl),

              if (_nuclearStep == 0) ...[
                Text('This Will Delete\nEverything',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: TypeScale.title2,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    )),
                const SizedBox(height: Spacing.md),
                Text(
                  'All your accounts, transactions, investments, goals, budgets, and settings will be permanently deleted.\n\nThis CANNOT be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: TypeScale.body,
                      color: subColor,
                      height: 1.5),
                ),
                const Spacer(),
                BouncyButton(
                  onPressed: () => setState(() => _nuclearStep = 1),
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppStyles.plasmaRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Radii.full),
                      border: Border.all(
                          color: AppStyles.plasmaRed.withValues(alpha: 0.4)),
                    ),
                    child: const Center(
                      child: Text('I Understand — Continue',
                          style: TextStyle(
                              color: AppStyles.plasmaRed,
                              fontSize: TypeScale.body,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ] else if (_nuclearStep == 1) ...[
                Text('Type to Confirm',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: TypeScale.title2,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    )),
                const SizedBox(height: Spacing.md),
                Text(
                  'Type  DELETE MY DATA  below to confirm you want to erase everything.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: TypeScale.body,
                      color: subColor,
                      height: 1.5),
                ),
                const SizedBox(height: Spacing.xxl),
                CupertinoTextField(
                  controller: _nuclearController,
                  placeholder: 'DELETE MY DATA',
                  style: TextStyle(
                      color: textColor,
                      fontSize: TypeScale.body,
                      letterSpacing: 1),
                  textAlign: TextAlign.center,
                  decoration: BoxDecoration(
                    color: AppStyles.getCardColor(context),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  padding: const EdgeInsets.all(Spacing.md),
                  onChanged: (v) => setState(() {}),
                ),
                const Spacer(),
                BouncyButton(
                  onPressed:
                      _nuclearController.text.trim() == 'DELETE MY DATA'
                          ? _startNuclearCountdown
                          : () {},
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _nuclearController.text.trim() == 'DELETE MY DATA'
                          ? AppStyles.plasmaRed
                          : AppStyles.plasmaRed.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                    child: Center(
                      child: Text('Erase All Data',
                          style: TextStyle(
                              color: _nuclearController.text.trim() ==
                                      'DELETE MY DATA'
                                  ? Colors.white
                                  : AppStyles.plasmaRed.withValues(alpha: 0.4),
                              fontSize: TypeScale.body,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ] else ...[
                // Countdown
                Text('Deleting in...',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: TypeScale.title2,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    )),
                const SizedBox(height: Spacing.xxl),
                Text(
                  '$_countdown',
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 80,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.plasmaRed,
                  ),
                ),
                const SizedBox(height: Spacing.xl),
                Text('seconds',
                    style: TextStyle(color: subColor, fontSize: TypeScale.body)),
                const Spacer(),
                BouncyButton(
                  onPressed: () {
                    _countdownTimer?.cancel();
                    setState(() {
                      _showNuclearReset = false;
                      _nuclearStep = 0;
                      _nuclearController.clear();
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: subColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                    child: Center(
                      child: Text('Cancel — Stop Deletion',
                          style: TextStyle(
                              color: textColor,
                              fontSize: TypeScale.body,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.15))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          child: Text('or',
              style: TextStyle(color: color, fontSize: TypeScale.caption)),
        ),
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.15))),
      ],
    );
  }
}

// ── Helper screen: show new recovery code after reset ─────────────────────────

class _NewCodeAfterRecoveryScreen extends StatefulWidget {
  final String recoveryCode;
  final VoidCallback onDone;

  const _NewCodeAfterRecoveryScreen(
      {required this.recoveryCode, required this.onDone});

  @override
  State<_NewCodeAfterRecoveryScreen> createState() =>
      _NewCodeAfterRecoveryScreenState();
}

class _NewCodeAfterRecoveryScreenState
    extends State<_NewCodeAfterRecoveryScreen> {
  @override
  Widget build(BuildContext context) {
    return RecoveryCodeSaveScreen(
      recoveryCode: widget.recoveryCode,
      onConfirmed: widget.onDone,
    );
  }
}

