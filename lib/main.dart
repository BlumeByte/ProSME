import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'config/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDevMode) {
    await Firebase.initializeApp();
  }
  runApp(const ProviderScope(child: ProSMEApp()));
}
