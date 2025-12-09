import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'VideoPlayerPage.dart';
import 'stock_market_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String selectedTab = 'الأسهم';
  List<Map<String, dynamic>> educationFavorites = [];
  List<Map<String, dynamic>> stockFavorites = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEducationFavorites();
    fetchStockFavorites();
  }

  Future<void> fetchStockFavorites() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    List<Map<String, dynamic>> items = [];
    Set<String> seenCompanies = {}; // لتتبع الشركات المضافة

    try {
      final stocksSnap = await FirebaseFirestore.instance
          .collection('Favorites')
          .doc(userId)
          .collection('stocks')
          .get();

      for (var doc in stocksSnap.docs) {
        final companyId = doc.id;
        
        // تجاهل الشركات المكررة
        if (seenCompanies.contains(companyId)) {
          continue;
        }
        
        seenCompanies.add(companyId);
        items.add({
          'id': companyId,
          'name': doc['name'],
          'logoAsset': doc['logoAsset'],
        });
      }

      setState(() {
        stockFavorites = items;
      });
    } catch (e) {
      print('Error fetching stock favorites: $e');
    }
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

  Future<void> removeStockFavorite(String companyId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      // حذف من المفضلة
      await FirebaseFirestore.instance
          .collection('Favorites')
          .doc(userId)
          .collection('stocks')
          .doc(companyId)
          .delete();

      // تحديث حالة liked في جميع المراكز (positions) لهذه الشركة
      final positionsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('positions')
          .where('symbol', isEqualTo: companyId)
          .get();

      // تحديث كل المراكز
      for (var doc in positionsSnap.docs) {
        await doc.reference.update({'liked': false});
      }

      setState(() {
        stockFavorites.removeWhere((element) => element['id'] == companyId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إزالة السهم من المفضلة'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
  preferredSize: Size.fromHeight(kToolbarHeight),
  child: AppBar(
    backgroundColor: Color(0xFF609966),
    elevation: 0,
    automaticallyImplyLeading: false,
    title: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(width: 48),

        Expanded(
          child: Text(
            'قائمة المفضلة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),

                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
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
      return Center(child: CircularProgressIndicator(color: Color(0xFF609966)));
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
                child: Icon(Icons.favorite, color: Color(0xFF609966), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockList() {
    if (stockFavorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'لا توجد أسهم مفضلة',
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'اضغط على أيقونة القلب في صفحة المحفظة\nلإضافة أسهم إلى المفضلة',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: stockFavorites.length,
      itemBuilder: (context, index) {
        final item = stockFavorites[index];
        return _buildStockCard(
          companyId: item['id'],
          name: item['name'],
          logoPath: 'assets/company-logos/${item['logoAsset']}',
        );
      },
    );
  }

  Widget _buildStockCard({
    required String companyId,
    required String name,
    required String logoPath,
  }) {
    return GestureDetector(
      onTap: () {
        // الانتقال إلى صفحة المحاكاة مع تحديد الشركة
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketSimulationPage(),
            settings: RouteSettings(
              arguments: {'selectedCompany': name},
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                logoPath,
                fit: BoxFit.contain,
              ),
            ),
          ),

            SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            SizedBox(width: 12),
            GestureDetector(
              onTap: () => removeStockFavorite(companyId),
              child: Container(
                padding: EdgeInsets.all(8),
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
                child: Icon(Icons.favorite, color: Color(0xFF609966), size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}