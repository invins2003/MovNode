import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CyberTheme {
  // Brand Colors
  static const Color hackerGreen = Color(0xFF39FF14);
  static const Color hackerGreenDark = Color(0xFF1E8A0A);
  static const Color hackerGreenGlow = Color(0x6639FF14);
  
  static const Color matrixBlack = Color(0xFF0D0208);
  static const Color matrixDarkGray = Color(0xFF151515);
  static const Color matrixLightGray = Color(0xFF252525);
  
  // Glassmorphism Textures
  static BoxDecoration glassBox({double borderRadius = 12.0, bool border = true}) {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
    );
  }
  
  static BoxDecoration glassBoxGreen({double borderRadius = 12.0}) {
    return BoxDecoration(
      color: hackerGreen.withOpacity(0.05),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: hackerGreen.withOpacity(0.3)),
      boxShadow: [
        BoxShadow(
          color: hackerGreenGlow,
          blurRadius: 10,
          spreadRadius: -5,
        ),
      ],
    );
  }

  // Typography
  static TextStyle headerText({double size = 24, Color color = Colors.white}) {
    return GoogleFonts.orbitron(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.5,
    );
  }

  static TextStyle monoText({double size = 14, Color color = Colors.white, FontWeight weight = FontWeight.normal}) {
    return GoogleFonts.shareTechMono(
      color: color,
      fontSize: size,
      fontWeight: weight,
    );
  }
}
