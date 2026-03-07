import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const HerCodeXApp());
}

class HerCodeXApp extends StatelessWidget {
  const HerCodeXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HerCodeX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF81C784), // soft green
          secondary: const Color(0xFF81D4FA), // light blue
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF81C784),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
//