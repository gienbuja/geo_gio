import 'package:flutter/material.dart';
import 'welcome_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
    const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WelcomeScreen(),
    );
  }
}
