import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For JSON encoding/decoding

class AuthService {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _currentUsernameKey = 'currentUsername';
  static const String _usersKey = 'users'; // Key for storing user credentials

  // In-memory storage for user credentials (username, password)
  static Map<String, String> _users = {};

  static Future<void> init() async {
    print('AuthService.init: Starting initialization.');
    final prefs = await SharedPreferences.getInstance();
    
    // Always initialize _users from SharedPreferences
    final usersJson = prefs.getString(_usersKey);
    print('AuthService.init: Raw users data from SharedPreferences: $usersJson');
    
    if (usersJson != null && usersJson.isNotEmpty) {
      try {
        _users = Map<String, String>.from(json.decode(usersJson));
        print('AuthService.init: Successfully loaded users from SharedPreferences.');
        print('AuthService.init: Users count: ${_users.length}');
        print('AuthService.init: Users data: $_users');
      } catch (e) {
        print('AuthService.init: Error decoding users JSON: $e');
        _users = {}; // Fallback to empty map on error
      }
    } else {
      _users = {}; // Ensure _users is empty if no data is found or empty
      print('AuthService.init: No users data found or data is empty in SharedPreferences.');
    }

    // These lines should remain commented out or removed as previously instructed
    // await prefs.setBool(_isLoggedInKey, false);
    // await prefs.remove(_currentUsernameKey);

    print('AuthService.init: isLoggedIn (after init logic): ${prefs.getBool(_isLoggedInKey)}');
    print('AuthService.init: currentUsername (after init logic): ${prefs.getString(_currentUsernameKey)}');
  }

  static Future<bool> login(String username, String password) async {
    print('AuthService.login: Attempting login for username: $username');
    print('AuthService.login: Current users in memory: $_users');
    
    final prefs = await SharedPreferences.getInstance();
    if (_users.containsKey(username) && _users[username] == password) {
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_currentUsernameKey, username);
      print('AuthService.login: Successfully logged in.');
      print('AuthService.login: isLoggedIn: ${await prefs.getBool(_isLoggedInKey)}');
      print('AuthService.login: currentUsername: ${await prefs.getString(_currentUsernameKey)}');
      return true;
    }
    print('AuthService.login: Login failed for username: $username');
    return false;
  }

  static Future<bool> signup(String username, String password) async {
    print('AuthService.signup: Attempting signup for username: $username');
    print('AuthService.signup: Current users in memory: $_users');
    
    final prefs = await SharedPreferences.getInstance();
    if (_users.containsKey(username)) {
      print('AuthService.signup: Username $username already exists.');
      return false;
    }

    try {
      // Update in-memory users map
      _users[username] = password;
      
      // Save to SharedPreferences
      final usersJson = json.encode(_users);
      print('AuthService.signup: Saving users data to SharedPreferences: $usersJson');
      
      final success = await prefs.setString(_usersKey, usersJson);
      if (!success) {
        print('AuthService.signup: Failed to save users data to SharedPreferences');
        return false;
      }
      
      // Set login state
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_currentUsernameKey, username);
      
      print('AuthService.signup: Successfully signed up and saved data.');
      print('AuthService.signup: isLoggedIn: ${await prefs.getBool(_isLoggedInKey)}');
      print('AuthService.signup: currentUsername: ${await prefs.getString(_currentUsernameKey)}');
      print('AuthService.signup: Updated users in memory: $_users');
      
      return true;
    } catch (e) {
      print('AuthService.signup: Error during signup: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    print('AuthService.logout: Starting logout process');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove(_currentUsernameKey);
    print('AuthService.logout: Successfully logged out');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getBool(_isLoggedInKey) ?? false;
    print('AuthService.isLoggedIn: Retrieved status: $status');
    return status;
  }

  static Future<String?> getCurrentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_currentUsernameKey);
    print('AuthService.getCurrentUsername: Retrieved username: $username');
    return username;
  }
} 