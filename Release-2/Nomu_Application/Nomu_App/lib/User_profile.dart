import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'wallet_page.dart';
import 'home_page.dart';
import 'edit_profile_page.dart';
import 'login_page.dart';
import 'stock_market_page.dart';
import 'favorites_page.dart';
import 'portfolio_page.dart';
import 'Learning page.dart';
import 'combined_chat_screen.dart';

// Import the NEW Settings Page
import 'notification_settings_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String? _username;
  String? _email;
  bool _isLoading = true;

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
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) Navigator.push(context, MaterialPageRoute(builder: (context) => HomePage()));
    else if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (context) => LearningPage()));
    else if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (context) => MarketSimulationPage()));
    else if (index == 3) Navigator.push(context, MaterialPageRoute(builder: (context) => PortfolioPage()));
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
  }

  Future<void> _contactUs() async {
    final subject = Uri.encodeComponent('Nomu — Support Request');
    final body = Uri.encodeComponent('السلام عليكم فريق نمو,\r\n\r\nاكتب مشكلتك هنا...');
    final uri = Uri.parse('mailto:nmuapp6@gmail.com?subject=$subject&body=$body');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Handle error
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
              Text(_username ?? '...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor)),
              SizedBox(height: 4),
              Text(_email ?? '...', style: TextStyle(fontSize: 14, color: _subTextColor)),
              SizedBox(height: 24),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    _buildProfileOption(iconData: Icons.edit, title: 'تعديل معلوماتي الشخصية', onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfilePage(currentName: _username ?? '', currentEmail: _email ?? ''))).then((_) => _fetchUserData());
                    }),
                    _buildDivider(),

                    // ✨ UPDATED: Navigate to the new Settings Page
                    _buildNotificationOption(),

                    _buildDivider(),
                    _buildProfileOption(iconData: Icons.account_balance_wallet, title: 'المحفظة', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletPage()))),
                    _buildDivider(),
                    _buildProfileOption(iconData: Icons.favorite_border, title: 'قائمة المفضلة', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritesPage()))),
                    _buildDivider(),
                    _buildProfileOption(iconData: Icons.smart_toy, title: 'تحدث مع نمو', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CombinedChatScreen()))),
                    _buildDivider(),
                    _buildProfileOption(iconData: Icons.support_agent, title: 'مركز الدعم', onTap: _contactUs),
                  ],
                ),
              ),
              Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                onPressed: _showLogoutConfirmation,
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: StadiumBorder(), padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14)),
                  child: Text('تسجيل الخروج', style: TextStyle(fontSize: 16, color: Colors.white)),
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
                decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 5, spreadRadius: 2)]),
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

  // ✨ NEW WIDGET FOR NOTIFICATION SETTINGS
  Widget _buildNotificationOption() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationSettingsPage()),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.notifications, color: _primaryColor),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('إعدادات الإشعارات', style: TextStyle(fontSize: 16, color: _textColor))),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({required IconData iconData, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(iconData, color: _primaryColor)),
            SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, color: _textColor))),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => Container(height: 1, color: Colors.grey.withOpacity(0.3));

  void _showLogoutConfirmation() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.red.shade50,
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text(
                "تأكيد تسجيل الخروج",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          content: Text(
            "هل أنت متأكد أنك تريد تسجيل الخروج؟",
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "إلغاء",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _logout();
              },
              child: Text(
                "تأكيد",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

}