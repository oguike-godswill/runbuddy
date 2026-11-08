import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/network/api_endpoints.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiEndpoints.init();
  runApp(const RunBuddyApp());
}
