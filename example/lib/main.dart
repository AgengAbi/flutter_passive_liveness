import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liveness Detection Example',
      home: Scaffold(
        appBar: AppBar(title: const Text('Passive Liveness Detection')),
        body: const Center(
          child: Text(
            'See README.md for integration guide.\n'
            'See liveness_demo for full camera integration.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
