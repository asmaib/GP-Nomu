import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'FlashcardPage.dart';
import 'Learning page.dart';

class InteractiveCardsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [

          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 175,
                color:  Color(0xFF609966)
              ),
              Positioned(
                left: 10,
                top: 30,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LearningPage()),
                    );
                  },
                ),
              ),
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    children: [
                      Image.asset('assets/cards_icon.png', height: 80),
                      SizedBox(height: 5),
                      Text(
                        'البطاقات التفاعلية',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'بطاقات تفاعلية',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(color: Colors.black, fontSize: 16),
                      children: [
                        TextSpan(
                          text: 'تعليمات اللعبة: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF609966),
                          ),
                        ),
                        TextSpan(
                          text:
                              'اللعبة بسيطة! أمامك بطاقات فيها معلومات عن الاستثمار. لو سحبت البطاقة لليمين، معناه أنك فهمت المعلومة، وما راح تتكرر كثير. ولو سحبتها لليسار، يعني محتاج تراجعها، وراح نشوفها معاك مرة ثانية.',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'كل ما تتقن بطاقات أكثر، تتقدم في اللعبة وتتعلم أكثر! جاهز نبدأ؟',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => FlashcardPage()),
                      );

                      if (result == true) {
                        Navigator.pop(context, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:  Color(0xFF609966),
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      shadowColor: Colors.black,
                      elevation: 5,
                    ),
                    child: Text(
                      'ابدأ اللعب',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
