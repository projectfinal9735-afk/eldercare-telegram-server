import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 72,
    this.fontSize = 24,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    if (widget.onPressed == null) return;
    setState(() => _scale = pressed ? 0.98 : 1.0);
  }

  void _handlePressed() {
    if (widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    widget.onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.card,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
              disabledForegroundColor: AppColors.card70,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: enabled ? _handlePressed : null,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w800,
                color: AppColors.card,
                letterSpacing: _scale < 1 ? 0.2 : 0,
              ),
              child: Text(widget.text, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

class LinkRow extends StatelessWidget {
  final String leftText;
  final VoidCallback onLeft;
  final String rightText;
  final VoidCallback onRight;

  const LinkRow({
    super.key,
    required this.leftText,
    required this.onLeft,
    required this.rightText,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: onLeft,
          child: Text(
            leftText,
            style: const TextStyle(color: AppColors.primary, fontSize: 26),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onRight,
          child: Text(
            rightText,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
