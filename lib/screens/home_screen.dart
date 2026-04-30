import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'home_screen_mobile.dart';
import 'home_screen_windows.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if running on Web or Desktop
    final isDesktop = kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use Windows layout if screen is wide enough or if it's explicitly desktop
        if (isDesktop && constraints.maxWidth > 800) {
          return const HomeScreenWindows();
        } else {
          return const HomeScreenMobile();
        }
      },
    );
  }
}
