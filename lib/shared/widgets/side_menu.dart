import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SideMenu extends StatelessWidget {
  final bool isSidebar;

  const SideMenu({
    super.key,
    this.isSidebar = false,
  });

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),

          /// =========================
          /// TITLE
          /// =========================
          Text(
            'Registro Catechismo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isSidebar ? Colors.white : const Color(0xFF174A7E),
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 25),

          /// =========================
          /// MENU ITEMS
          /// =========================
          _item(
            context,
            location,
            '/',
            Icons.dashboard_rounded,
            'Dashboard',
          ),
          _item(
            context,
            location,
            '/my-group',
            Icons.groups_rounded,
            'Il mio gruppo',
          ),
          _item(
            context,
            location,
            '/planning',
            Icons.calendar_month_rounded,
            'Programmazione',
          ),
          _item(
            context,
            location,
            '/documents',
            Icons.description_rounded,
            'Documenti',
          ),
          _item(
            context,
            location,
            '/settings',
            Icons.settings_rounded,
            'Impostazioni',
          ),
        ],
      ),
    );
  }

  /// =========================
  /// MENU ITEM
  /// =========================
  Widget _item(
    BuildContext context,
    String location,
    String route,
    IconData icon,
    String title,
  ) {
    final selected = location == route;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? (isSidebar
                  ? Colors.white.withOpacity(0.15)
                  : const Color(0xFF174A7E).withOpacity(0.10))
              : Colors.transparent,
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),

          leading: Icon(
            icon,
            color: selected
                ? (isSidebar ? Colors.white : const Color(0xFF174A7E))
                : (isSidebar ? Colors.white70 : Colors.grey.shade700),
          ),

          title: Text(
            title,
            style: TextStyle(
              color: isSidebar ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),

          onTap: () {
            context.go(route);
          },
        ),
      ),
    );
  }
}