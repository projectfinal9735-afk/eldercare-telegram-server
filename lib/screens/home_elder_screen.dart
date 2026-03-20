import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'route_search_screen.dart';
import 'add_caregiver_screen.dart';
import '../root.dart';

class HomeElderScreen extends StatefulWidget {
  const HomeElderScreen({super.key});

  @override
  State<HomeElderScreen> createState() => _HomeElderScreenState();
}

class _HomeElderScreenState extends State<HomeElderScreen> {
  int _index = 1; // เริ่มที่แผนที่

  // ✅ title เปลี่ยนตามเมนู
  String get _title {
    switch (_index) {
      case 0:
        return 'ผู้ดูแล';
      case 1:
        return 'แผนที่';
      case 2:
        return 'โปรไฟล์';
      default:
        return '';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const AddCaregiverScreen(),   // ซ้าย
      const RouteSearchScreen(showCoordinateInput: false),    // กลาง
      const ProfileScreen(),        // ขวา
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 239, 150, 91),
        title: Text(
          _title,
          style: const TextStyle(color: Colors.white), // ✅ ตัวหนังสือขาว
        ),
        iconTheme: const IconThemeData(
          color: Colors.white, // ✅ ไอคอนฝั่งซ้าย (ถ้ามี)
        ),
        actionsIconTheme: const IconThemeData(
          color: Colors.white, // ✅ ไอคอนฝั่งขวา (logout)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const Root()),
                (_) => false,
              );
            },
          ),
        ],
),


      // ✅ เปลี่ยนหน้าทันที ไม่ push
      body: IndexedStack(
        index: _index,
        children: pages,
      ),

      bottomNavigationBar: _BottomActionBar(
        currentIndex: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const _BottomActionBar({
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.white; // ✅ บังคับให้เป็นสีขาว

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 239, 150, 91), // ✅ พื้นหลังฟ้า (เหมือนปุ่มไป)
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            _button(
              icon: Icons.person_add_alt_1,
              label: 'ผู้ดูแล',
              selected: currentIndex == 0,
              color: color,
              onTap: () => onSelect(0),
            ),
            _button(
              icon: Icons.map,
              label: 'แผนที่',
              selected: currentIndex == 1,
              color: color,
              onTap: () => onSelect(1),
            ),
            _button(
              icon: Icons.person,
              label: 'โปรไฟล์',
              selected: currentIndex == 2,
              color: color,
              onTap: () => onSelect(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required IconData icon,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 30,
                color: selected ? color : color.withOpacity(0.7),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color : color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



