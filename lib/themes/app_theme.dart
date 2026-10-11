import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primarySwatch: Colors.blue,
    textTheme: TextTheme(
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 16),
    ),
  );
}
