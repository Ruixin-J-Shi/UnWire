import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const P2PApp());
}

class P2PApp extends StatelessWidget {
  const P2PApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P Chat',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
