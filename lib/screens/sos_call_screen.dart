import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SosCallScreen extends StatefulWidget {
  final String caregiverName;
  final String caregiverPhone;

  const SosCallScreen({
    super.key,
    required this.caregiverName,
    required this.caregiverPhone,
  });

  @override
  State<SosCallScreen> createState() => _SosCallScreenState();
}

class _SosCallScreenState extends State<SosCallScreen> {
  bool _triedAutoCall = false;
  bool _launchingCall = false;

  @override
  void initState() {
    super.initState();
    _playEmergencyFeedback();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoCallOnce();
    });
  }

  Future<void> _playEmergencyFeedback() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    await HapticFeedback.heavyImpact();
  }

  Future<void> _autoCallOnce() async {
    if (_triedAutoCall) return;
    _triedAutoCall = true;
    await _callCaregiver();
  }

  Future<void> _callCaregiver() async {
    final phone = widget.caregiverPhone.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบเบอร์โทรของผู้ดูแล')),
      );
      return;
    }

    if (_launchingCall) return;
    setState(() => _launchingCall = true);

    try {
      await HapticFeedback.heavyImpact();
      await launchUrl(
        Uri.parse('tel:$phone'),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิดหน้าโทรได้')),
      );
    } finally {
      if (mounted) {
        setState(() => _launchingCall = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = widget.caregiverPhone.trim().isNotEmpty;
    final caregiverName = widget.caregiverName.trim().isEmpty
        ? 'ผู้ดูแล'
        : widget.caregiverName.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF1ECEC),
      appBar: AppBar(
        title: const Text('โหมดฉุกเฉิน'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: AppColors.card,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 8,
                color: AppColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.shade200, width: 2),
                        ),
                        child: Icon(
                          Icons.sos_rounded,
                          size: 48,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'ส่งสัญญาณฉุกเฉินแล้ว',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.red.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ระบบกำลังติดต่อผู้ดูแลทันที',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3ECFA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              caregiverName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              hasPhone ? widget.caregiverPhone : 'ไม่พบเบอร์โทรผู้ดูแล',
                              style: TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                color: hasPhone ? AppColors.text : Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hasPhone
                            ? 'ระบบได้ส่ง SOS แจ้ง LINE และพยายามเปิดหน้าโทรให้อัตโนมัติแล้ว'
                            : 'ส่ง SOS และแจ้ง LINE แล้ว แต่ยังไม่มีเบอร์โทรของผู้ดูแล',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: hasPhone && !_launchingCall ? _callCaregiver : null,
                          icon: _launchingCall
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.card,
                                  ),
                                )
                              : const Icon(Icons.call_rounded),
                          label: Text(
                            hasPhone
                                ? (_launchingCall ? 'กำลังเปิดหน้าโทร...' : 'โทรหาผู้ดูแลทันที')
                                : 'ยังโทรไม่ได้',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: AppColors.card,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await HapticFeedback.selectionClick();
                            if (!mounted) return;
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('กลับไปหน้าแผนที่'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
