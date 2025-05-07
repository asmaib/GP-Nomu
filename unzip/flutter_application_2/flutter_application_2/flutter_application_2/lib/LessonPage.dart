import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'PlaylistPage.dart';
import 'FlashcardWidget.dart';

class LessonPage extends StatefulWidget {
  final String lessonDocId;

  const LessonPage({required this.lessonDocId});

  @override
  _LessonPageState createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  late Future<Map<String, dynamic>?> lessonFuture;
  YoutubePlayerController? _youtubeController;
  bool _rewardGiven = false;

  @override
  void initState() {
    super.initState();
    lessonFuture = fetchLessonData();
  }

  @override
  void dispose() {
    _youtubeController?.removeListener(_videoListener);
    _youtubeController?.dispose();
    super.dispose();
  }

  void _videoListener() {
    if (_youtubeController?.value.playerState == PlayerState.ended && !_rewardGiven) {
      checkAndRewardCoins();
      setState(() {
        _rewardGiven = true;
      });
    }
  }

  Future<Map<String, dynamic>?> fetchLessonData() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('Learing')
          .doc(widget.lessonDocId)
          .get();

      if (!docSnapshot.exists) return null;

      final data = docSnapshot.data();
      final hasPlaylist = data != null &&
          data.containsKey('playlist_videos') &&
          (data['playlist_videos'] as List).isNotEmpty;

      // If no playlist, initialize YouTube controller
      if (!hasPlaylist) {
        final videoUrl = data?['url'] ?? '';
        final videoId = YoutubePlayer.convertUrlToId(videoUrl);
        if (videoId != null) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: true,
              mute: false,
              enableCaption: false,
            ),
          )..addListener(_videoListener);
        }
      }

      return data;
    } catch (e) {
      debugPrint('Error fetching lesson data: $e');
      return null;
    }
  }

  Future<void> checkAndRewardCoins() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || !mounted) return;

      final rewardRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('lessons_rewards')
          .doc(widget.lessonDocId);

      final rewardDoc = await rewardRef.get();
      if (!rewardDoc.exists) {
        await rewardRef.set({
          'coins': 10,
          'timestamp': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'coins': FieldValue.increment(10)});

        if (mounted) {
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    backgroundColor: const Color.fromARGB(255, 157, 192, 139),
    title: Text(
      'نجاح',
      textAlign: TextAlign.right,
      style: TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),
    content: Text(
      'ربحت 10 عملات إضافية إلى رصيدك!',
      textAlign: TextAlign.right,
      style: TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: Text(
          'حسناً',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    ],
  ),
);

        }
      }
    } catch (e) {
      debugPrint('Error rewarding coins: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: lessonFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(body: Center(child: Text("لم يتم العثور على الدرس")));
        }

        final data = snapshot.data!;
        final title = data['title'] ?? 'عنوان غير متوفر';
        final description = data['description'] ?? '';
        final hasPlaylist = data.containsKey('playlist_videos') &&
            (data['playlist_videos'] as List).isNotEmpty;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SafeArea(
              top: true,
              child: ListView(
                children: [
                  Stack(
                    children: [
                      if (hasPlaylist)
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/introduction.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else if (_youtubeController != null)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: YoutubePlayer(
                            controller: _youtubeController!,
                            showVideoProgressIndicator: true,
                            progressColors: ProgressBarColors(
                              playedColor: Color(0xFFDAF0CF),
                              handleColor: Color(0xFFDAF0CF),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_forward,
                            color: hasPlaylist ? Color(0xFF609966) : Color(0xFF609966),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      if (!hasPlaylist)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: FavoriteLessonIcon(
                            lessonId: widget.lessonDocId,
                          ),
                        ),
                    ],
                  ),

                  // Title & Description
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                        SizedBox(height: 10),
                        Text(description),
                      ],
                    ),
                  ),

                  // Continue button (unless 'first')
                  if (widget.lessonDocId != 'first')
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                            onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => hasPlaylist
                                    ? PlaylistPage(lessonDocId: widget.lessonDocId)
                                    : FlashcardWidget(lessonId: widget.lessonDocId),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:Color(0xFF609966),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            hasPlaylist ? 'متابعة الدروس' : 'انتقل إلى البطاقات',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
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

class FavoriteLessonIcon extends StatefulWidget {
  final String lessonId;

  const FavoriteLessonIcon({required this.lessonId});

  @override
  _FavoriteLessonIconState createState() => _FavoriteLessonIconState();
}

class _FavoriteLessonIconState extends State<FavoriteLessonIcon> {
  bool isFavorite = false;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    checkIfFavorite();
  }

  Future<void> checkIfFavorite() async {
    if (userId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Favorites')
          .doc(userId)
          .collection('lessons')
          .doc(widget.lessonId)
          .get();
      if (mounted) {
        setState(() => isFavorite = doc.exists);
      }
    } catch (e) {
      debugPrint('Error checking favorite: $e');
    }
  }

  Future<void> toggleFavorite() async {
    if (userId == null) return;
    final favRef = FirebaseFirestore.instance
        .collection('Favorites')
        .doc(userId)
        .collection('lessons')
        .doc(widget.lessonId);

    if (isFavorite) {
      await favRef.delete();
    } else {
      final lessonDoc = await FirebaseFirestore.instance
          .collection('Learing')
          .doc(widget.lessonId)
          .get();
      await favRef.set({
        'lessonId': widget.lessonId,
        'title': lessonDoc['title'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    if (mounted) setState(() => isFavorite = !isFavorite);
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
