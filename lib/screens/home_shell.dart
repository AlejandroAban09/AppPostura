// lib/screens/home_shell.dart
// CAMBIO: Mejoras en diseño de navegación
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../styles/colors.dart';

class HomeShell extends StatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indexFromPath(String path) {
    if (path.startsWith('/devices')) return 1;
    if (path.startsWith('/rewards')) return 2;
    if (path.startsWith('/metrics')) return 3;
    if (path.startsWith('/profile')) return 4;
    return 0; // dashboard
  }

  void _onTap(int i) {
    switch (i) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/devices');
        break;
      case 2:
        context.go('/rewards');
        break;
      case 3:
        context.go('/metrics');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final currentIndex = _indexFromPath(path);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: _onTap,
          backgroundColor: AppColors.backgroundColor,
          indicatorColor: AppColors.primaryColor.withOpacity(0.2),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 70,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.secondaryText),
              selectedIcon: Icon(Icons.home, color: AppColors.primaryColor),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.devices_outlined,
                color: AppColors.secondaryText,
              ),
              selectedIcon: Icon(Icons.devices, color: AppColors.primaryColor),
              label: 'Dispositivos',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.card_giftcard_outlined,
                color: AppColors.secondaryText,
              ),
              selectedIcon: Icon(
                Icons.card_giftcard,
                color: AppColors.primaryColor,
              ),
              label: 'Recompensas',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.insights_outlined,
                color: AppColors.secondaryText,
              ),
              selectedIcon: Icon(Icons.insights, color: AppColors.primaryColor),
              label: 'Métricas',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: AppColors.secondaryText),
              selectedIcon: Icon(Icons.person, color: AppColors.primaryColor),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
