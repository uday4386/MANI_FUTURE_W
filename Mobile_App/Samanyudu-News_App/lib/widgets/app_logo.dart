import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppLogo extends StatelessWidget {
  final double fontSize;
  final bool showTV;

  const AppLogo({
    super.key,
    this.fontSize = 90,
    this.showTV = true,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/app_logo_new.png',
      height: fontSize * 0.8,
      fit: BoxFit.contain,
    );
  }
}
