import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'details_screen_mobile.dart';
import 'details_screen_windows.dart';

class DetailsScreen extends StatelessWidget {
  final Map<String, dynamic> item;

  const DetailsScreen({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isDesktop && constraints.maxWidth > 800) {
          return DetailsScreenWindows(item: item);
        } else {
          return DetailsScreenMobile(item: item);
        }
      },
    );
  }
}
