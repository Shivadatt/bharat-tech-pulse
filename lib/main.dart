import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/bindings/initial_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize critical dependencies before runApp for immediate theme resolution
  InitialBinding().dependencies();

  runApp(const BharatTechApp());
}
