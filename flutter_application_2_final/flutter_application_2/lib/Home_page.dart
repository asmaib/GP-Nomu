import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile.dart';
import 'portfolio_page.dart';
import 'stock_market_page.dart';
import 'Learning page.dart';

import 'daily_questions.dart';
import 'combined_chat_screen.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 4;
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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final answered = doc['challenge_answered'] ?? false;
        final ts = (doc['challenge_timestamp'] as Timestamp?)?.toDate();
        if (answered && ts != null) {
          final diff = DateTime.now().difference(ts).inHours;
          if (diff >= 24) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'challenge_answered': false});
            setState(() => _challengeAnswered = false);
          } else {
            setState(() => _challengeAnswered = true);
          }
        } else {
          setState(() => _challengeAnswered = false);
        }
      }
    }
  }

  Future<void> _markChallengeAnswered() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final now = DateTime.now();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'challenge_answered': true,
        'challenge_timestamp': Timestamp.fromDate(now),
      });
      setState(() => _challengeAnswered = true);
    }
  }

  Future<String> _getUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.get('username') ?? '';
      }
    }
    return '';
  }

  Future<void> _storeDailyQuestionForUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final q = (dailyQuestions..shuffle()).first;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'daily_question_${user.uid}',
        jsonEncode({
          'text': q.text,
          'options': q.options,
          'correctAnswer': q.correctAnswer,
        }),
      );
    }
  }

  Future<Question> _getDailyQuestion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('daily_question_${user.uid}');
      if (saved != null) {
        final m = jsonDecode(saved);
        return Question(
          text: m['text'],
          options: List<String>.from(m['options']),
          correctAnswer: m['correctAnswer'],
        );
      }
    }
    await _storeDailyQuestionForUser();
    return _getDailyQuestion();
  }

  Future<void> _loadCoinCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() => _coinCount = doc.data()?['coins'] ?? 0);
    }
  }

  void _showQuestionDialog(Question question) {
    _selectedAnswer = null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Color(0xFF609966),
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Text(
                    'تحدي اليوم',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
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
                        side: BorderSide(color: Color(0xFF609966), width: 2),
                        foregroundColor: Color(0xFF609966),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('تخطي'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFF609966), width: 2),
                        foregroundColor: Color(0xFF609966),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
  void _showCorrectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Color(0xFF609966),
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
                    // add 5 coins to Firestore
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({'coins': FieldValue.increment(5)});
                    }
                    // update the coin counter locally
                    setState(() {
                      _coinCount += 5;
                    });
                    // close the dialog and mark the challenge as solved
                    Navigator.pop(context);
                    _markChallengeAnswered();
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
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, size: 64, color: Colors.black),
              SizedBox(height: 16),
              Text('إجابة خاطئة',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('الإجابة الصحيحة:',
                  style: TextStyle(color: Colors.black, fontSize: 18)),
              SizedBox(height: 6),
              Text(
                question.correctAnswer,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.red[700],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _markChallengeAnswered();
                },
                child:
                Text('موافق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int i) {
    setState(() => _selectedIndex = i);
    switch (i) {
      case 0:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => UserProfilePage()));
        break;
      case 1:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => PortfolioPage()));
        break;
      case 2:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => MarketSimulationPage()));
        break;
      case 3:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => LearningPage()));
        break;
    }
  }

  Widget _buildHeader() => FutureBuilder<String>(
    future: _getUsername(),
    builder: (ctx, snap) {
      final user = snap.data ?? '';
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.white),
              onPressed: () {},
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                user.isNotEmpty ? 'مرحبًا بك، $user' : 'مرحبًا بك',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    },
  );

  /// matches the exact style of the daily-challenge card
  Widget _buildChatbotCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CombinedChatScreen()),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFDAF0CF), Color(0xFF609966)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF609966),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.smart_toy, size: 32, color: Colors.white),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'تحدث مع نمو وتعلم عن الاستثمار',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ),
                // with this:
                Icon(Icons.arrow_back_ios, color: Colors.black54),

              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Color(0xFF609966),
    body: SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildBalanceCard(),
                    _buildChatbotCard(),
                    _buildChallengeCard(),
                    _buildTransactionsList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: _buildBottomNavBar(),
  );

  Widget _buildBalanceCard() => Padding(
    padding: EdgeInsets.all(16),
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 5,
              spreadRadius: 2)
        ],
      ),
      child: Column(children: [
        Text('الرصيد الإجمالي',
            style: TextStyle(fontSize: 18, color: Colors.grey)),
        SizedBox(height: 10),
        Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Image.asset('assets/saudi_riyal_black.png', height: 24),
    SizedBox(width: 6),
    Text('10,000.00',
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
  ],
),

        SizedBox(height: 20),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  children: [
    _buildStatItem('الخسارة', '3,000.00', Colors.red, 'assets/saudi_riyal_red.png'),
    _buildStatItem('الربح', '1,200.00', Color(0xFF609966), 'assets/saudi_riyal_green.png'),
  ],
),

      ]),
    ),
  );

