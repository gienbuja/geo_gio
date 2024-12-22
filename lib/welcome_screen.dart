import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geo_gio/auth/login_screen.dart';
import 'package:geo_gio/auth/register_screen.dart';
import 'package:geo_gio/core/map_view.dart';
import 'package:geo_gio/misc/config.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import 'package:logger/logger.dart';

var logger = Logger();

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  WelcomeScreenState createState() => WelcomeScreenState();
}

class WelcomeScreenState extends State<WelcomeScreen> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');
    if (token != null) {
      final response = await http.get(
        Uri.parse('$apiUrl/user'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      logger.i(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _userData = json.decode(response.body);
          _isAuthenticated = true;
        });
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido'),
      ),
      body: Center(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _isAuthenticated
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '¡Bienvenido!',
                        style: TextStyle(
                            fontSize: 24.0, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_userData?['name']}',
                        style: TextStyle(
                          fontSize: 24.0,
                        ),
                      ),
                      SizedBox(height: 20.0),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => MapView()),
                          );
                        },
                        child: Text('Ir al mapa'),
                      ),
                      SizedBox(height: 50.0),
                      Text(
                        'No eres tu?',
                        style: TextStyle(
                          fontSize: 24.0,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final SharedPreferences prefs =
                              SharedPreferences.getInstance()
                                  as SharedPreferences;
                          prefs.remove('access_token');
                          final Database db =
                              await openDatabase('my_database.db');
                          await db.delete('locations');
                          await db.delete('zones');
                          if (context.mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => WelcomeScreen()),
                            );
                          }
                        },
                        icon: Icon(Icons.logout),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'Bienvenido a GeoGio',
                        style: TextStyle(
                            fontSize: 24.0, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20.0),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => LoginScreen()),
                          );
                        },
                        child: Text('Ingresar'),
                      ),
                      SizedBox(height: 10.0),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => RegisterScreen()),
                          );
                        },
                        child: Text('Registrarse'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
