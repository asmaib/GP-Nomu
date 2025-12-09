import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;

  const VideoPlayerPage({
    Key? key,
    required this.videoUrl,
    required this.videoTitle,
  }) : super(key: key);

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late YoutubePlayerController _controller;
  bool _rewardGiven = false;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl)!;
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );

    _controller.addListener(() {
      if (_controller.value.playerState == PlayerState.ended && !_rewardGiven) {
        checkAndRewardCoins();
        _rewardGiven = true;
      }
    });
  }

  Future<void> checkAndRewardCoins() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userCoinsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('lessons_rewards')
        .doc(widget.videoTitle);

    final userCoinsDoc = await userCoinsRef.get();

    if (!userCoinsDoc.exists) {
      await userCoinsRef.set({'coins': 10});

      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      await userRef.update({
        'coins': FieldValue.increment(10),
      });

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
  }

  @override
  Widget build(BuildContext context) {
return Directionality(
  textDirection: TextDirection.rtl,
  child: Scaffold(
    backgroundColor: Colors.white,
    body: Column(
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF609966), Color(0xFF609966)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
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
              top: 70,
              left: 0,
              right: 0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    widget.videoTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 5.0,
                          color: Colors.black.withOpacity(0.3),
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressColors: ProgressBarColors(
                playedColor:  Color(0xFF609966),
                handleColor:  Color(0xFF609966),
              ),
            ),
          ),
        ),
        SizedBox(height: 20),
      ],
    ),
  ),
);

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}