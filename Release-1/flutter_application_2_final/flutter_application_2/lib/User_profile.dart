import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';
import 'edit_profile_page.dart';
import 'login_page.dart';
import 'stock_market_page.dart';
import 'favorites_page.dart';
import 'portfolio_page.dart';
import 'Learning page.dart';
import 'combined_chat_screen.dart'; 

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String? _username;
  String? _email;
  bool _isLoading = true;

  // use the custom green everywhere
  final Color _primaryColor = Color(0xFF609966);
  final Color _textColor = Colors.black;
  final Color _subTextColor = Colors.grey;

  int _selectedIndex = 4;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            _username = doc.get('username') ?? 'اسم غير معروف';
            _email = doc.get('email') ?? 'لا يوجد بريد';
            _isLoading = false;
          });
        } else {
          setState(() {
            _username = 'اسم غير معروف';
            _email = 'لا يوجد بريد';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _username = 'اسم غير معروف';
          _email = 'لا يوجد بريد';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _username = 'اسم غير معروف';
        _email = 'لا يوجد بريد';
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage()));
    } else if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => LearningPage()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => MarketSimulationPage()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => PortfolioPage()));
    }
    // index 4 is current page
  }

  Future<void> _logout() async {
    bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Color.fromARGB(255, 236, 161, 160),
        title: Text(
          'تأكيد',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك بتسجيل الخروج؟',
          textAlign: TextAlign.right,
          style: TextStyle(color: Colors.black87, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('إلغاء', style: TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('تسجيل الخروج', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: Text('المزيد', style: TextStyle(color: _textColor)),
        ),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
            children: [
              SizedBox(height: 20),
              Text(
                _username ?? 'اسم غير معروف',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                _email ?? 'لا يوجد بريد',
                style: TextStyle(fontSize: 14, color: _subTextColor),
              ),
              SizedBox(height: 24),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    _buildProfileOption(
                      iconData: Icons.edit,
                      title: 'تعديل معلوماتي الشخصية',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfilePage(
                              currentName: _username ?? '',
                              currentEmail: _email ?? '',
                            ),
                          ),
                        ).then((_) => _fetchUserData());
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      iconData: Icons.account_balance_wallet,
                      title: 'المحفظة',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PortfolioPage()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      iconData: Icons.favorite_border,
                      title: 'قائمة المفضلة',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => FavoritesPage()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      iconData: Icons.smart_toy,
                      title: 'تحدث مع نمو',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CombinedChatScreen()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildProfileOption(
                      iconData: Icons.support_agent,
                      title: 'مركز الدعم',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: StadiumBorder(),
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  child: Text(
                    'تسجيل الخروج',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
            BottomNavigationBarItem(
              icon: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 5,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset('assets/saudi_riyal.png', width: 30, height: 30),
              ),
              label: '',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
          ],
          selectedItemColor: _primaryColor,
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData iconData,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: _primaryColor),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 16, color: _textColor)),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() =>
      Container(height: 1, color: Colors.grey.withOpacity(0.3));
}
