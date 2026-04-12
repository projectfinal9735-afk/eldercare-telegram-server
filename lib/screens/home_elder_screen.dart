import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';
import 'route_search_screen.dart';
import '../theme/app_colors.dart';
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
        return 'คนใกล้ชิด';
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
        backgroundColor: AppColors.primary,
        title: Text(
          _title,
          style: const TextStyle(color: AppColors.card), // ✅ ตัวหนังสือขาว
        ),
        iconTheme: const IconThemeData(
          color: AppColors.card, // ✅ ไอคอนฝั่งซ้าย (ถ้ามี)
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.card, // ✅ ไอคอนฝั่งขวา (logout)
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
    final color = AppColors.card;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
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
            _NavActionItem(
              icon: Icons.person_add_alt_1,
              label: 'คนใกล้ชิด',
              selected: currentIndex == 0,
              color: color,
              onTap: () => onSelect(0),
            ),
            _NavActionItem(
              icon: Icons.map,
              label: 'แผนที่',
              selected: currentIndex == 1,
              color: color,
              onTap: () => onSelect(1),
            ),
            _NavActionItem(
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
}

class _NavActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _NavActionItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  State<_NavActionItem> createState() => _NavActionItemState();
}

class _NavActionItemState extends State<_NavActionItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final opacity = selected ? 1.0 : 0.72;

    return Expanded(
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: BorderRadius.circular(14),
          splashColor: AppColors.card.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected ? AppColors.card.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      widget.icon,
                      size: 34,
                      color: widget.color.withOpacity(opacity),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: widget.color.withOpacity(opacity),
                    ),
                    child: Text(widget.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}




