import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'VideoPlayerPage.dart';
import 'FlashcardWidget.dart';

class PlaylistPage extends StatelessWidget {
  final String lessonDocId;

  PlaylistPage({required this.lessonDocId});

  Future<Map<String, dynamic>> fetchLessonData() async {
    final doc = await FirebaseFirestore.instance
        .collection('Learing')
        .doc(lessonDocId)
        .get();
    return doc.data() ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchLessonData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
              body: Center(child: Text('لم يتم العثور على بيانات الدرس')));
        }

        final data = snapshot.data!;
        final title = data['title'] ?? '';
        final videos =
        List<Map<String, dynamic>>.from(data['playlist_videos'] ?? []);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              top: false, // ← allow header to extend into status bar area
              child: Column(
                children: [
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
                              Image.asset('assets/investments2.png',
                                  height: 80),
                              SizedBox(height: 5),
                              Text(
                                title,
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        final subtitle = video['subtitle'] ?? 'بدون عنوان';
                        final url = video['url'] ?? '';

                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: GestureDetector(
                                  onTap: () {
                                    if (url.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => VideoPlayerPage(
                                            videoUrl: url,
                                            videoTitle: subtitle,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    color: Color(0xFFE8F5E9),
                                    padding: EdgeInsets.all(10),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Image.asset('assets/investments2.png',
                                            height: 50),
                                        Icon(Icons.play_circle_fill,
                                            color: Colors.white, size: 30),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              FavoriteVideoIcon(
                                lessonId: lessonDocId,
                                subtitle: subtitle,
                                url: url,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Fixed button at bottom
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FlashcardWidget(lessonId: lessonDocId),
    ),
  );
},

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF609966),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'انتقل إلى البطاقات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FavoriteVideoIcon extends StatefulWidget {
  final String lessonId;
  final String subtitle;
  final String url;

  const FavoriteVideoIcon({
    required this.lessonId,
    required this.subtitle,
    required this.url,
  });

  @override
  _FavoriteVideoIconState createState() => _FavoriteVideoIconState();
}

class _FavoriteVideoIconState extends State<FavoriteVideoIcon> {
  bool isFavorite = false;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    checkIfFavorite();
  }

  Future<void> checkIfFavorite() async {
    if (userId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('Favorites')
        .doc(userId)
        .collection('lessons')
        .doc(widget.lessonId)
        .collection('videos')
        .doc(widget.subtitle)
        .get();

    setState(() {
      isFavorite = doc.exists;
    });
  }

  Future<void> toggleFavorite() async {
    if (userId == null) return;

    final lessonDocRef = FirebaseFirestore.instance
        .collection('Favorites')
        .doc(userId)
        .collection('lessons')
        .doc(widget.lessonId);

    final videoDocRef =
    lessonDocRef.collection('videos').doc(widget.subtitle);

    if (isFavorite) {
      await videoDocRef.delete();
    } else {
      final lessonExists = await lessonDocRef.get();
      if (!lessonExists.exists) {
        final lessonData = await FirebaseFirestore.instance
            .collection('Learing')
            .doc(widget.lessonId)
            .get();
        final title = lessonData.data()?['title'] ?? 'درس';
        await lessonDocRef.set({'title': title});
      }

      await videoDocRef.set({
        'subtitle': widget.subtitle,
        'url': widget.url,
        'lessonId': widget.lessonId,
      });
    }

    setState(() {
      isFavorite = !isFavorite;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: Color(0xFF609966),
      ),
      onPressed: toggleFavorite,
    );
  }
}
