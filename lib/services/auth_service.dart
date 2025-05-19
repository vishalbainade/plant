import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _token;
  String? _userId;
  String? _username;
  String? _email;

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  String? get userId => _userId;
  String? get username => _username;
  String? get email => _email;

  // Base URL for API calls
  final String baseUrl = 'http://192.168.60.15:5000/api/auth'; // Replace with your PC's IP
  // Use 'http://localhost:3000/api/auth' for web or iOS simulator

  // Initialize auth state from shared preferences
  Future<void> initAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if token exists and is not expired
    final tokenExpiry = prefs.getInt('tokenExpiry');
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    if (tokenExpiry != null && currentTime < tokenExpiry) {
      // Token is valid
      _token = prefs.getString('token');
      _userId = prefs.getString('userId');
      _username = prefs.getString('username');
      _email = prefs.getString('email');
      _isLoggedIn = _token != null;
    } else {
      // Token is expired or doesn't exist, clear stored data
      await logout();
    }
    
    notifyListeners();
  }

  // Register a new user
  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Registration successful'};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Registration failed',
        };
      }
    } catch (error) {
      if (error.toString().contains('Connection refused') ||
          error.toString().contains('Failed host lookup') ||
          error.toString().contains('SocketException')) {
        return {'success': false, 'message': 'Cannot connect to server. Please check your internet connection or server status.'};
      }
      return {'success': false, 'message': 'Network error: $error'};
    }
  }

  // Login a user
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);
      
      // Check if the response has the expected format
      if (response.statusCode == 200) {
        // Handle different response formats
        String? token = data['token'];
        String? userId = data['user']?['id']?.toString() ?? data['userId'];
        String? username = data['user']?['username'] ?? data['username'];
        
        if (token != null) {
          _token = token;
          _userId = userId;
          _username = username;
          _email = email;
          _isLoggedIn = true;
          
          // Save to shared preferences with expiration date (30 days from now)
          final prefs = await SharedPreferences.getInstance();
          final expiryDate = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
          
          await prefs.setString('token', _token!);
          await prefs.setString('userId', _userId ?? '');
          await prefs.setString('username', _username ?? '');
          await prefs.setString('email', _email!);
          await prefs.setBool('isLoggedIn', true);
          await prefs.setInt('tokenExpiry', expiryDate);
          
          notifyListeners();
          return {'success': true};
        }
      }
      
      // If we reach here, something went wrong
      return {
        'success': false,
        'message': data['message'] ?? 'Login failed',
      };
    } catch (error) {
      print('Login error: $error');
      
      // For testing purposes, if server is unavailable, use mock login
      if (error.toString().contains('Connection refused') ||
          error.toString().contains('Failed host lookup') ||
          error.toString().contains('SocketException')) {
        print('Server unavailable, using mock login');
        return await mockLogin(email, password);
      }
      
      return {
        'success': false,
        'message': 'An error occurred during login: ${error.toString()}',
      };
    }
  }

  // Logout the current user
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _username = null;
    _email = null;
    _isLoggedIn = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('isLoggedIn');
    await prefs.remove('tokenExpiry');
    
    notifyListeners();
  }

  // Mock login for testing without backend
  Future<Map<String, dynamic>> mockLogin(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (email == 'test@example.com' && password == 'password123') {
      _token = 'mock_token';
      _userId = 'mock_user_id';
      _username = 'Test User';
      _email = email;
      _isLoggedIn = true;

      // Save to shared preferences with expiration date
      final prefs = await SharedPreferences.getInstance();
      final expiryDate = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
      
      await prefs.setString('token', _token!);
      await prefs.setString('userId', _userId!);
      await prefs.setString('username', _username!);
      await prefs.setString('email', _email!);
      await prefs.setBool('isLoggedIn', true);
      await prefs.setInt('tokenExpiry', expiryDate);

      notifyListeners();
      return {'success': true, 'message': 'Login successful'};
    } else {
      return {'success': false, 'message': 'Invalid email or password'};
    }
  }
}