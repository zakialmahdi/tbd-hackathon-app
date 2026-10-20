import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:firebase_core/firebase_core.dart';

import '../app_config.dart';
import '../models.dart';
import '../services/bin_repository.dart';
import '../shared_widgets.dart';
import 'report_page.dart';

class _WalkingRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final Duration duration;

  const _WalkingRoute({
    required this.points,
    required this.distanceMeters,
    required this.duration,
  });
}

class BinMapPage extends StatefulWidget {
  const BinMapPage({super.key});
  @override
  State<BinMapPage> createState() => _BinMapPageState();
}

class _BinMapPageState extends State<BinMapPage> {
  final MapController _mapController = MapController();
  final Location _location = Location();
  final BinRepository _binRepository = BinRepository();
  final TextEditingController _searchController = TextEditingController();
  static const _mapCenter = LatLng(3.185, 101.515);

  String filter = 'All';
  String _searchQuery = '';
  LatLng? _userLocation;
  LatLng? _searchedLocation;
  _WalkingRoute? _activeRoute;
  Bin? _routeDestination;
  bool _isLocating = false;
  bool _isSearchingAddress = false;
  bool _isNavigating = false;
  int _streamRetryKey = 0;

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Bin> _matchingBins(List<Bin> candidates) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return candidates;
    return candidates.where((bin) {
      return [
        bin.name,
        bin.id,
        bin.type,
        statusLabel(bin.status),
        bin.emptiedLabel,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  void _selectBin(Bin bin) {
    final point = _pointFor(bin);
    setState(() {
      _searchQuery = bin.name;
      _searchController.text = bin.name;
      _searchedLocation = null;
    });
    _mapController.move(point, 16);
    _showBin(bin);
  }

  Future<void> _search(String query, List<Bin> allBins) async {
    final text = query.trim();
    if (text.isEmpty || _isSearchingAddress) return;

    final matches = _matchingBins(allBins);
    if (matches.isNotEmpty) {
      _selectBin(matches.first);
      return;
    }

    if (kStadiaMapsApiKey.isEmpty) {
      snack(context, 'Add your Stadia Maps API key to search for addresses.');
      return;
    }

    setState(() => _isSearchingAddress = true);
    try {
      final uri = Uri.https('api.stadiamaps.com', '/geocoding/v1/search', {
        'text': text,
        'api_key': kStadiaMapsApiKey,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('Stadia address search failed: HTTP ${response.statusCode}');
        if (mounted) {
          snack(context, 'Address search failed (${response.statusCode}).');
        }
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['features'] is! List ||
          (decoded['features'] as List).isEmpty) {
        if (mounted) snack(context, 'No address found. Try another search.');
        return;
      }

      final feature = (decoded['features'] as List).first;
      if (feature is! Map<String, dynamic> ||
          feature['geometry'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid geocoding result.');
      }
      final coordinates =
          (feature['geometry'] as Map<String, dynamic>)['coordinates'];
      if (coordinates is! List ||
          coordinates.length < 2 ||
          coordinates[0] is! num ||
          coordinates[1] is! num) {
        throw const FormatException('Invalid address coordinates.');
      }

      final point = LatLng(
        (coordinates[1] as num).toDouble(),
        (coordinates[0] as num).toDouble(),
      );
      if (!mounted) return;
      setState(() => _searchedLocation = point);
      _mapController.move(point, 15);
    } on http.ClientException catch (error) {
      debugPrint('Stadia address search request failed: $error');
      if (mounted) snack(context, 'Could not connect to address search.');
    } on TimeoutException catch (error) {
      debugPrint('Stadia address search timed out: $error');
      if (mounted) snack(context, 'Address search timed out. Try again.');
    } on FormatException catch (error) {
      debugPrint('Invalid Stadia address search response: $error');
      if (mounted) snack(context, 'Could not read the address search result.');
    } finally {
      if (mounted) setState(() => _isSearchingAddress = false);
    }
  }

  Future<LatLng?> _getCurrentLocation() async {
    var serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        if (mounted) snack(context, 'Turn on location services to continue.');
        return null;
      }
    }

    var permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      if (mounted) {
        snack(
          context,
          permission == PermissionStatus.deniedForever
              ? 'Allow location access for this app in your device settings.'
              : 'Location permission is needed to find your position.',
        );
      }
      return null;
    }

    final location = await _location.getLocation();
    final latitude = location.latitude;
    final longitude = location.longitude;
    if (latitude == null || longitude == null) {
      if (mounted) snack(context, 'Your current location is unavailable.');
      return null;
    }

    final point = LatLng(latitude, longitude);
    if (mounted) setState(() => _userLocation = point);
    return point;
  }

  Future<void> _centerOnCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      final point = await _getCurrentLocation();
      if (point != null && mounted) _mapController.move(point, 15);
    } on Exception catch (error) {
      debugPrint('Unable to get current location: $error');
      if (mounted) snack(context, 'Could not get your current location.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _navigateToBin(Bin bin) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    try {
      final origin = await _getCurrentLocation();
      if (origin == null) return;
      final route = await _fetchWalkingRoute(bin, origin);
      if (!mounted) return;
      setState(() {
        _activeRoute = route;
        _routeDestination = bin;
      });
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: route.points,
          padding: const EdgeInsets.fromLTRB(48, 180, 48, 180),
          maxZoom: 16,
        ),
      );
      Navigator.of(context).pop();
    } on Exception catch (error) {
      debugPrint('Unable to load Stadia walking route: $error');
      if (mounted) snack(context, 'Could not load the walking route.');
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  LatLng _pointFor(Bin bin) => LatLng(bin.latitude, bin.longitude);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Bin>>(
    key: ValueKey(_streamRetryKey),
    stream: _binRepository.watchBins(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        final permissionDenied =
            snapshot.error is FirebaseException &&
            (snapshot.error! as FirebaseException).code == 'permission-denied';
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    permissionDenied ? Icons.lock_outline : Icons.cloud_off,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    permissionDenied
                        ? 'Your account is not allowed to read the bins. Check Firestore rules.'
                        : 'Could not load bins: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _streamRetryKey++),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return _buildMap(context, snapshot.data!);
    },
  );

  Widget _buildMap(BuildContext context, List<Bin> allBins) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mapStyle = dark ? 'alidade_smooth_dark' : 'alidade_smooth';
    final shown = allBins
        .where((b) => filter == 'All' || b.type == filter)
        .toList();
    final matching = _matchingBins(shown);
    final visibleBins = _searchQuery.trim().isEmpty ? shown : matching;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 13.5,
              backgroundColor: dark
                  ? const Color(0xFF1E2A22)
                  : const Color(0xFFEAF1E4),
            ),
            children: [
              if (kStadiaMapsApiKey.isNotEmpty)
                TileLayer(
                  urlTemplate:
                      'https://tiles.stadiamaps.com/tiles/$mapStyle/{z}/{x}/{y}{r}.png?api_key=${Uri.encodeQueryComponent(kStadiaMapsApiKey)}',
                  userAgentPackageName: 'com.example.app',
                  maxZoom: 20,
                  tileDisplay: const TileDisplay.instantaneous(),
                ),
              if (_activeRoute case final route?)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route.points,
                      strokeWidth: 6,
                      color: Colors.blue,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  ...visibleBins.map(
                    (b) => Marker(
                      point: _pointFor(b),
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () => _showBin(b),
                        child: _pin(b),
                      ),
                    ),
                  ),
                  if (_userLocation case final userLocation?)
                    Marker(
                      point: userLocation,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(blurRadius: 8, color: Colors.black26),
                          ],
                        ),
                      ),
                    ),
                  if (_searchedLocation case final searchedLocation?)
                    Marker(
                      point: searchedLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.place,
                        color: Colors.deepOrange,
                        size: 40,
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© Stadia Maps © OpenMapTiles © OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
          ),
          if (kStadiaMapsApiKey.isEmpty)
            Positioned(
              top: 136,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Add your Stadia Maps API key in lib/app_config.dart '
                    'to load map tiles.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          if (_activeRoute case final route?)
            Positioned(
              left: 16,
              right: 16,
              bottom: 148,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_walk, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_routeDestination?.name ?? 'Walking route'} · '
                          '${_travelEstimate(route)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'End navigation',
                        onPressed: () => setState(() {
                          _activeRoute = null;
                          _routeDestination = null;
                        }),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search bins or address',
                    onChanged: (value) => setState(() => _searchQuery = value),
                    onSubmitted: (query) => _search(query, shown),
                    leading: _isSearchingAddress
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    trailing: [
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _searchedLocation = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                      IconButton(
                        onPressed: () => _showList(shown),
                        icon: const Icon(Icons.view_list_outlined),
                      ),
                    ],
                  ),
                ),
                if (_searchQuery.trim().isNotEmpty && matching.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: matching.length > 5 ? 5 : matching.length,
                          itemBuilder: (context, index) {
                            final bin = matching[index];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                bin.type == 'Recycle'
                                    ? Icons.recycling
                                    : Icons.delete,
                                color: statusColor(bin.status),
                              ),
                              title: Text(bin.name),
                              subtitle: Text('${bin.id} · ${bin.type}'),
                              onTap: () => _selectBin(bin),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final f in ['All', 'Domestic', 'Recycle'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: filter == f,
                            onSelected: (_) => setState(() => filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in BinStatus.values)
                      Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: statusColor(s)),
                          const SizedBox(width: 6),
                          Text(
                            statusLabel(s),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 72,
            child: FloatingActionButton(
              heroTag: 'bin-map-location-fab',
              tooltip: 'Center on my location',
              onPressed: _isLocating ? null : _centerOnCurrentLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pin(Bin b) => Column(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: statusColor(b.status),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
        ),
        child: Icon(
          b.type == 'Recycle' ? Icons.recycling : Icons.delete,
          color: Colors.white,
          size: 22,
        ),
      ),
      Icon(Icons.arrow_drop_down, color: statusColor(b.status), size: 0),
    ],
  );

  void _showBin(Bin b) {
    final routeFuture = _loadRouteEstimateForBin(b);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => FutureBuilder<_WalkingRoute?>(
        future: routeFuture,
        builder: (context, snapshot) {
          final distanceLabel = switch (snapshot.connectionState) {
            ConnectionState.waiting => 'Getting walking route…',
            _ when snapshot.hasError => 'Walking route estimate unavailable.',
            _ when snapshot.data == null =>
              'Location unavailable for route estimate.',
            _ => _travelEstimate(snapshot.data!),
          };

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        statusLabel(b.status),
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: statusColor(b.status),
                      side: BorderSide.none,
                    ),
                  ],
                ),
                Text(
                  '${b.type} bin · ID ${b.id}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Fill level'),
                    const Spacer(),
                    Text(
                      '${b.fill}%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: b.fill / 100,
                    minHeight: 10,
                    color: statusColor(b.status),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.history, size: 18),
                    const SizedBox(width: 8),
                    Text('Last emptied: ${b.emptiedLabel}'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.directions_walk, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(distanceLabel)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReportPage(
                                initial: b.status == BinStatus.full
                                    ? 'Bin full'
                                    : 'Other',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Report issue'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isNavigating
                            ? null
                            : () => _navigateToBin(b),
                        icon: _isNavigating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.navigation),
                        label: Text(_isNavigating ? 'Opening…' : 'Navigate'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_WalkingRoute?> _loadRouteEstimateForBin(Bin bin) async {
    try {
      final userLocation = await _getCurrentLocation();
      if (userLocation == null) return null;
      return await _fetchWalkingRoute(bin, userLocation);
    } on Exception catch (error) {
      debugPrint('Unable to get walking route estimate: $error');
      rethrow;
    }
  }

  Future<_WalkingRoute> _fetchWalkingRoute(Bin bin, LatLng userLocation) async {
    final binLocation = _pointFor(bin);
    final uri = Uri.https('api.stadiamaps.com', '/route/v1', {
      'api_key': kStadiaMapsApiKey,
      'json': jsonEncode({
        'locations': [
          {'lat': userLocation.latitude, 'lon': userLocation.longitude},
          {'lat': binLocation.latitude, 'lon': binLocation.longitude},
        ],
        'costing': 'pedestrian',
        'units': 'kilometers',
        'shape_format': 'polyline6',
      }),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Stadia walking route request failed: HTTP ${response.statusCode}',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['trip'] is! Map<String, dynamic> ||
        (decoded['trip'] as Map<String, dynamic>)['summary']
            is! Map<String, dynamic>) {
      throw const FormatException('Invalid Stadia walking route response.');
    }
    final summary =
        (decoded['trip'] as Map<String, dynamic>)['summary']
            as Map<String, dynamic>;
    final legs = (decoded['trip'] as Map<String, dynamic>)['legs'];
    final lengthKilometers = summary['length'];
    final timeSeconds = summary['time'];
    if (lengthKilometers is! num ||
        timeSeconds is! num ||
        legs is! List ||
        legs.isEmpty ||
        !lengthKilometers.isFinite ||
        !timeSeconds.isFinite ||
        lengthKilometers < 0 ||
        timeSeconds < 0) {
      throw const FormatException('Invalid Stadia walking route summary.');
    }

    final routePoints = <LatLng>[];
    for (final leg in legs) {
      if (leg is! Map<String, dynamic> || leg['shape'] is! String) {
        throw const FormatException('Invalid Stadia route geometry.');
      }
      final legPoints = _decodePolyline6(leg['shape'] as String);
      if (routePoints.isNotEmpty && legPoints.isNotEmpty) {
        legPoints.removeAt(0);
      }
      routePoints.addAll(legPoints);
    }
    if (routePoints.length < 2) {
      throw const FormatException('Stadia returned an empty walking route.');
    }

    return _WalkingRoute(
      points: routePoints,
      distanceMeters: lengthKilometers.toDouble() * 1000,
      duration: Duration(seconds: timeSeconds.round()),
    );
  }

  List<LatLng> _decodePolyline6(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    int decodeValue() {
      var result = 0;
      var shift = 0;
      var chunk = 0;
      do {
        if (index >= encoded.length) {
          throw const FormatException('Invalid encoded route geometry.');
        }
        chunk = encoded.codeUnitAt(index++) - 63;
        if (chunk < 0 || chunk > 63) {
          throw const FormatException('Invalid encoded route geometry.');
        }
        result |= (chunk & 0x1f) << shift;
        shift += 5;
      } while (chunk >= 0x20);

      return result.isOdd ? ~(result >> 1) : result >> 1;
    }

    while (index < encoded.length) {
      latitude += decodeValue();
      longitude += decodeValue();
      points.add(LatLng(latitude / 1e6, longitude / 1e6));
    }
    return points;
  }

  String _travelEstimate(_WalkingRoute route) {
    final distanceLabel = route.distanceMeters >= 1000
        ? '${(route.distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${route.distanceMeters.round()} m';
    final totalMinutes = route.duration.inMinutes;
    final timeLabel = totalMinutes >= 60
        ? '${totalMinutes ~/ 60} hr ${totalMinutes % 60} min'
        : '$totalMinutes min';
    return '$distanceLabel by road · about $timeLabel walk';
  }

  void _showList(List<Bin> l) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      builder: (_, sc) => ListView(
        controller: sc,
        children: l
            .map(
              (b) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor(b.status),
                  child: Icon(
                    b.type == 'Recycle' ? Icons.recycling : Icons.delete,
                    color: Colors.white,
                  ),
                ),
                title: Text(b.name),
                subtitle: Text('${statusLabel(b.status)} · ${b.fill}%'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _showBin(b);
                },
              ),
            )
            .toList(),
      ),
    ),
  );
}
