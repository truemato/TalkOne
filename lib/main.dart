import 'package:flutter/material.dart';
import 'package:flutter_temp/src/screens/matching_screen.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Temp',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MatchingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
