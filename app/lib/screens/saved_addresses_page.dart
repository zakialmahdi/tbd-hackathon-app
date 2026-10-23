import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_config.dart';
import '../services/saved_address_service.dart';
import '../shared_widgets.dart';

class SavedAddressesPage extends StatelessWidget {
  final String userId;
  final SavedAddressService _service;

  SavedAddressesPage({
    required this.userId,
    SavedAddressService? service,
    super.key,
  }) : _service = service ?? SavedAddressService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      body: StreamBuilder<List<SavedAddress>>(
        stream: _service.watchAddresses(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load saved addresses: ${snapshot.error}',
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final addresses = snapshot.data ?? const <SavedAddress>[];
          if (addresses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No saved addresses yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add an address and pin its exact location on the map.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final savedAddress = addresses[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.location_on_outlined),
                  ),
                  title: Text(savedAddress.address),
                  subtitle: Text(
                    '${savedAddress.location.latitude.toStringAsFixed(5)}, '
                    '${savedAddress.location.longitude.toStringAsFixed(5)}',
                  ),
                  onTap: () => _editAddress(context, savedAddress),
                  trailing: IconButton(
                    tooltip: 'Delete address',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, savedAddress),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAddress(context),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
    );
  }

  Future<void> _addAddress(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _AddressFormPage(userId: userId, service: _service),
      ),
    );
  }

  Future<void> _editAddress(BuildContext context, SavedAddress address) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _AddressFormPage(
          userId: userId,
          service: _service,
          initialAddress: address,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SavedAddress address,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved address?'),
        content: Text('Remove "${address.address}" from your saved addresses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteAddress(userId, address.id);
      if (context.mounted) snack(context, 'Address deleted.');
    } on FirebaseException catch (error) {
      debugPrint('Unable to delete saved address: $error');
      if (context.mounted) {
        snack(context, 'Could not delete this address: ${error.message}');
      }
    }
  }
}

class _AddressFormPage extends StatefulWidget {
  final String userId;
  final SavedAddressService service;
  final SavedAddress? initialAddress;

  const _AddressFormPage({
    required this.userId,
    required this.service,
    this.initialAddress,
  });

  @override
  State<_AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<_AddressFormPage> {
  static const _defaultCenter = LatLng(3.185, 101.515);

  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _mapController = MapController();
  LatLng? _selectedLocation;
  bool _isSearching = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialAddress = widget.initialAddress;
    if (initialAddress != null) {
      _addressController.text = initialAddress.address;
      _selectedLocation = LatLng(
        initialAddress.location.latitude,
        initialAddress.location.longitude,
      );
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _zoomMap(double amount) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + amount).clamp(3.0, 20.0));
  }

  Future<void> _searchAddress() async {
    final address = _addressController.text.trim();
    if (address.length < 3 || _isSearching) return;

    setState(() => _isSearching = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('geocodeSavedAddress');
      final response = await callable.call<Map<String, dynamic>>({
        'address': address,
      });
      final rawResults = response.data['results'];
      if (rawResults is! List) {
        throw const FormatException('Invalid geocoding response.');
      }
      final locations = rawResults
          .whereType<Map<Object?, Object?>>()
          .where((item) => item['latitude'] is num && item['longitude'] is num)
          .map(
            (item) => LatLng(
              (item['latitude'] as num).toDouble(),
              (item['longitude'] as num).toDouble(),
            ),
          )
          .toList();
      if (locations.isEmpty) {
        if (mounted) {
          snack(
            context,
            'No matching Malaysian address was found. Try adding a city or postcode.',
          );
        }
        return;
      }

      if (!mounted) return;
      final location = locations.first;
      setState(() => _selectedLocation = location);
      _mapController.move(location, 19);
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'Backend address search failed: ${error.code}: ${error.message}',
      );
      if (mounted) {
        snack(
          context,
          error.message ?? 'Address search failed. Please try again.',
        );
      }
    } on FormatException catch (error) {
      debugPrint('Invalid backend geocoding response: $error');
      if (mounted) snack(context, 'Could not read address search results.');
    } on FirebaseException catch (error) {
      debugPrint('Could not call address search function: $error');
      if (mounted) snack(context, 'Address search failed: ${error.message}');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    final location = _selectedLocation;
    if (location == null) {
      snack(context, 'Tap the map to place a pin for this address.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final existing = widget.initialAddress;
      if (existing == null) {
        await widget.service.addAddress(
          widget.userId,
          address: _addressController.text,
          location: GeoPoint(location.latitude, location.longitude),
        );
      } else {
        await widget.service.updateAddress(
          widget.userId,
          addressId: existing.id,
          address: _addressController.text,
          location: GeoPoint(location.latitude, location.longitude),
        );
      }
      if (mounted) Navigator.pop(context);
    } on FirebaseException catch (error) {
      debugPrint('Unable to save address: $error');
      if (mounted) {
        snack(context, 'Could not save this address: ${error.message}');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedLocation ?? _defaultCenter;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialAddress == null ? 'Add address' : 'Edit address',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Form(
              key: _formKey,
              child: TextFormField(
                controller: _addressController,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (_selectedLocation != null) {
                    setState(() => _selectedLocation = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Complete address',
                  hintText: 'Street, building, area, city, postcode',
                  alignLabelWithHint: true,
                  suffixIcon: IconButton(
                    tooltip: 'Search address online',
                    onPressed: _isSearching ? null : _searchAddress,
                    icon: _isSearching
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the complete address.';
                  }
                  if (value.trim().length > 500) {
                    return 'Address must be 500 characters or fewer.';
                  }
                  return null;
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Search places an approximate pin. Tap the map to adjust it before saving.',
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _selectedLocation == null ? 12 : 16,
                onTap: (_, point) => setState(() => _selectedLocation = point),
              ),
              children: [
                if (kStadiaMapsApiKey.isNotEmpty)
                  TileLayer(
                    urlTemplate:
                        'https://tiles.stadiamaps.com/tiles/osm_bright/{z}/{x}/{y}{r}.png?api_key=${Uri.encodeQueryComponent(kStadiaMapsApiKey)}',
                    userAgentPackageName: 'com.example.app',
                    maxZoom: 20,
                    tileDisplay: const TileDisplay.instantaneous(),
                  ),
                if (_selectedLocation case final location?)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: location,
                        alignment: Alignment.topCenter,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.deepOrange,
                          size: 46,
                        ),
                      ),
                    ],
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'saved-address-zoom-in',
                        tooltip: 'Zoom in',
                        onPressed: () => _zoomMap(1),
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'saved-address-zoom-out',
                        tooltip: 'Zoom out',
                        onPressed: () => _zoomMap(-1),
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
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
          ),
          if (_selectedLocation case final location?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Pinned at ${location.latitude.toStringAsFixed(6)}, '
                '${location.longitude.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveAddress,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    widget.initialAddress == null
                        ? 'Save address'
                        : 'Update address',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
