import 'package:flutter/material.dart';
import 'package:my_app/main.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);

  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    print('AuthCheckScreen: Checking login status...');
    final isLoggedIn = await AuthService.isLoggedIn();
    print('AuthCheckScreen: isLoggedIn = $isLoggedIn');
    
    if (!mounted) return;
    
    if (isLoggedIn) {
      print('AuthCheckScreen: User is logged in, navigating to MainScreen');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    } else {
      print('AuthCheckScreen: User is not logged in, navigating to LoginScreen');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
} 