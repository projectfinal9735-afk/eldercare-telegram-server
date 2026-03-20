import 'package:flutter/material.dart';

class CoordinateInputCard extends StatelessWidget {
  final TextEditingController latController;
  final TextEditingController lngController;
  final String? latestSosLabel;
  final String? latestLiveLocationLabel;
  final VoidCallback onSubmit;

  const CoordinateInputCard({
    super.key,
    required this.latController,
    required this.lngController,
    required this.latestSosLabel,
    required this.latestLiveLocationLabel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'พิกัด (จาก SOS / กรอกเอง)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (latestSosLabel != null) ...[
              Text(latestSosLabel!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
            ],
            if (latestLiveLocationLabel != null) ...[
              Text(latestLiveLocationLabel!, style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'ละติจูด (lat)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'ลองจิจูด (lng)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 239, 150, 91),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onSubmit,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('ไป', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
