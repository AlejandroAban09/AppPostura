// lib/screens/home_shell.dart
// CAMBIO: Mejoras en diseño de navegación
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:motion_tab_bar/MotionTabBar.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';

import '../../../styles/colors.dart';

class HomeShell extends StatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  MotionTabBarController? _motionTabBarController;

  @override
  void initState() {
    super.initState();
    _motionTabBarController = MotionTabBarController(
      initialIndex: 0,
      length: 5,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _motionTabBarController?.dispose();
    super.dispose();
  }

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

    // Sincronizar el controlador con la ruta actual si es necesario
    if (_motionTabBarController != null &&
        _motionTabBarController!.index != currentIndex) {
      _motionTabBarController!.index = currentIndex;
    }

    const labels = [
      "Dashboard",
      "Dispositivos",
      "Recompensas",
      "Métricas",
      "Perfil",
    ];

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: MotionTabBar(
        controller: _motionTabBarController,
        initialSelectedTab: labels[currentIndex],
        labels: labels,
        icons: const [
          Icons.home,
          Icons.devices,
          Icons.card_giftcard,
          Icons.insights,
          Icons.person,
        ],
        tabSize: 50,
        tabBarHeight: 55,
        textStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.primaryText,
          fontWeight: FontWeight.w500,
        ),
        tabIconColor: AppColors.secondaryText,
        tabIconSize: 28.0,
        tabIconSelectedSize: 26.0,
        tabSelectedColor: AppColors.primaryColor,
        tabIconSelectedColor: Colors.white,
        tabBarColor: Colors.white,
        onTabItemSelected: (int value) {
          setState(() {
            _motionTabBarController?.index = value;
          });
          _onTap(value);
        },
      ),
    );
  }
}
