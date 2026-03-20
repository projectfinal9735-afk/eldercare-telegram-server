import 'package:flutter/material.dart';


class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 70,
    this.fontSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 239, 150, 91), // ✅ สีปุ่ม primary
          foregroundColor: Colors.white,     // ✅ สีตัวหนังสือ
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
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
          child: const Text(
            'หากยังไม่มีบัญชี',
            style: TextStyle(color: Colors.white),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onRight,
          child: Text(
            rightText,
            style: TextStyle(
              color: Colors.white, // ✅ ให้ตัดกับพื้นหลังฟ้า
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
