import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:pens_smart_stove/dashboard.dart';

void main() {
  runApp(
    Phoenix(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        // colorScheme: ColorScheme.fromSwatch(),
        colorScheme: ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 0, 21, 255)),
        // useMaterial3: true,
      ),
      home: Dashboard(),
    );
  }
}
