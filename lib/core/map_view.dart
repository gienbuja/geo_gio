import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geo_gio/misc/config.dart';
import 'package:geo_gio/core/history_view.dart';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geofence_foreground_service/exports.dart' as geofence;
import 'package:geofence_foreground_service/geofence_foreground_service.dart';
import 'package:geofence_foreground_service/models/zone.dart';
import 'package:geofence_foreground_service/constants/geofence_event_type.dart';
import 'package:geo_gio/misc/database_helper.dart';

var logger = Logger();

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'com.geo_gio.locate', // Define un ID de canal único
    'Recordatorio', // Define un nombre de canal
    channelDescription:
        'Notificaciones de cambio de zona', // Define una descripción del canal
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  GeofenceForegroundService().handleTrigger(
    backgroundTriggerHandler: (zoneID, triggerType) async {
      String zoneName = zoneID.split(' ').skip(1).join(' ');
      if (triggerType == GeofenceEventType.enter) {
        logger.i('Entra a zona $zoneName ');
        await flutterLocalNotificationsPlugin.show(
          1,
          'Ingresó a zona',
          'Has ingresado a la zona $zoneName',
          platformChannelSpecifics,
        );
      } else if (triggerType == GeofenceEventType.exit) {
        logger.i('Sale de zona $zoneName ');
        await flutterLocalNotificationsPlugin.show(
          2,
          'Salió de zona',
          'Has salido de la zona $zoneName',
          platformChannelSpecifics,
        );
      } else if (triggerType == GeofenceEventType.dwell) {
        logger.i('Permanece en zona $zoneName ');
        await flutterLocalNotificationsPlugin.show(
          3,
          'Continua en zona',
          'Has permanecido en la zona $zoneName por un tiempo',
          platformChannelSpecifics,
        );
      } else {
        logger.i(triggerType.toString());
      }
      return Future.value(true);
    },
  );
}

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  MapViewState createState() => MapViewState();
}

