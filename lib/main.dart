import 'package:flutter/material.dart';

import 'ui/views/home_view.dart';

void main() => runApp(const O2Exercise());

class O2Exercise extends StatelessWidget {
  const O2Exercise({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'O2 Exercise',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.greenAccent),
      ),
      home: const HomeView(),
    );
  }
}
