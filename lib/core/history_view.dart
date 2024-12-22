import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geo_gio/misc/config.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});
  @override
  HistoryViewState createState() => HistoryViewState();
}

class HistoryViewState extends State<HistoryView> {
  List<Map<String, dynamic>> _locations = [];
  DateTime _startDate = DateTime.now().subtract(Duration(days: 7));
  DateTime _endDate = DateTime.now();
  late LocationDataSource _locationDataSource;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('access_token');

    try {
      final response = await http.get(
        Uri.parse(
            '$apiUrl/locations?start_date=${_startDate.toIso8601String()}&end_date=${_endDate.toIso8601String()}'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isNotEmpty) {
          List<dynamic> locations = json.decode(response.body);
          setState(() {
            _locations = locations
                .map((location) => {
                      'latitude': location['latitude'],
                      'longitude': location['longitude'],
                      'datetime': location['datetime'],
                    })
                .toList();
            _locationDataSource = LocationDataSource(_locations);
          });
        } else {
          logger.e('La respuesta del servidor está vacía.');
        }
      } else {
        logger.e(response.statusCode);
        logger.e(response.body);
      }
    } catch (e) {
      logger.e('Error al obtener las ubicaciones: $e');
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime? pickedStartDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedStartDate != null && pickedStartDate != _startDate) {
      setState(() {
        _startDate = pickedStartDate;
      });

      if (!mounted) return;
      final DateTime? pickedEndDate = await showDatePicker(
        context: context,
        initialDate: _endDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );

      if (pickedEndDate != null && pickedEndDate != _endDate) {
        setState(() {
          _endDate = pickedEndDate;
          _fetchLocations();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _locations.isEmpty
          ? Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Altura de la fila (ajusta según sea necesario)
                const double rowHeight = 56.0;
                // Altura de la cabecera de la tabla
                const double headerHeight = 56.0;
                // Calcula el número de filas que caben en el espacio disponible
                final int rowsPerPage =
                    ((constraints.maxHeight - headerHeight) / rowHeight)
                        .floor();

                return SingleChildScrollView(
                  child: PaginatedDataTable(
                    header: Text('Historial'),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: _fetchLocations,
                      ),
                      IconButton(
                        icon: Icon(Icons.filter_list),
                        onPressed: () {
                          // Add filter functionality here
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.map),
                        onPressed: _selectDateRange,
                      ),
                    ],
                    columns: [
                      DataColumn(label: Text('Latitud')),
                      DataColumn(label: Text('Longitud')),
                      DataColumn(label: Text('Fecha y Hora')),
                    ],
                    source: _locationDataSource,
                    rowsPerPage: rowsPerPage-1,
                    columnSpacing: 20,
                    horizontalMargin: 10,
                    showCheckboxColumn: false,
                  ),
                );
              },
            ),
    );
  }
}

class LocationDataSource extends DataTableSource {
  final List<Map<String, dynamic>> _locations;

  LocationDataSource(this._locations);

  @override
  DataRow getRow(int index) {
    final location = _locations[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(location['latitude'].toString())),
        DataCell(Text(location['longitude'].toString())),
        DataCell(
            Text(DateTime.parse(location['datetime']).toLocal().toString())),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _locations.length;

  @override
  int get selectedRowCount => 0;
}
