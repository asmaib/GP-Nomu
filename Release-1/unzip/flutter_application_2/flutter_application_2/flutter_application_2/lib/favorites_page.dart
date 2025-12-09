import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'VideoPlayerPage.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}



class _FavoritesPageState extends State<FavoritesPage> {
  String selectedTab = 'الأسهم';
  List<Map<String, dynamic>> educationFavorites = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEducationFavorites();
  }

  Future<void> fetchEducationFavorites() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    List<Map<String, dynamic>> items = [];

final lessonsSnap = await FirebaseFirestore.instance
    .collection('Favorites')
    .doc(userId)
    .collection('lessons')
    .get();

for (var doc in lessonsSnap.docs) {
  final lessonId = doc.id;
  final title = doc['title'];

  // Check if the lesson is a single video and not a playlist
  final lessonSnapshot = await FirebaseFirestore.instance
      .collection('Learing')
      .doc(lessonId)
      .get();

  final lessonData = lessonSnapshot.data();

  final isSingleVideo = lessonData == null ||
      !lessonData.containsKey('playlist_videos') ||
      (lessonData['playlist_videos'] as List).isEmpty;

  if (isSingleVideo) {
    items.add({'id': lessonId, 'title': title, 'type': 'lesson'});
  }

  final videosSnap = await FirebaseFirestore.instance
      .collection('Favorites')
      .doc(userId)
      .collection('lessons')
      .doc(lessonId)
      .collection('videos')
      .get();

  for (var videoDoc in videosSnap.docs) {
    items.add({
      'id': videoDoc.id,
      'title': videoDoc['subtitle'],
      'url': videoDoc['url'],
      'lessonId': lessonId,
      'type': 'video',
    });
  }
}


    final flashcardsSnap = await FirebaseFirestore.instance
        .collection('Favorites')
        .doc(userId)
        .collection('flashcards')
        .get();

    for (var doc in flashcardsSnap.docs) {
      items.add({'id': doc.id, 'title': doc['title'], 'type': 'flashcard'});
    }

    setState(() {
      educationFavorites = items;
      isLoading = false;
    });
  }

  Future<void> removeFavorite(Map<String, dynamic> item) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (item['type'] == 'lesson') {
      await FirebaseFirestore.instance
          .collection('Favorites')
          .doc(userId)
          .collection('lessons')
          .doc(item['id'])
          .delete();
    } else if (item['type'] == 'video') {
      await FirebaseFirestore.instance
          .collection('Favorites')
          .doc(userId)
          .collection('lessons')
          .doc(item['lessonId'])
          .collection('videos')
          .doc(item['id'])
          .delete();
    } else if (item['type'] == 'flashcard') {
      await FirebaseFirestore.instance
          .collection('Favorites')
          .doc(userId)
          .collection('flashcards')
          .doc(item['id'])
          .delete();
    }

    setState(() {
      educationFavorites.removeWhere((element) =>
          element['id'] == item['id'] &&
          element['type'] == item['type'] &&
          (item['type'] != 'video' || element['lessonId'] == item['lessonId']));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
  preferredSize: Size.fromHeight(kToolbarHeight),
  child: Directionality(
    textDirection: TextDirection.ltr, 
    child: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: false,
      title: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'قائمة المفضلة',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  ),
),

        body: Column(
          children: [
            _buildTabs(),
            SizedBox(height: 16),
            Expanded(
              child: selectedTab == 'الأسهم' ? _buildStockList() : _buildEducationList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      height: 50,
      decoration: BoxDecoration(
        color: Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildToggleTab('التعليم'),
          _buildToggleTab('الأسهم'),
        ],
      ),
    );
  }

  Widget _buildToggleTab(String label) {
    bool isSelected = selectedTab == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = label),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFF609966) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEducationList() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color:  Color(0xFF609966)));
    }

    if (educationFavorites.isEmpty) {
      return Center(
        child: Text(
          'لا توجد عناصر مفضلة هنا.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: educationFavorites.length,
      itemBuilder: (context, index) {
        final item = educationFavorites[index];
        return _buildFavoriteCard(
          title: item['title'] ?? '',
          type: item['type'],
          onTap: () {
            if (item['type'] == 'lesson') {
              Navigator.pushNamed(context, '/lesson', arguments: item['id']);
            } else if (item['type'] == 'flashcard') {
              Navigator.pushNamed(context, '/flashcard', arguments: item['id']);
} else if (item['type'] == 'video') {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => VideoPlayerPage(
        videoUrl: item['url'],
        videoTitle: item['title'],
      ),
    ),
  );
}


          },
          onRemove: () => removeFavorite(item),
        );
      },
    );
  }

  Widget _buildFavoriteCard({
    required String title,
    required String type,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.green[100],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  type == 'flashcard'
                      ? 'assets/cards_icon.png'
                      : 'assets/investments2.png',
                  height: 40,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.favorite, color:Color(0xFF609966), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockList() {
    List<Map<String, dynamic>> stockFavorites = [
      {'symbol': 'Alrajhi', 'change': '+15.5%', 'logo': 'assets/alrajhi.png'},
    ];

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: stockFavorites.length,
      itemBuilder: (context, index) {
        final item = stockFavorites[index];
        return _buildStockCard(
          symbol: item['symbol'],
          change: item['change'],
          logoPath: item['logo'],
        );
      },
    );
  }

  Widget _buildStockCard({
    required String symbol,
    required String change,
    required String logoPath,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: AssetImage(logoPath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  symbol,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 6),
                Text(
                  change,
                  style: TextStyle(color:Color(0xFF609966), fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.favorite, color: Color(0xFF609966), size: 20),
          ),
        ],
      ),
    );
  }
}
