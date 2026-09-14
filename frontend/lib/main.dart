import 'package:flutter/material.dart';

import 'app.dart';
import 'shared/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = ThemeController();
  await theme.load();
  runApp(ReviewQueueApp(theme: theme));
}
