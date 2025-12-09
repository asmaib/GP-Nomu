import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ✨ Add this import
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'wellcome.dart';
import 'LessonPage.dart';
import 'FlashcardWidget.dart';

import 'notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✨ Add this line to fix the Red Screen
  await initializeDateFormatting();

  // 1. Load Environment Variables
  try {
    await dotenv.load(fileName: ".env");
    print("DotEnv loaded successfully.");
  } catch (e) {
    print("Error loading .env file: $e");
  }

  // 2. Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully.");
  } catch (e) {
    print("Error initializing Firebase: $e");
    return;
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WelcomePage(),
      routes: {
        '/lesson': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          final lessonId = arguments is String ? arguments : null;
          if (lessonId == null) {
            return Scaffold(body: Center(child: Text("Error: Lesson ID missing or invalid.")));
          }
          return LessonPage(lessonDocId: lessonId);
        },
        '/flashcard': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          final id = arguments is String ? arguments : null;
          if (id == null) {
            return Scaffold(body: Center(child: Text("Error: Flashcard ID missing or invalid.")));
          }
          return FlashcardWidget(lessonId: id);
        },
      },
    );
  }
}