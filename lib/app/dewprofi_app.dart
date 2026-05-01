import 'package:flutter/material.dart';

import '../features/humidity_calculator/humidity_calculator_page.dart';

class DewprofiApp extends StatelessWidget {
  const DewprofiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E);

    return MaterialApp(
      title: 'Dewprofi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          primary: seed,
          secondary: const Color(0xFFB45309),
          tertiary: const Color(0xFF4F46E5),
          surface: const Color(0xFFFFFBF5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F3EF),
        visualDensity: VisualDensity.standard,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          filled: true,
          fillColor: Color(0xFFFFFBF5),
        ),
      ),
      home: const HumidityCalculatorPage(),
    );
  }
}
