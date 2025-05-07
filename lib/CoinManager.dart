import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CoinManager {
  // Get the current coin balance for the logged-in user
  static Future<int> getCoins() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return doc.data()?['coins'] ?? 0; // Default to 0 if no coins field exists
    }
    return 0; // Return 0 if no user is logged in
  }

  // Add coins to the user's balance
  static Future<void> addCoin(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.update({'coins': FieldValue.increment(amount)});
    }
  }

  // Initialize the user's coin balance if it's their first time logging in
  static Future<void> initializeCoins() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        await userRef.set({
          'coins': 0, // Start with 0 coins
        });
      }
    }
  }

  // Check if the user has earned coins for a specific flashcard lesson
  static Future<bool> hasEarnedCoinsForLesson(String lessonId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('earnedFlashcardCoins')
          .doc(lessonId)
          .get();
      return doc.exists;
    }
    return false;
  }

  //  Mark that the user has earned coins for a specific flashcard lesson
  static Future<void> markCoinsAsEarnedForLesson(String lessonId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('earnedFlashcardCoins')
          .doc(lessonId);
      await docRef.set({'earned': true});
    }
  }
}
