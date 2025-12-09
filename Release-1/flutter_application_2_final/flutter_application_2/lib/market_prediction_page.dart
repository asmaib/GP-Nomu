import 'package:flutter/material.dart';
import 'home_page.dart';
import 'user_profile.dart';
import 'stock_market_page.dart';
import 'portfolio_page.dart';
import 'Learning page.dart';

class MarketPredictionPage extends StatefulWidget {
  @override
  _MarketPredictionPageState createState() => _MarketPredictionPageState();
}

class _MarketPredictionPageState extends State<MarketPredictionPage> {
  int _selectedIndex = 2;
  // Updated to the darker green:
  static const Color _customGreen = Color(0xFF609966);

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage()));
    } else if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PortfolioPage()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MarketSimulationPage()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => LearningPage()));
    } else if (index == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => HomePage()));
    }
  }

  Widget _buildTabSwitcher(BuildContext context) {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MarketSimulationPage()));
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text('المحاكاة', style: TextStyle(color: Colors.grey, fontSize: 20)),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _customGreen,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text('توقعات السوق', style: TextStyle(color: Colors.white, fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPredictionCard({
    required String logoPath,
    required String company,
    required String price,
    required String percentage,
    required String chartImagePath,
    required bool isUp,
    required bool isRecommended,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, spreadRadius: 1, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: isUp ? _customGreen : Colors.red,
            size: 32,
          ),
          SizedBox(width: 4),
    Row(
  children: [
    Image.asset(
      isUp ? 'assets/saudi_riyal_green.png' : 'assets/saudi_riyal_red.png',
      width: 18,
      height: 18,
    ),
    SizedBox(width: 4),
    Text(
      price,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isUp ? _customGreen : Colors.red,
      ),
    ),
  ],
),

          SizedBox(width: 6),
          Text(
            '($percentage)',
            style: TextStyle(
              fontSize: 14,
              color: isUp ? _customGreen : Colors.red,
            ),
          ),
          Spacer(),
          Text(company, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          CircleAvatar(backgroundImage: AssetImage(logoPath)),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isRecommended ? _customGreen.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isRecommended ? 'اشتري' : 'لا تشتري',
              style: TextStyle(
                color: isRecommended ? _customGreen : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTabSwitcher(context),
            Expanded(
              child: ListView(
                children: [
                  buildPredictionCard(
                    logoPath: 'assets/almarai.png',
                    company: 'المراعي',
                    price: '505.30',
                    percentage: '10.3%',
                    chartImagePath: 'assets/chart_line.png',
                    isUp: true,
                    isRecommended: true,
                  ),
                  buildPredictionCard(
                    logoPath: 'assets/alrajhi.png',
                    company: 'الراجحي',
                    price: '460.10',
                    percentage: '9.2%',
                    chartImagePath: 'assets/chart_line.png',
                    isUp: true,
                    isRecommended: true,
                  ),
                  buildPredictionCard(
                    logoPath: 'assets/aramco.png',
                    company: 'ارامكو',
                    price: '103.20',
                    percentage: '0.3%',
                    chartImagePath: 'assets/chart_line_red.png',
                    isUp: false,
                    isRecommended: false,
                  ),
                  // … add more cards as needed …
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: _customGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: ''),
          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _customGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: _customGreen.withOpacity(0.3), blurRadius: 5, spreadRadius: 2),
                ],
              ),
              child: Image.asset('assets/saudi_riyal.png', width: 30, height: 30),
            ),
            label: '',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
        ],
      ),
    );
  }
}
