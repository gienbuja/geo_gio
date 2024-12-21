import 'package:flutter/material.dart';
import 'package:geo_gio/misc/notification_helper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:geo_gio/misc/config.dart';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:background_locator/background_locator.dart';
import 'package:background_locator/settings/locator_settings.dart' as locator;
import 'package:geo_gio/core/location_callback_handler.dart';
import 'package:background_locator/settings/android_settings.dart' as android;
import 'package:background_locator/settings/ios_settings.dart' as ios;
import 'dart:async';

var logger = Logger();

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  MapViewState createState() => MapViewState();
}

class MapViewState extends State<MapView> {
  late GoogleMapController mapController;
  LocationData? currentLocation;
  final Location location = Location();
  final LatLng _center = const LatLng(10.3997, -75.5144);
  List<Marker> _markers = [];
  Timer? _manualLocationTimer;
  DateTime? _lastManualLocationTime;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _fetchLocations();
    initBackgroundLocator();
    NotificationHelper.initialize();
    location.onLocationChanged.listen((LocationData loc) {
      setState(() {
        currentLocation = loc;
      });
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(loc.latitude!, loc.longitude!),
            zoom: 15.0,
          ),
        ),
      );
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    currentLocation = await location.getLocation();
  }

  void _onMapTapped(LatLng location) {
    TextEditingController commentController = TextEditingController();
    TextEditingController dateController = TextEditingController();
    TextEditingController timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Agregar actividad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: commentController,
                decoration:
                    InputDecoration(labelText: '¿Qué actividad realizaste?'),
              ),
              TextField(
                controller: dateController,
                decoration: InputDecoration(labelText: 'Fecha'),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (!mounted) return;
                  if (pickedDate != null) {
                    dateController.text = pickedDate.toString().split(' ')[0];
                  }
                },
              ),
              TextField(
                controller: timeController,
                decoration: InputDecoration(labelText: 'Hora'),
                onTap: () async {
                  TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (!mounted) return;
                  if (pickedTime != null) {
                    if (context.mounted) {
                    timeController.text = pickedTime.format(context);
                    }
                  }
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Enviar'),
              onPressed: () async {
                final SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                final String? token = prefs.getString('access_token');
                String dateText = dateController.text;
                String timeText = timeController.text;
                DateTime localDateTime =
                    DateFormat("yyyy-MM-dd HH:mm").parse("$dateText $timeText");
                String utcDateTime = localDateTime.toUtc().toString();
                final response = await http.post(
                  Uri.parse('$apiUrl/locations'),
                  headers: <String, String>{
                    'Content-Type': 'application/json; charset=UTF-8',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode(<String, dynamic>{
                    'latitude': location.latitude,
                    'longitude': location.longitude,
                    'comment': commentController.text,
                    'datetime': utcDateTime,
                    'manual': true,
                  }),
                );
                if (!context.mounted) return;
                if (response.statusCode == 201) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Datos enviados exitosamente')),
                  );
                  _lastManualLocationTime = DateTime.now();
                  _startManualLocationTimer();
                  Navigator.of(context).pop();
                } else {
                  logger.e(json.decode(response.body));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al enviar los datos')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchLocations() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('$apiUrl/locations'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      List<dynamic> locations = json.decode(response.body);
      setState(() {
        _markers = locations.map((location) {
          return Marker(
            markerId: MarkerId(location['id'].toString()),
            position: LatLng(location['latitude'], location['longitude']),
            infoWindow: InfoWindow(
              title: location['comment'],
              snippet: location['datetime'],
            ),
          );
        }).toList();
      });
    } else {
      logger.e(json.decode(response.body));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener las ubicaciones')),
      );
    }
  }

  void initBackgroundLocator() {
    BackgroundLocator.initialize();
    BackgroundLocator.registerLocationUpdate(
      LocationCallbackHandler.callback,
      initCallback: LocationCallbackHandler.initCallback,
      disposeCallback: LocationCallbackHandler.disposeCallback,
      autoStop: false,
      iosSettings: ios.IOSSettings(
        accuracy: locator.LocationAccuracy.NAVIGATION,
        distanceFilter: 0,
      ),
      androidSettings: android.AndroidSettings(
        accuracy: locator.LocationAccuracy.NAVIGATION,
        interval: 5,
        distanceFilter: 0,
        androidNotificationSettings: android.AndroidNotificationSettings(
          notificationChannelName: 'Location tracking',
          notificationTitle: 'Start Location Tracking',
          notificationMsg: 'Track location in background',
          notificationBigMsg: 'Background location tracking is active',
          notificationIcon: '',
          notificationIconColor: Colors.grey,
        ),
      ),
    );
  }

  void _startManualLocationTimer() {
    _manualLocationTimer?.cancel();
    _manualLocationTimer = Timer.periodic(Duration(minutes: 30), (timer) {
      if (_lastManualLocationTime == null ||
          DateTime.now().difference(_lastManualLocationTime!).inMinutes >= 30) {
        NotificationHelper.showNotification(
          title: 'Recordatorio',
          body: 'Hace rato no ingresas una ubicación manual.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visor de recorrido'),
        backgroundColor: Colors.green[700],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _center,
          zoom: 11.0,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onTap: _onMapTapped,
        markers: Set<Marker>.of(_markers),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.green[700],
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(
                Icons.home,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(
                Icons.history,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
            const SizedBox(
              width: 20,
            ),
            IconButton(
              icon: const Icon(
                Icons.account_circle,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
              ),
              onPressed: () {},
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: Colors.amber,
          shape: const CircleBorder(),
          child: const Icon(Icons.add)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
