import 'package:flutter/material.dart';
import 'package:geo_gio/auth/login_screen.dart';
import 'package:geo_gio/auth/register_screen.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Bienvenido a GeoGio',
              style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                // logger.i('Clic en ingresar');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              child: Text('Ingresar'),
            ),
            SizedBox(height: 10.0),
            ElevatedButton(
              onPressed: () {
                // logger.i('Clic en registrarse');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterScreen()),
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