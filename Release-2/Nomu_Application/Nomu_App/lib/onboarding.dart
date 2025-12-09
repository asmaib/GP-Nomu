import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'signup_page.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "image": "assets/images/on_boarding_images/firstbording.png",
      "title": "! ابدأ رحلتك الاستثمارية",
      "description":
          "ما عندك خبرة في الاستثمار؟ نمو يساعدك تبدأ بثقة، مع شرح بسيط وتقديم محاكاة لتجربة السوق بأمان"
    },
    {
      "image": "assets/images/on_boarding_images/secondbording.png",
      "title": "! تعلم وجرب بدون خوف",
      "description":
          "استخدم المحاكي الاستثماري وابدأ تداول الأسهم بأموال وهمية. الخسارة؟ لا تخاف، تقدر تعيد المحفظة بكل سهولة"
    },
    {
      "image": "assets/images/on_boarding_images/thierdbording.png",
      "title": "جاهز تبدأ؟",
      "description":
          "استعد للانطلاق في عالم الاستثمار. جرب استراتيجياتك، تعلم وتطور بدون أي مخاطرة حقيقية"
    },
  ];

  void _goToNextPage() {
    if (_currentPage < onboardingData.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to Signup Page when on the last onboarding page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignupPage()),
      );
    }
  }

  void _skipOnboarding() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SignupPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: Color(0xFF609966)),
                onPressed: () {
                  _pageController.previousPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: onboardingData.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) => OnboardingContent(
                image: onboardingData[index]["image"]!,
                title: onboardingData[index]["title"]!,
                description: onboardingData[index]["description"]!,
              ),
            ),
          ),
          SmoothPageIndicator(
            controller: _pageController,
            count: onboardingData.length,
            effect: ExpandingDotsEffect(
              activeDotColor: Color(0xFF609966),
              dotColor: Colors.grey,
              dotHeight: 8,
              dotWidth: 8,
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF609966),
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _goToNextPage,
                  child: Text(
                    "التالي",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    "تخطي",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontFamily: "Poppins",
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }
}

class OnboardingContent extends StatelessWidget {
  final String image, title, description;

  const OnboardingContent({
    required this.image,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFamily: "Poppins",
            ),
          ),
          SizedBox(height: 20),
          Image.asset(
            image,
            height: 340,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
              fontFamily: "Poppins",
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}