class MapViewState extends State<MapView> {
  int _selectedIndex = 0;
  late GoogleMapController mapController;
  final LatLng _center = const LatLng(10.3997, -75.5144);
  final List<Marker> _markers = [];
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _manualLocationTimer;
  DateTime? _lastManualLocationTime;
  Set<Polyline> polylines = {};
  Set<Polygon> polygons = {};
  final Set<Circle> _circles = {};
  bool hasServiceStarted = false;
  List<dynamic> zones = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _fetchLocations();
    _determinePosition();
    _initializeNotifications();
    _startManualLocationTimer();
    _startSyncTimer();
  }

  Future<void> initPlatformState() async {
    hasServiceStarted =
        await GeofenceForegroundService().startGeofencingService(
      contentTitle: 'La aplicación GeoGio está en ejecución',
      contentText:
          'La aplicación GeoGio está en ejecución y monitoreando tus ubicaciones.',
      notificationChannelId: 'com.app.geofencing_notifications_channel',
      serviceId: 525600,
      callbackDispatcher: callbackDispatcher,
    );
    if (hasServiceStarted) {
      await _fetchZones();
      await _setZones();
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  BitmapDescriptor _getIconFromString(String icon) {
    switch (icon) {
      case 'red':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case 'blue':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 'green':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 'yellow':
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow);
      case 'orange':
        return BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  void _onMapTapped(LatLng location) {
    TextEditingController titleController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    TextEditingController dateController = TextEditingController();
    TextEditingController timeController = TextEditingController();
    String selectedIcon = 'default';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Agregar actividad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration:
                    InputDecoration(labelText: 'Titulo de la actividad'),
                maxLength: 256,
              ),
              TextField(
                controller: descriptionController,
                decoration:
                    InputDecoration(labelText: 'Describe lo que hiciste'),
                maxLines: 3, // This makes the TextField act like a TextArea
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Icono de la actividad'),
                items: [
                  DropdownMenuItem(
                    value: 'red',
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Rojo'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'blue',
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Azul'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'green',
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Verde'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'yellow',
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.yellow),
                        SizedBox(width: 8),
                        Text('Amarillo'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'orange',
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Naranja'),
                      ],
                    ),
                  ),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    selectedIcon = newValue?.toString() ?? 'default';
                  });
                },
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
                String dateText = dateController.text;
                String timeText = timeController.text;
                DateTime localDateTime =
                    DateFormat("yyyy-MM-dd HH:mm").parse("$dateText $timeText");
                String utcDateTime = localDateTime.toUtc().toString();
                final savedLocation = {
                  'latitude': location.latitude,
                  'longitude': location.longitude,
                  'title': titleController.text,
                  'description': descriptionController.text,
                  'icon': selectedIcon,
                  'datetime': utcDateTime,
                  'manual': true,
                };
                await DatabaseHelper().insertLocation(savedLocation);

                setState(() {
                  _markers.add(
                    Marker(
                      markerId: MarkerId(savedLocation['id'].toString()),
                      position: LatLng(savedLocation['latitude'] as double,
                          savedLocation['longitude'] as double),
                      visible: true,
                      icon: _getIconFromString(selectedIcon),
                      infoWindow: InfoWindow(
                        title: savedLocation['title'] as String?,
                        snippet: savedLocation['description'] as String?,
                      ),
                    ),
                  );
                });
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _onMapLongPressed(LatLng location) {
    TextEditingController titleController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    TextEditingController radiusController = TextEditingController();
    String color = 'red';

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Agregar zona'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'Nombre de la zona'),
                  maxLength: 256,
                ),
                TextField(
                  controller: descriptionController,
                  decoration:
                      InputDecoration(labelText: 'Descripción de la zona'),
                  maxLines: 3, // This makes the TextField act like a TextArea
                ),
                TextField(
                  controller: radiusController,
                  decoration:
                      InputDecoration(labelText: 'Radio de la zona (metros)'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Color de la zona'),
                  items: [
                    DropdownMenuItem(
                      value: 'red',
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Rojo'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'blue',
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Azul'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'green',
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Verde'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'yellow',
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.yellow),
                          SizedBox(width: 8),
                          Text('Amarillo'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'orange',
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Naranja'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      color = newValue?.toString() ?? 'red';
                    });
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
                child: Text('Guardar'),
                onPressed: () async {
                  final zone = {
                    'latitude': location.latitude,
                    'longitude': location.longitude,
                    'name': titleController.text,
                    'radius': double.parse(radiusController.text),
                    'description': descriptionController.text,
                    'color': color,
                  };
                  await DatabaseHelper().insertZone(zone);
                  zones.add(zone);
                  _setZones();

                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
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

    if (response.statusCode == 200) {
      List<dynamic> locations = json.decode(response.body);
      _setLocations(locations);
    } else {
      logger.e(json.decode(response.body));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener las ubicaciones')),
      );
    }
  }

  Future<void> _setLocations(List locations) async {
    List<Marker> newMarkers = [];
    List<LatLng> positions = [];

    for (var location in locations) {
      if (location['manual'] == false) {
        positions.add(LatLng(location['latitude'], location['longitude']));
      } else {
        newMarkers.add(
          Marker(
            markerId: MarkerId(location['id'].toString()),
            position: LatLng(location['latitude'], location['longitude']),
            visible: location['visible'],
            icon: location['icon'] != null
                ? BitmapDescriptor.defaultMarkerWithHue(
                    location['icon'] == 'red'
                        ? BitmapDescriptor.hueRed
                        : location['icon'] == 'blue'
                            ? BitmapDescriptor.hueBlue
                            : location['icon'] == 'green'
                                ? BitmapDescriptor.hueGreen
                                : location['icon'] == 'yellow'
                                    ? BitmapDescriptor.hueYellow
                                    : location['icon'] == 'orange'
                                        ? BitmapDescriptor.hueOrange
                                        : BitmapDescriptor.hueRed)
                : BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(
              title: location['title'],
              snippet: location['description'],
            ),
          ),
        );
      }
    }

    setState(() {
      polylines.add(
        Polyline(
          polylineId: PolylineId('locations'),
          points: positions,
          color: Colors.blue,
          width: 3,
        ),
      );
      _markers.addAll(newMarkers);
    });
  }

  Future<void> _fetchZones() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('$apiUrl/zones'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 201) {
      logger.i(json.decode(response.body));
      zones = json.decode(response.body);

      _setZones();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener las zonas')),
      );
    }
  }

  Future<void> _setZones() async {
    for (var zone in zones) {
      _circles.add(
        Circle(
          circleId: CircleId(zone['id'].toString()),
          center: LatLng(zone['latitude'], zone['longitude']),
          radius: (zone['radius'] as int).toDouble(),
          fillColor: zone['color'] == 'red'
              ? Colors.red.withAlpha((0.5 * 255).toInt())
              : zone['color'] == 'blue'
                  ? Colors.blue.withAlpha((0.5 * 255).toInt())
                  : zone['color'] == 'green'
                      ? Colors.green.withAlpha((0.5 * 255).toInt())
                      : zone['color'] == 'yellow'
                          ? Colors.yellow.withAlpha((0.5 * 255).toInt())
                          : zone['color'] == 'orange'
                              ? Colors.orange.withAlpha((0.5 * 255).toInt())
                              : Colors.red.withAlpha((0.5 * 255).toInt()),
          strokeWidth: 2,
          strokeColor: zone['color'] == 'red'
              ? Colors.red
              : zone['color'] == 'blue'
                  ? Colors.blue
                  : zone['color'] == 'green'
                      ? Colors.green
                      : zone['color'] == 'yellow'
                          ? Colors.yellow
                          : zone['color'] == 'orange'
                              ? Colors.orange
                              : Colors.red,
        ),
      );
      await GeofenceForegroundService().addGeofenceZone(
        zone: Zone(
          id: '${zone['id']} ${zone['name']}',
          radius: (zone['radius'] as int).toDouble(),
          coordinates: [
            geofence.LatLng.degree(zone['latitude'], zone['longitude'])
          ],
        ),
      );
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verifica si los servicios de ubicación están habilitados.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Los servicios de ubicación están deshabilitados.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Los permisos de ubicación están denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Los permisos de ubicación están denegados permanentemente.');
    }

    // Solicita permiso para acceder a la ubicación en segundo plano
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always) {
        return Future.error(
            'Se requiere permiso de ubicación siempre para esta funcionalidad.');
      }
    }
    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualiza cada 10 metros
      timeLimit: Duration(minutes: 1), // Actualiza cada 1 minuto
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _updatePosition(position);
      },
    );
  }

  void _updatePosition(Position position) {
    LatLng newPosition = LatLng(position.latitude, position.longitude);
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('current_location'),
          position: newPosition,
          infoWindow: InfoWindow(title: 'Tu ubicación actual'),
        ),
      );
    });
    _savePosition(position);
  }

  Future<void> _savePosition(Position position) async {
    final location = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'datetime': DateTime.now().toUtc().toString(),
      'manual': 0,
    };
    await DatabaseHelper().insertLocation(location);
  }

  void _startSyncTimer() {
    Timer.periodic(Duration(minutes: 1), (timer) async {
      await _syncData();
    });
  }

  Future<void> _syncData() async {
    final dbHelper = DatabaseHelper();
    final unsyncedLocations = await dbHelper.getUnsyncedLocations();
    final unsyncedZones = await dbHelper.getUnsyncedZones();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');
    
    for (var zone in unsyncedZones) {
      final response = await http.post(
        Uri.parse('$apiUrl/zones'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(zone),
      );
      if (response.statusCode == 201) {
        await dbHelper.deleteZone(zone['id']);
      } else {
        logger.e('Error al sincronizar zona: ${response.body}');
      }
    }

    for (var location in unsyncedLocations) {
      final response = await http.post(
        Uri.parse('$apiUrl/locations'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(location),
      );
      if (response.statusCode == 201) {
        await dbHelper.deleteLocation(location['id']);
      } else {
        logger.e('Error al sincronizar ubicación: ${response.body}');
      }
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _initializeNotifications() async {
    // Verificar y solicitar permisos de notificación
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'com.geo_gio.reminder', // Define un ID de canal único
      'Recordatorio', // Define un nombre de canal
      channelDescription:
          'Notificaciones de recordatorio para agregar ubicaciones manuales', // Define una descripción del canal
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'Recordatorio GeoGio',
      'Hace rato no ingresas una ubicación manual. ¡Ingresa una ahora!',
      platformChannelSpecifics,
    );
  }

  void _startManualLocationTimer() {
    _manualLocationTimer?.cancel();
    _manualLocationTimer = Timer.periodic(Duration(minutes: 30), (timer) {
      if (_lastManualLocationTime == null ||
          DateTime.now().difference(_lastManualLocationTime!).inMinutes >= 30) {
        _showNotification();
        _lastManualLocationTime = DateTime.now();
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visor de recorrido'),
        backgroundColor: Colors.green[700],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 13.0,
            ),
            polylines: polylines,
            polygons: polygons,
            circles: _circles,
            myLocationEnabled: true,
            onTap: _onMapTapped,
            onLongPress: _onMapLongPressed,
            markers: Set<Marker>.of(_markers),
          ),
          HistoryView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
      //   bottomNavigationBar: BottomAppBar(
      //     color: Colors.green[700],
      //     shape: const CircularNotchedRectangle(),
      //     notchMargin: 6,
      //     child: Row(
      //       mainAxisAlignment: MainAxisAlignment.spaceAround,
      //       children: [
      //         IconButton(
      //           icon: const Icon(
      //             Icons.home,
      //             color: Colors.white,
      //           ),
      //           onPressed: () {},
      //         ),
      //         IconButton(
      //           icon: const Icon(
      //             Icons.history,
      //             color: Colors.white,
      //           ),
      //           onPressed: () {},
      //         ),
      //         const SizedBox(
      //           width: 20,
      //         ),
      //         IconButton(
      //           icon: const Icon(
      //             Icons.account_circle,
      //             color: Colors.white,
      //           ),
      //           onPressed: () {},
      //         ),
      //         IconButton(
      //           icon: const Icon(
      //             Icons.settings,
      //             color: Colors.white,
      //           ),
      //           onPressed: () {},
      //         ),
      //       ],
      //     ),
      //   ),
      //   floatingActionButton: FloatingActionButton(
      //       onPressed: () {},
      //       backgroundColor: Colors.amber,
      //       shape: const CircleBorder(),
      //       child: const Icon(Icons.add)),
      //   floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
