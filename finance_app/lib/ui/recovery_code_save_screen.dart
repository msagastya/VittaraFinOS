import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

/// Shown ONCE after the user sets their PIN.
/// Displays the emergency recovery code with instructions to save it.
class RecoveryCodeSaveScreen extends StatefulWidget {
  final String recoveryCode;
  final VoidCallback onConfirmed;

  const RecoveryCodeSaveScreen({
    super.key,
    required this.recoveryCode,
    required this.onConfirmed,
  });

  @override
  State<RecoveryCodeSaveScreen> createState() => _RecoveryCodeSaveScreenState();
}

class _RecoveryCodeSaveScreenState extends State<RecoveryCodeSaveScreen> {
  bool _copied = false;
  bool _confirmed = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.recoveryCode));
    setState(() => _copied = true);
    Haptics.medium();
    // Auto-clear clipboard after 60 seconds
    Future.delayed(const Duration(seconds: 60), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    final bg = AppStyles.getBackground(context);
    final textColor = AppStyles.getTextColor(context);
    final subColor = AppStyles.getSecondaryTextColor(context);
    final parts = widget.recoveryCode.split('-');

    return CupertinoPageScaffold(
      backgroundColor: bg,
      navigationBar: CupertinoNavigationBar(
        middle: Text('Recovery Code',
            style: TextStyle(color: textColor)),
        backgroundColor: bg.withValues(alpha: 0.85),
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Warning icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppStyles.gold(context).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.shield_lefthalf_fill,
                    color: AppStyles.gold(context), size: 36),
              ),
              const SizedBox(height: Spacing.xl),

              Text(
                'Save Your\nRecovery Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: TypeScale.title1,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: Spacing.md),

              Text(
                'If you forget your PIN and biometric is unavailable,\nthis code is the ONLY way to recover your data.\nWrite it down and store it somewhere safe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: TypeScale.body,
                  color: subColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: Spacing.xxl),

              // Recovery code display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.xl),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppStyles.gold(context).withValues(alpha: 0.06)
                      : AppStyles.gold(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Radii.xxl),
                  border: Border.all(
                    color: AppStyles.gold(context).withValues(alpha: 0.30),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'EMERGENCY RECOVERY CODE',
                      style: TextStyle(
                        fontSize: TypeScale.caption,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: AppStyles.gold(context),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    // Code in groups for readability
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: parts.map((part) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppStyles.gold(context).withValues(alpha: 0.10)
                              : AppStyles.gold(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          part,
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: textColor,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: Spacing.lg),
                    // Copy button
                    BouncyButton(
                      onPressed: _copy,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.xl, vertical: Spacing.sm),
                        decoration: BoxDecoration(
                          color: _copied
                              ? AppStyles.gain(context).withValues(alpha: 0.15)
                              : AppStyles.gold(context).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _copied
                                ? AppStyles.gain(context).withValues(alpha: 0.5)
                                : AppStyles.gold(context).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _copied
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.doc_on_doc,
                              size: 16,
                              color: _copied ? AppStyles.gain(context) : AppStyles.gold(context),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _copied ? 'Copied!' : 'Copy to Clipboard',
                              style: TextStyle(
                                fontSize: TypeScale.subhead,
                                fontWeight: FontWeight.w600,
                                color: _copied ? AppStyles.gain(context) : AppStyles.gold(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // Warning boxes
              _warningBox(
                context,
                icon: CupertinoIcons.eye_slash_fill,
                color: AppStyles.loss(context),
                text: 'This code will NOT be shown again. Screenshot it or write it on paper NOW.',
              ),
              const SizedBox(height: Spacing.md),
              _warningBox(
                context,
                icon: CupertinoIcons.device_phone_portrait,
                color: subColor,
                text: 'Do not save this only on this device — if you lose the phone, you lose access.',
              ),
              const SizedBox(height: Spacing.xxl),

              // Confirmation checkbox
              GestureDetector(
                onTap: () {
                  setState(() => _confirmed = !_confirmed);
                  Haptics.light();
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: AppDurations.fast,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _confirmed
                            ? AppStyles.gain(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _confirmed
                              ? AppStyles.gain(context)
                              : subColor.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: _confirmed
                          ? const Icon(CupertinoIcons.checkmark,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Text(
                        'I have saved my recovery code in a safe place and understand it cannot be recovered if lost.',
                        style: TextStyle(
                          fontSize: TypeScale.subhead,
                          color: subColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xxl),

              // Continue button
              BouncyButton(
                onPressed: _confirmed ? widget.onConfirmed : () {},
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: _confirmed
                        ? LinearGradient(colors: [
                            AppStyles.gain(context),
                            AppStyles.teal(context),
                          ])
                        : null,
                    color: _confirmed ? null : subColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.full),
                  ),
                  child: Center(
                    child: Text(
                      'I\'ve Saved It — Continue',
                      style: TextStyle(
                        fontSize: TypeScale.body,
                        fontWeight: FontWeight.w600,
                        color: _confirmed ? Colors.white : subColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _warningBox(BuildContext context,
      {required IconData icon,
      required Color color,
      required String text}) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: TypeScale.subhead,
                color: AppStyles.getSecondaryTextColor(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
