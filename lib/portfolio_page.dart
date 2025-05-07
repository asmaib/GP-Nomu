import 'package:flutter/material.dart';
import 'home_page.dart';
import 'stock_market_page.dart';
import 'user_profile.dart';
import 'Learning page.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({Key? key}) : super(key: key);

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  int _selectedIndex = 3;

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LearningPage()));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MarketSimulationPage()));
    } else if (index == 3) {
      // Already on Portfolio
    } else if (index == 4) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserProfilePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Header section
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Color(0xFF609966),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                padding: EdgeInsets.only(top: 60, bottom: 24, left: 16, right: 16),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/saudi_riyal.png', width: 20, height: 20),
                          SizedBox(width: 4),
                          Text(
                            '209,647.50',
                            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Image.asset('assets/portfolio_chart.png', height: 120),
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/saudi_riyal.png', width: 20, height: 20),
                          SizedBox(width: 4),
                          Text(
                            '168,249.67',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['1D', '1M', '3M', '1Y', '5Y'].map((e) {
                        bool isSelected = e == '1M';
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            e,
                            style: TextStyle(
                              color: isSelected ? Color(0xFF9DC08B) : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

             // Summary box
Container(
  margin: EdgeInsets.all(16),
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.grey.shade300),
  ),
  child: Column(
    children: [
      // الرصيد الرئيسي مع أيقونة
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 6),
          Text('10,000', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
          Image.asset('assets/saudi_riyal_black.png', height: 24),
        ],
      ),
      SizedBox(height: 12),

      // الأرباح والخسائر
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_downward, color: Colors.red),
              SizedBox(width: 4),
              SizedBox(width: 4),
              Text('66,379 (24.65%)',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  Image.asset('assets/saudi_riyal_red.png', height: 18),
            ],
          ),
          Row(
            children: [
              Icon(Icons.arrow_upward, color: Color(0xFF9DC08B)),
              SizedBox(width: 4),
              SizedBox(width: 4),
              Text('66,379 (24.65%)',
                  style: TextStyle(color: Color(0xFF9DC08B), fontWeight: FontWeight.bold)),
                  Image.asset('assets/saudi_riyal_green.png', height: 18),
            ],
          ),
        ],
      )
    ],
  ),
),

              // حسابي section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'حسابي',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildStatItem('الطلبات المعلقة', ' 23,087 ', Icons.access_time, Colors.orange.shade100)),
                        SizedBox(width: 12),
                        Expanded(child: _buildStatItem('الرصيد المتاح', ' 23,087 ', Icons.account_balance_wallet, Colors.blue.shade100)),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildStatItem('إجمالي الأرباح', ' 23,087 ', Icons.show_chart, Color(0xFF9DC08B))),
                        SizedBox(width: 12),
                        Expanded(child: _buildStatItem('إجمالي المحفظة', ' 23,087 ', Icons.pie_chart, Colors.red.shade100)),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // استثماراتي الحالية section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'استثماراتي الحالية',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: 12),
              _buildInvestmentCard('الراجحي', '505.30', '10.3%', 'assets/chart_line.png', 'assets/alrajhi.png'),
              _buildInvestmentCard('المراعي', '405.20', '9.1%', 'assets/chart_line.png', 'assets/almarai.png'),
              SizedBox(height: 30),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor:Color(0xFF609966),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:Color(0xFF609966),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [BoxShadow(color: Color(0xFF9DC08B).withOpacity(0.3), blurRadius: 5, spreadRadius: 2)],
                ),
                child: Image.asset('assets/saudi_riyal.png', width: 30, height: 30),
              ),
              label: '',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
          ],
        ),
      ),
    );
  }

Widget _buildStatItem(String title, String value, IconData icon, Color bgColor) {
  bool showRiyalIcon = title != 'الطلبات المعلقة';

  return Container(
    padding: EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      children: [
        CircleAvatar(
          backgroundColor: bgColor,
          child: Icon(icon, color: Colors.black),
        ),
        SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 14, color: Colors.grey)),
        SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
           
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
             if (showRiyalIcon) ...[
              Image.asset('assets/saudi_riyal_black.png', height: 16),
              SizedBox(width: 4),
            ],
          ],
        ),
      ],
    ),
  );
}



  Widget _buildInvestmentCard(String company, String price, String percentage, String chartImage, String logoPath) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 6, spreadRadius: 2)],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundImage: AssetImage(logoPath)),
          SizedBox(width: 12),
          Text(company, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(chartImage, height: 24),
              Row(
                children: [
                  Icon(Icons.arrow_drop_up, color: Color(0xFF9DC08B)),
                  Row(
                    children: [
                      Image.asset('assets/saudi_riyal_green.png', width: 18, height: 18),
                      SizedBox(width: 4),
                      Text(price, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9DC08B))),
                    ],
                  ),
                  SizedBox(width: 4),
                  Text('($percentage)', style: TextStyle(color: Color(0xFF9DC08B))),
                ],
              ),
            ],
          ),
          SizedBox(width: 12),
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4)],
            ),
            child: Icon(Icons.favorite_border, color:Color(0xFF609966)),
          ),
        ],
      ),
    );
  }
}
