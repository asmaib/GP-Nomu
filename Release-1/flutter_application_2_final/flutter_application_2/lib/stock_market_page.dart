import 'package:flutter/material.dart';
import 'home_page.dart';
import 'user_profile.dart';
import 'market_prediction_page.dart';
import 'portfolio_page.dart';
import 'Learning page.dart';

class MarketSimulationPage extends StatefulWidget {
  @override
  _MarketSimulationPageState createState() => _MarketSimulationPageState();
}

class _MarketSimulationPageState extends State<MarketSimulationPage> {
  // Changed the green to the new darker shade:
  static const Color _customGreen = Color(0xFF609966);

  int _selectedIndex = 2;
  String? selectedCompany;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage()));
    } else if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PortfolioPage()));
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
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: _customGreen,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text('المحاكاة', style: TextStyle(color: Colors.white, fontSize: 20)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MarketPredictionPage()));
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(30)),
                child: Center(
                  child: Text('توقعات السوق', style: TextStyle(color: Colors.grey, fontSize: 20)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyLogos() {
    final companies = [
      {'name': ' الراجحي', 'logo': 'assets/alrajhi.png'},
      {'name': ' ارامكو', 'logo': 'assets/aramco.png'},
      {'name': ' سابك', 'logo': 'assets/sabic.png'},
      {'name': ' المراعي', 'logo': 'assets/almarai.png'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: companies.map((company) {
        bool isSelected = selectedCompany == company['name'];
        return GestureDetector(
          onTap: () {
            setState(() {
              selectedCompany = isSelected ? null : company['name'];
            });
          },
          child: Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? _customGreen : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: _customGreen.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Image.asset(company['logo']!, width: 50),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDefaultMarketView() {
    return Column(
      children: [
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('نظرة عامة عن السوق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10)],
          ),
          child: Column(
            children: [
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Text('3.40', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 12),
                      Text('3.30', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 12),
                      Text('3.20', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 12),
                      Text('3.10', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 12),
                      Text('2.00', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 12),
                      Text('1.90', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 200,
                      child: Image.asset('assets/2025-03-188.png', fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('13.00'),
                  Text('14.00'),
                  Text('15.00'),
                  Text('16.00'),
                  Text('17.00'),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('الأكثر ارتفاعاً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        _buildRecommendationCard('assets/almarai.png', 'المراعي', '505.30', '10.3%', 'assets/chart_line.png', 'المراعي'),
        _buildRecommendationCard('assets/alrajhi.png', 'الراجحي', '460.10', '9.2%', 'assets/chart_line.png', 'الراجحي'),
      ],
    );
  }

  Widget _buildCompanyDetails(String companyName) {
    return Column(
      children: [
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'الرسم البياني لأسهم $companyName',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10)],
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Text('3.40', style: TextStyle(fontSize: 12)),
                            SizedBox(height: 12),
                            Text('3.30', style: TextStyle(fontSize: 12)),
                            SizedBox(height: 12),
                            Text('3.20', style: TextStyle(fontSize: 12)),
                            SizedBox(height: 12),
                            Text('3.10', style: TextStyle(fontSize: 12)),
                            SizedBox(height: 12),
                            Text('2.00', style: TextStyle(fontSize: 12)),
                            SizedBox(height: 12),
                            Text('1.90', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 200,
                            child: Image.asset('assets/2025-03-188.png', fit: BoxFit.contain),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('13.00'),
                        Text('14.00'),
                        Text('15.00'),
                        Text('16.00'),
                        Text('17.00'),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: Text('شراء', style: TextStyle(color: Colors.white)),
                    style: TextButton.styleFrom(
                      backgroundColor: _customGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: EdgeInsets.symmetric(horizontal: 32),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    child: Text('بيع', style: TextStyle(color: _customGreen)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _customGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: EdgeInsets.symmetric(horizontal: 32),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            ' $companyName عن  \n\n'
                '$companyName هي من الشركات الرائدة في السوق وتؤثر بشكل كبير على حركة الأسهم. '
                'يمكن أن تكون فرصة استثمارية جيدة حسب توجهات السوق.',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(
      String logoPath,
      String symbol,
      String price,
      String percentage,
      String chartImagePath,
      String companyName) {
    bool isSelected = selectedCompany == companyName;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCompany = isSelected ? null : companyName;
        });
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
                offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(chartImagePath, height: 30),
                Row(
                  children: [
                    Icon(Icons.arrow_drop_up, color: _customGreen),
                    Image.asset('assets/saudi_riyal_green.png', width: 18),
                    SizedBox(width: 4),
                    Text(price,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _customGreen)),
                    SizedBox(width: 4),
                    Text('($percentage)',
                        style: TextStyle(fontSize: 13, color: _customGreen)),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(symbol,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                  ],
                ),
                SizedBox(width: 12),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSelected)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _customGreen, width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: _customGreen.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 2),
                          ],
                        ),
                      ),
                    CircleAvatar(
                        radius: 24, backgroundImage: AssetImage(logoPath)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Updated bottom nav bar color
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: ''),
          BottomNavigationBarItem(
            icon: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _customGreen,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                      color: _customGreen.withOpacity(0.3),
                      blurRadius: 5,
                      spreadRadius: 2)
                ],
              ),
              child:
              Image.asset('assets/saudi_riyal.png', width: 30, height: 30),
            ),
            label: '',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
        ],
        selectedItemColor: _customGreen,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTabSwitcher(context),
              SizedBox(height: 10),
              Text('رصيدك الحالي',
                  style: TextStyle(
                      fontSize: 20,
                      color: _customGreen,
                      fontWeight: FontWeight.bold)),
             Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Image.asset('assets/saudi_riyal_green.png', height: 24),
    SizedBox(width: 6),
    Text(
      '10.000',
      style: TextStyle(
        fontSize: 30,
        color: _customGreen,
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
),

              Text('هذا الرصيد وهمي',
                  style: TextStyle(color: Colors.red, fontSize: 14)),
              Divider(),
              _buildCompanyLogos(),
              selectedCompany == null
                  ? _buildDefaultMarketView()
                  : _buildCompanyDetails(selectedCompany!),
            ],
          ),
        ),
      ),
    );
  }
}
