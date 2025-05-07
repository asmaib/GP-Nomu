// lib/FlashcardWidget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swipe_cards/swipe_cards.dart';
import 'package:flip_card/flip_card.dart';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_application_2/CoinManager.dart';

const Color _appBackgroundColor = Color(0xFFE5F3E6);

class Flashcard {
  final String question;
  final String answer;

  Flashcard({required this.question, required this.answer});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Flashcard &&
              runtimeType == other.runtimeType &&
              question == other.question &&
              answer == other.answer;

  @override
  int get hashCode => question.hashCode ^ answer.hashCode;
}

class FlashcardWidget extends StatefulWidget {
  final String lessonId;

  const FlashcardWidget({Key? key, required this.lessonId}) : super(key: key);

  @override
  _FlashcardWidgetState createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> {
  List<Flashcard> allCards = [];
  late List<SwipeItem> _swipeItems;
  late MatchEngine _matchEngine;
  Map<Flashcard, Color> _cardColors = {};
  List<Flashcard> _cardsToRepeat = [];
  int understoodCount = 0;
  int initialCardCount = 0;
  bool isLoading = true;

  // ← ADD: show tutorial once
  bool _showTutorial = true;

  @override
  void initState() {
    super.initState();
    fetchFlashcardsFromFirestore();
  }

  Future<void> fetchFlashcardsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Learing')
          .doc(widget.lessonId)
          .collection('flashcard')
          .orderBy(FieldPath.documentId)
          .get();

      final cards = <Flashcard>[];
      for (var doc in snapshot.docs) {
        final docId = doc.id;
        final data = doc.data();

        final rawQuestion = data['question'] ?? data['question '] ?? data[' Question'];
        final rawAnswer = data['answer'] ?? data['answer '] ?? data[' Answer'];

        if (rawQuestion == null || rawAnswer == null) {
          print('⚠️ Skipping "$docId": null question or answer');
          continue;
        }

        final question = rawQuestion.toString().trim();
        if (question.isEmpty) {
          print('⚠️ Skipping "$docId": Empty question');
          continue;
        }

        String answer;
        if (rawAnswer is List) {
          answer = '• ' + rawAnswer.map((e) => e.toString().trim()).join('\n• ');
        } else {
          answer = rawAnswer.toString().trim();
        }

        if (answer.isEmpty) {
          print('⚠️ Skipping "$docId": Empty answer');
          continue;
        }

        cards.add(Flashcard(question: question, answer: answer));
      }

      setState(() {
        allCards = cards;
        initialCardCount = allCards.length;
        for (var card in allCards) {
          _cardColors[card] = Colors.white;
        }
        _setupSwipeItems();
        _matchEngine = MatchEngine(swipeItems: _swipeItems);
        isLoading = false;
      });

      // ← ADD: show the tutorial dialog once
      if (_showTutorial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showHowToPlayDialog();
        });
      }
    } catch (e) {
      print('❌ Error fetching flashcards: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _setupSwipeItems() {
    _swipeItems = allCards.map((card) {
      return SwipeItem(
        content: card,
        likeAction: () {
          setState(() {
            understoodCount++;
            _cardColors[card] = Colors.green;
          });
        },
        nopeAction: () {
          setState(() {
            _cardsToRepeat.add(card);
            _cardColors[card] = Colors.red;
          });
        },
      );
    }).toList();
  }

  void _onStackFinished() {
    setState(() {
      if (_cardsToRepeat.isNotEmpty) {
        allCards = List.from(_cardsToRepeat);
        for (var card in allCards) {
          _cardColors[card] = Colors.white;
        }
        _cardsToRepeat.clear();
        _setupSwipeItems();
        _matchEngine = MatchEngine(swipeItems: _swipeItems);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _CongratsPage(lessonId: widget.lessonId),
          ),
        );
      }
    });
  }

  // ← ADD: tutorial dialog
  void _showHowToPlayDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('كيفية اللعب', textAlign: TextAlign.center),
        content: Text(
          ' اسحب البطاقة إلى اليمين إذا فهمت السؤال\n'
              ' اسحب إلى اليسار لإعادة المحاولة لاحقاً\n'
              ' انقر على البطاقة لقلبها لرؤية الإجابة',
          textAlign: TextAlign.right,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:  Color(0xFF609966), // green button
                foregroundColor: Colors.white, 
              ),
              child: Text('تمام فهمت'),
              onPressed: () {
                setState(() => _showTutorial = false);
                Navigator.of(context).pop();
              },
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _appBackgroundColor,
        appBar: AppBar(
          backgroundColor:  Color(0xFF609966),
          centerTitle: true,
          title: Text('', style: TextStyle(color: Colors.white)),
          leading: BackButton(color: Colors.white),
          actions: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 4),
                Text('$understoodCount / $initialCardCount',
                    style: TextStyle(color: Colors.white)),
                SizedBox(width: 12),
              ],
            ),
          ],
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.green))
            : allCards.isEmpty
            ? Center(
          child: Text(
            'لا توجد بطاقات في هذا الدرس',
            style:
            TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
        )
            : Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20.0, vertical: 10.0),
          child: SwipeCards(
            matchEngine: _matchEngine,
            onStackFinished: _onStackFinished,
            itemBuilder: (context, index) {
              final card =
              _swipeItems[index].content as Flashcard;
              final Color cardColor =
                  _cardColors[card] ?? Colors.white;

              return Listener(
                behavior: HitTestBehavior.translucent,
                onPointerMove: (event) {
                  if (_matchEngine.currentItem?.content ==
                      card &&
                      _cardColors[card] ==
                          Colors.white) {
                    setState(() {
                      if (event.delta.dx > 0) {
                        _cardColors[card] =
                            Colors.green.withOpacity(0.3);
                      } else if (event.delta.dx < 0) {
                        _cardColors[card] =
                            Colors.red.withOpacity(0.3);
                      }
                    });
                  }
                },
                onPointerUp: (_) {
                  if (_matchEngine.currentItem?.content ==
                      card &&
                      (_cardColors[card] ==
                          Colors.green.withOpacity(0.3) ||
                          _cardColors[card] ==
                              Colors.red.withOpacity(0.3))) {
                    setState(() {
                      _cardColors[card] = Colors.white;
                    });
                  }
                },
                child: Transform.rotate(
                  angle: index == 0
                      ? 0.0
                      : (Random().nextDouble() - 0.5) * 0.1,
                  child: FlipCard(
                    direction: FlipDirection.HORIZONTAL,
                    front: _buildCardFace(screen,
                        text: card.question,
                        backgroundColor: cardColor),
                    back: _buildCardFace(screen,
                        text: card.answer,
                        backgroundColor: cardColor),
                  ),
                ),
              );
            },
            upSwipeAllowed: false,
            fillSpace: true,
          ),
        ),
      ),
    );
  }

  Widget _buildCardFace(Size screen,
      {required String text, Color? backgroundColor}) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: screen.width * 0.85,
        maxHeight: screen.height * 0.60,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _CongratsPage extends StatelessWidget {
  final String lessonId;

  const _CongratsPage({Key? key, required this.lessonId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _appBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/stars.png', width: 400),
              SizedBox(height: 30),
              FutureBuilder<bool>(
                future: CoinManager.hasEarnedCoinsForLesson(lessonId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState !=
                      ConnectionState.done) {
                    return CircularProgressIndicator(color:  Color(0xFF609966));
                  }

                  final hasEarned = snapshot.data ?? false;
                  final message = hasEarned
                      ? "ممتاز!  أنت الآن جاهز لبدء رحلة الاستثمار"
                      : "تهانينا! تمت إضافة 10 عملات إلى رصيدك\nكل خطوة تعلم تقرّبك نحو النجاح";

                  return Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  bool hasEarned =
                  await CoinManager.hasEarnedCoinsForLesson(lessonId);
                  if (!hasEarned) {
                    await CoinManager.addCoin(10);
                    await CoinManager
                        .markCoinsAsEarnedForLesson(lessonId);
                  }
                  Navigator.pop(context, true);
                },
                child: Text("العودة للرئيسية", style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:  Color(0xFF609966),
                  foregroundColor: Colors.white,
                  padding:
                  EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