Widget _buildStatItem(String label, String value, Color color, String iconPath) {
  return Column(
    children: [
      Text(label, style: TextStyle(color: Colors.grey, fontSize: 16)),
      SizedBox(height: 5),
      Row(
        children: [
          Image.asset(iconPath, height: 18),
          SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ],
  );
}



  Widget _buildChallengeCard() {
    if (_challengeAnswered) {
      // الحالة بعد الإجابة
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors:[Colors.white, Color(0xFFDAF0CF), Color(0xFF609966)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.check_circle, size: 48, color: Colors.white),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'لقد اجبت على تحدي اليوم',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      //  challenge status  "active" before the user answers
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              if (_todaysQuestion == null) {
                _todaysQuestion = await _getDailyQuestion();
              }
              _showQuestionDialog(_todaysQuestion!);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFFDAF0CF), Color(0xFF609966)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: EdgeInsets.all(16),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  // Trophy Icon
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF609966),
                      shape: BoxShape.circle,
                    ),
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.emoji_events, size: 32, color: Colors.white),
                  ),
                  SizedBox(width: 16),
                  // Text
                  Expanded(
                    child: Text(
                      'جاهز لتحدي اليوم ؟',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                  // arrow
                  // with this:
                  Icon(Icons.arrow_back_ios, color: Colors.black54),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildTransactionsList() => Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        Text('آخر العمليات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
       _buildTransactionItem('المراعي', '- 8.99%', Colors.red, 'assets/almarai.png'),
_buildTransactionItem('الراحجي', '+ 7.56%', Color(0xFF609966), 'assets/alrajhi.png'),

      ],
    ),
  );

Widget _buildTransactionItem(
    String name, String amount, Color color, String imagePath) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 8,
          spreadRadius: 1,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      textDirection: TextDirection.rtl, 
      children: [
        // Company img
        CircleAvatar(
          radius: 24,
          backgroundImage: AssetImage(imagePath),
        ),
        SizedBox(width: 12),

        // Company name 
        Expanded(
          child: Text(
            name,
            textAlign: TextAlign.right, 
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        // The Stock and the Amount
        Row(
          children: [
            Icon(
              amount.startsWith('+') ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: color,
              size: 30,
            ),
            SizedBox(width: 4),
            Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}




  Widget _buildBottomNavBar() => BottomNavigationBar(
    items: [
      BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
      BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: ''),
      BottomNavigationBarItem(
        icon: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF609966),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                  color: Color(0xFF609966).withOpacity(0.3),
                  blurRadius: 5,
                  spreadRadius: 2)
            ],
          ),
          child: Image.asset('assets/saudi_riyal.png', width: 30, height: 30),
        ),
        label: '',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
      BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
    ],
    selectedItemColor: Color(0xFF609966),
    unselectedItemColor: Colors.grey,
    currentIndex: _selectedIndex,
    type: BottomNavigationBarType.fixed,
    onTap: _onItemTapped,
  );
}
