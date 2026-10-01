import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protein_calculator/app.dart';

void main() {
  runApp(const ProviderScope(child: ProteinCalculatorApp()));
}
