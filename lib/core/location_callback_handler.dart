
import 'package:background_locator/location_dto.dart';
import 'package:geo_gio/misc/config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:logger/logger.dart';

var logger = Logger();

class LocationCallbackHandler {
  static Future<void> initCallback(Map<dynamic, dynamic> params) async {
    logger.i('Locator init');
  }

  static Future<void> disposeCallback() async {
    logger.i('Locator dispose');
  }

  static Future<void> callback(LocationDto locationDto) async {
    logger.i('Location received: ${locationDto.latitude}, ${locationDto.longitude}');
    await _sendLocation(locationDto.latitude, locationDto.longitude);
  }

  static Future<void> _sendLocation(double latitude, double longitude) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');
    // final String apiUrl = '$apiUrl/locations';

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/locations'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(<String, dynamic>{
          'latitude': latitude,
          'longitude': longitude,
          'manual': false,
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to send location');
      }
    } catch (e) {
      await _saveLocationLocally(latitude, longitude);
    }
  }

  static Future<void> _saveLocationLocally(double latitude, double longitude) async {
    final database = await _openDatabase();
    await database.insert(
      'locations',
      {'latitude': latitude, 'longitude': longitude, 'manual': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Database> _openDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'locations.db');
    return openDatabase(
      path,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE locations(id INTEGER PRIMARY KEY, latitude REAL, longitude REAL, manual INTEGER)',
        );
      },
      version: 1,
    );
  }
}