import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'User_profile.dart';
import 'Home_page.dart';
import 'LessonPage.dart';
import 'InteractiveCardsPage.dart';
import 'stock_market_page.dart';
import 'portfolio_page.dart';
import 'daily_questions.dart';
import 'FlashcardWidget.dart';
import 'package:flutter_application_2/CoinManager.dart';

class LearningPage extends StatefulWidget {
  @override
  _LearningPageState createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  int _selectedIndex = 3;
  bool _challengeAnswered = false;
  Question? _todaysQuestion;
  String? _selectedAnswer;
  int _coinCount = 0;

  @override
  void initState() {
    super.initState();
    _loadChallengeStatus();
    _initializeDailyQuestion();
    _loadCoinCount();
  }

  Future<void> _initializeDailyQuestion() async {
    _todaysQuestion = await _getDailyQuestion();
  }

  Future<void> _loadChallengeStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final challengeAnswered = userDoc['challenge_answered'] ?? false;
        final timestamp = (userDoc['challenge_timestamp'] as Timestamp?)?.toDate();

        if (challengeAnswered && timestamp != null) {
          final difference = DateTime.now().difference(timestamp).inHours;
          if (difference >= 24) {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'challenge_answered': false,
            });
            setState(() {
              _challengeAnswered = false;
            });
          } else {
            setState(() {
              _challengeAnswered = true;
            });
          }
        } else {
          setState(() {
            _challengeAnswered = false;
          });
        }
      }
    }
  }

  Future<void> _markChallengeAnswered() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final answeredKey = 'challenge_answered_${user?.uid}_$today';
    final timestampKey = 'challenge_timestamp_${user?.uid}_$today';

    await prefs.setBool(answeredKey, true);
    await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

    setState(() {
      _challengeAnswered = true;
    });

    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'challenge_answered': true,
        'challenge_timestamp': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  Future<void> _storeDailyQuestionForUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final randomQuestion = (dailyQuestions..shuffle()).first;
      final prefs = await SharedPreferences.getInstance();
      final toSave = jsonEncode({
        'text': randomQuestion.text,
        'options': randomQuestion.options,
        'correctAnswer': randomQuestion.correctAnswer,
      });
      await prefs.setString('daily_question_${user.uid}', toSave);
    }
  }

  Future<Question> _getDailyQuestion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('daily_question_${user.uid}');
      if (savedData != null) {
        final savedMap = jsonDecode(savedData);
        return Question(
          text: savedMap['text'],
          options: List<String>.from(savedMap['options']),
          correctAnswer: savedMap['correctAnswer'],
        );
      }
    }
    await _storeDailyQuestionForUser();
    return _getDailyQuestion();
  }

  Future<void> _loadCoinCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _coinCount = doc.data()?['coins'] ?? 0;
      });
    }
  }

  void _showQuestionDialog(Question question) {
    _selectedAnswer = null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color:  Color(0xFF609966),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Text(
                      'تحدي اليوم',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    question.text,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 16),
                  ...question.options.map((opt) {
                    return RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.trailing,
                      title: Text(opt, textAlign: TextAlign.right),
                      value: opt,
                      groupValue: _selectedAnswer,
                      onChanged: (v) => setState(() => _selectedAnswer = v),
                    );
                  }).toList(),
                  SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedAnswer == null
                            ? null
                            : () {
                          Navigator.pop(ctx);
                          if (_selectedAnswer == question.correctAnswer)
                            _showCorrectDialog();
                          else
                            _showWrongAnswerDialogWithCorrect(question);
                        },
                        child: Text('إرسال'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color:  Color(0xFF609966), width: 2),
                          foregroundColor:  Color(0xFF609966),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: Colors.white, // optional: white fill
                        ),
                      ),

                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('تخطي'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color:  Color(0xFF609966), width: 2),
                          foregroundColor:  Color(0xFF609966),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: Colors.white, // optional: white fill
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
  void _showCorrectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.green[700],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.white),
              SizedBox(height: 16),
              Text(
                'يا سلام عليك! إجابة صحيحة وربحت 5 عملات إضافية',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF609966),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({'coins': FieldValue.increment(5)});
                    }

                    await _markChallengeAnswered(); // Save answered state

                    setState(() {
                      _coinCount += 5;
                      _challengeAnswered = true; // Update UI state
                    });

                    Navigator.pop(context); // Close dialog after all updates
                  },
                  child: Text(
                    'موافق',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWrongAnswerDialogWithCorrect(Question question) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.red[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.cancel_outlined, size: 64, color: Colors.black),
              SizedBox(height: 16),
              Text(
                'إجابة خاطئة',
                style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('الإجابة الصحيحة:', style: TextStyle(color: Colors.black, fontSize: 18)),
              SizedBox(height: 6),
              Text(
                question.correctAnswer,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _markChallengeAnswered();
                  },
                  child: Text('موافق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => UserProfilePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PortfolioPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MarketSimulationPage()),
        );
        break;
      case 3:
      // already on LearningPage
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
        );
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.5;
    final spacingBetweenCards = screenWidth * 0.05;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, // allow header to draw behind status bar
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                color: Color(0xFF609966),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF9DC08B).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Image.asset('assets/coins.png', width: 30),
                        SizedBox(width: 10),
                        Text(
                          '$_coinCount',
                          style: TextStyle(
                            color:  Color(0xFF609966),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "مرحباً بك في قسم التعلم",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacingBetweenCards),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: _buildCard('البطاقات التفاعلية', 'assets/cards_icon.png', () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => InteractiveCardsPage()),
                      );
                      if (result == true) {
                        final latest = await CoinManager.getCoins();
                        setState(() {
                          _coinCount = latest;
                        });
                      }
                    }, cardWidth),
                  ),
                  SizedBox(width: spacingBetweenCards),
                  Flexible(
                    child: _challengeAnswered
                        ? _buildCheckCard('تم حل تحدي اليوم', Icons.check_circle, cardWidth)
                        : _buildCard('جاهز لحل تحدي اليوم؟', 'assets/questions_icon.png', () async {
                      if (_todaysQuestion == null) {
                        _todaysQuestion = await _getDailyQuestion();
                      }
                      _showQuestionDialog(_todaysQuestion!);
                    }, cardWidth),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Color(0xFF9DC08B), thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      "الدروس التعليمية",
                      style:
                      TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 20),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFF9DC08B), thickness: 1)),
                ],
              ),
            ),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 11,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
                padding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildLessonCard('أنواع الاستثمار', 'assets/introduction.png', () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => LessonPage(lessonDocId: 'second')));
                  }),
                  _buildLessonCard('مقدمة عن الاستثمار', 'assets/investments.png', () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => LessonPage(lessonDocId: 'first')));
                  }),
                  _buildLessonCard('التخطيط المالي وأهداف الاستثمار', 'assets/trading.png', () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => LessonPage(lessonDocId: 'fourth')));
                  }),
                  _buildLessonCard('استراتيجيات الاستثمار', 'assets/risks.png', () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => LessonPage(lessonDocId: 'third')));
                  }),
                  Container(),
                  _buildLessonCard('التحليل الفني', 'assets/Graphs.png', () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => LessonPage(lessonDocId: 'fifth')));
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildCard(
      String text, String imagePath, Future<void> Function()? onTap, double width) {
    return GestureDetector(
      onTap: () async {
        if (onTap != null) await onTap();
      },
      child: Container(
        width: width,
        height: width * 0.75,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: width * 0.35),
            SizedBox(height: 15),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: width * 0.08, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckCard(String text, IconData icon, double width) {
    return Container(
      width: width,
      height: width * 0.75,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: width * 0.20, color:  Color(0xFF609966)),
          SizedBox(height: 35),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: width * 0.08, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(String title, String imagePath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color:  Color(0xFF609966), width: 2),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5, spreadRadius: 2)],
        ),
        child: Column(
          children: [
          ClipRRect(
  borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
  child: Container(
    color: Color(0xFFE9DC08B), // Background color behind the image
    height: 130,
    width: double.infinity,
    child: Image.asset(
      imagePath,
      fit: BoxFit.cover,
    ),
  ),
),

            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 2),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: ''),
        BottomNavigationBarItem(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:  Color(0xFF609966),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(color: Color(0xFF9DC08B).withOpacity(0.3), blurRadius: 5, spreadRadius: 2),
              ],
            ),
            child: Image.asset('assets/saudi_riyal.png', width: 30, height: 30),
          ),
          label: '',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
      ],
      selectedItemColor:  Color(0xFF609966),
      unselectedItemColor: Colors.grey,
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed,
      onTap: _onItemTapped,
    );
  }
}
