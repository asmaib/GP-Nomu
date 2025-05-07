import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

import 'firebase_options.dart';
import 'wellcome.dart'; // our WelcomePage file
import 'LessonPage.dart';
import 'FlashcardWidget.dart';

Future<void> main() async {
  // Flutter bindings are initialize
  WidgetsFlutterBinding.ensureInitialized();

  // Load Environment Variables for the API Key
  try {
    await dotenv.load(fileName: ".env");
    print("DotEnv loaded successfully."); // Optional for debugging
  } catch (e) {
    print("Error loading .env file: $e"); // Optional for debugging
  }

  // Initialize Firebase 
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully."); // Optional for debugging
  } catch (e) {
    print("Error initializing Firebase: $e"); // Optional for debugging
    // Decide if the app should run if Firebase fails
    return; // Maybe exit if Firebase is critical
  }


  runApp(MyApp()); // Run the Application 
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      home: WelcomePage(), // Starts with WelcomePage
      // Define routes for navigation
      routes: {
        '/lesson': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          final lessonId = arguments is String ? arguments : null; 
          // Handle cases where lessonId might be null or not a string
          if (lessonId == null) {
            // Return an error page or a default state
            return Scaffold(body: Center(child: Text("Error: Lesson ID missing or invalid.")));
          }
          return LessonPage(lessonDocId: lessonId);
        },
        '/flashcard': (context) {
          // Safely get arguments
          final arguments = ModalRoute.of(context)?.settings.arguments;
          final id = arguments is String ? arguments : null; // Ensure it's a String
          // Handle cases where id might be null or not a string
          if (id == null) {
            // Return an error page or a default state
            return Scaffold(body: Center(child: Text("Error: Flashcard ID missing or invalid.")));
          }
          return FlashcardWidget(lessonId: id);
        },
      },

    );
  }
}