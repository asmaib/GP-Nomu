import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'FlashcardWidget.dart';
import 'CoinManager.dart';

class FlashcardPage extends StatefulWidget {
  @override
  _FlashcardPageState createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  List<Map<String, String>> flashcards = [];
  bool isLoading = true;
  int _coinCount = 0;
  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    fetchFlashcardsFromFirebase();
    _reloadCoinsFromFirestore();
  }

  Future<void> _loadFavorites() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final favSnap = await FirebaseFirestore.instance
        .collection('Favorites')
        .doc(userId)
        .collection('flashcards')
        .get();
    setState(() {
      _favoriteIds = favSnap.docs.map((d) => d.id).toSet();
    });
  }

  Future<void> fetchFlashcardsFromFirebase() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('Learing').get();

      final List<String> order = ['second', 'third', 'fourth', 'fifth'];

      final filteredAndSorted = snapshot.docs
          .where((doc) => doc.id != 'first')
          .toList()
        ..sort((a, b) {
          final aIndex = order.indexOf(a.id);
          final bIndex = order.indexOf(b.id);
          return (aIndex == -1 ? 999 : aIndex)
              .compareTo(bIndex == -1 ? 999 : bIndex);
        });

      final fetched = filteredAndSorted
          .map((doc) => {
        'id': doc.id,
        'title': doc['title'] as String,
        'image': 'assets/cards_icon.png',
      })
          .toList();

      setState(() {
        flashcards = fetched;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching flashcards: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _reloadCoinsFromFirestore() async {
    final coins = await CoinManager.getCoins();
    setState(() {
      _coinCount = coins;
    });
  }

  Future<void> _toggleFavorite(String id, String title) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('Favorites')
        .doc(userId)
        .collection('flashcards')
        .doc(id);

    if (_favoriteIds.contains(id)) {
      await docRef.delete();
      setState(() => _favoriteIds.remove(id));
    } else {
      await docRef.set({
        'flashcardId': id,
        'title': title,
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() => _favoriteIds.add(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: isLoading
              ? Center(child: CircularProgressIndicator(color: Color(0xFF609966)))
              : Column(
            children: [
              // Header
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 175,
                    color:  Color(0xFF609966),
                  ),

                  Positioned(
                    left: 10,
                    top: 30,
                    child: Directionality(
                      // force this subtree LTR so the arrow_back icon isn't flipped
                      textDirection: TextDirection.ltr,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 50,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        children: [
                          Image.asset('assets/cards_icon.png',
                              height: 80),
                          SizedBox(height: 5),
                          Text(
                            'البطاقات التفاعلية',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Flashcard list
              Expanded(
                child: flashcards.isEmpty
                    ? Center(
                  child: Text(
                    "لا توجد بطاقات حالياً",
                    style: TextStyle(fontSize: 16),
                  ),
                )
                    : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: flashcards.length,
                  itemBuilder: (context, index) {
                    final flashcard = flashcards[index];
                    final id = flashcard['id']!;
                    final title = flashcard['title']!;
                    final isFav = _favoriteIds.contains(id);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                FlashcardWidget(lessonId: id),
                          ),
                        );
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color:
                              Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child:Row(
  mainAxisAlignment: MainAxisAlignment.start,
  children: [
    // Card image (first thing on the right)
    ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: Color(0xFFE8F5E9),
        padding: EdgeInsets.all(10),
        child: Image.asset(
          flashcard['image']!,
          height: 50,
        ),
      ),
    ),

    SizedBox(width: 12),

    // The text next to the image is adjacent
    Expanded(
      child: Text(
        title,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    SizedBox(width: 12),

    //Favorite icon (on the left)
    IconButton(
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: Color(0xFF609966),
      ),
      onPressed: () => _toggleFavorite(id, title),
    ),
  ],
),

                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
