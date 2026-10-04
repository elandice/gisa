import 'package:flutter/material.dart';
import 'app.dart';

export 'app.dart';
export 'screens/workspace.dart';
export 'screens/learning_home.dart';
export 'screens/study_screen.dart';
export 'screens/exam_screen.dart';
export 'screens/exam_results.dart';
export 'screens/wrong_screen.dart';
export 'widgets/app_chrome.dart';
export 'widgets/study_content.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
