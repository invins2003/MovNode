import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize media_kit for video playback
  MediaKit.ensureInitialized();
  runApp(const MovNodeApp());
}

class MovNodeApp extends StatelessWidget {
  const MovNodeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MovNode',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0208),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF39FF14),
          secondary: Color(0xFF39FF14),
          surface: Color(0xFF0D0208),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
