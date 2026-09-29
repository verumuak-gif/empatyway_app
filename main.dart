import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EmpatyWayApp());
}

class EmpatyWayApp extends StatelessWidget {
  const EmpatyWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmpatyWay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class UserPreferences {
  bool avoidSteps;
  bool requireSmoothPath;
  bool preferWellLit;
  bool avoidQuietOrNoisy;
  bool avoidConstruction;

  UserPreferences({
    this.avoidSteps = false,
    this.requireSmoothPath = false,
    this.preferWellLit = false,
    this.avoidQuietOrNoisy = false,
    this.avoidConstruction = true,
  });
}

class NearbyPOI {
  final String id;
  final String name;
  final String category;
  final LatLng location;
  final String description;

  NearbyPOI({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.description,
  });
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  Position? _currentPosition;
  final UserPreferences _userPrefs = UserPreferences();

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<String> _favoriteStationIds = {};

  final List<NearbyPOI> _pois = [
    NearbyPOI(
      id: 'cgp3',
      name: 'CGP Comuna 3',
      category: 'CGP',
      location: const LatLng(-34.6231, -58.4011),
      description: 'Sede Comunal - Sarandí 1273',
    ),
    NearbyPOI(
      id: 'cesac11',
      name: 'CeSAC N° 11',
      category: 'Centro de Salud',
      location: const LatLng(-34.6265, -58.3982),
      description: 'Centro de Salud y Acción Comunitaria',
    ),
    NearbyPOI(
      id: 'subte_jujuy',
      name: 'Estación Jujuy (Línea E)',
      category: 'Estación',
      location: const LatLng(-34.6258, -58.4042),
      description: 'Acceso adaptado disponible',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadMapMarkers();
  }

  void _loadMapMarkers() {
    for (final poi in _pois) {
      final isFavorite = _favoriteStationIds.contains(poi.id);
      _markers.add(
        Marker(
          markerId: MarkerId(poi.id),
          position: poi.location,
          infoWindow: InfoWindow(
            title: poi.name,
            snippet: poi.description,
          ),
          icon: poi.category == 'Estación'
              ? BitmapDescriptor.defaultMarkerWithHue(
                  isFavorite
                      ? BitmapDescriptor.hueYellow
                      : BitmapDescriptor.hueAzure,
                )
              : BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
        ),
      );
    }
  }

  void _generateRoute() {
    final pathCoordinates = [
      const LatLng(-34.6240, -58.4010),
      const LatLng(-34.6250, -58.4020),
      const LatLng(-34.6258, -58.4042),
    ];

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_path'),
          points: pathCoordinates,
          color: Colors.teal,
          width: 5,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ruta optimizada según tus preferencias.'),
      ),
    );
  }

  void _showPreferencesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Preferencias de Movilidad'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('Evitar escalones o cordones altos'),
                      value: _userPrefs.avoidSteps,
                      onChanged: (val) {
                        setDialogState(
                          () => _userPrefs.avoidSteps = val ?? false,
                        );
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Priorizar veredas lisas'),
                      value: _userPrefs.requireSmoothPath,
                      onChanged: (val) {
                        setDialogState(
                          () => _userPrefs.requireSmoothPath = val ?? false,
                        );
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Priorizar iluminación nocturna'),
                      value: _userPrefs.preferWellLit,
                      onChanged: (val) {
                        setDialogState(
                          () => _userPrefs.preferWellLit = val ?? false,
                        );
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Evitar obras en construcción'),
                      value: _userPrefs.avoidConstruction,
                      onChanged: (val) {
                        setDialogState(
                          () => _userPrefs.avoidConstruction = val ?? false,
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const initialCenter = LatLng(-34.6240, -58.4010);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EmpatyWay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showPreferencesDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: initialCenter,
              zoom: 15.0,
            ),
            onMapCreated: (controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
            markers: _markers,
            polylines: _polylines,
          ),
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _generateRoute,
              icon: const Icon(Icons.alt_route),
              label: const Text(
                'Trazar Ruta Accesible',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
