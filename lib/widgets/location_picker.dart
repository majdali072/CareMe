import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class SelectedLocation {
  final String address;
  final double latitude;
  final double longitude;

  const SelectedLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory SelectedLocation.fromParts({
    required String address,
    double? latitude,
    double? longitude,
  }) {
    return SelectedLocation(
      address: address,
      latitude: latitude ?? 0.0,
      longitude: longitude ?? 0.0,
    );
  }

  bool get hasCoords => latitude != 0.0 || longitude != 0.0;
}

class LocationAddressField extends StatelessWidget {
  final String label;
  final SelectedLocation? value;
  final ValueChanged<SelectedLocation> onChanged;

  const LocationAddressField({
    super.key,
    this.label = 'Address',
    required this.value,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final result = await Navigator.of(context).push<SelectedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: value),
        fullscreenDialog: true,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.address.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _open(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasValue ? value!.address : 'Tap to pick a location',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasValue
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFCBD5E1),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF94A3B8), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LocationPickerScreen extends StatefulWidget {
  final SelectedLocation? initial;

  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const LatLng _fallbackCenter = LatLng(33.8938, 35.5018); // Beirut

  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  LatLng? _pin;
  bool _busy = false;
  String? _error;

  String get _address => _addressCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null && init.hasCoords) {
      _pin = LatLng(init.latitude, init.longitude);
      _addressCtrl.text = init.address;
    } else if (init != null && init.address.isNotEmpty) {
      _addressCtrl.text = init.address;
      Future.microtask(() => _geocode(init.address));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  LatLng get _initialCamera => _pin ??
      (widget.initial?.hasCoords == true
          ? LatLng(widget.initial!.latitude, widget.initial!.longitude)
          : _fallbackCenter);

  Future<void> _onMapTap(LatLng latLng) async {
    setState(() {
      _pin = latLng;
      _busy = true;
      _error = null;
    });
    final result = await _reverseGeocode(latLng);
    if (!mounted) return;
    setState(() {
      if (result.address != null) {
        _addressCtrl.text = result.address!;
      } else if (_addressCtrl.text.trim().isEmpty) {
        _error = result.error ??
            'Could not resolve that pin to an address. Type it manually below.';
      }
      _busy = false;
    });
  }

  Future<void> _geocode(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      LatLng? latLng;
      String? resolvedAddress;
      if (kIsWeb) {
        final web = await _webForwardGeocode(query);
        if (web.error != null || web.latLng == null) {
          setState(() {
            _busy = false;
            _error = web.error ?? 'No results for "$query".';
          });
          return;
        }
        latLng = web.latLng;
        resolvedAddress = web.address;
      } else {
        final results = await locationFromAddress(query);
        if (results.isEmpty) {
          setState(() {
            _busy = false;
            _error = 'No results for "$query".';
          });
          return;
        }
        latLng = LatLng(results.first.latitude, results.first.longitude);
        final reverse = await _reverseGeocode(latLng);
        resolvedAddress = reverse.address;
      }
      setState(() {
        _pin = latLng;
        _addressCtrl.text = resolvedAddress ?? query;
        _busy = false;
      });
      final ctrl = await _mapController.future;
      await ctrl.animateCamera(CameraUpdate.newLatLngZoom(latLng!, 15));
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Search failed: $e';
      });
    }
  }

  Future<_GeocodeResult> _reverseGeocode(LatLng latLng) async {
    if (kIsWeb) return _webReverseGeocode(latLng);
    try {
      final places = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (places.isEmpty) {
        return const _GeocodeResult(error: 'No address found for that pin.');
      }
      return _GeocodeResult(address: _formatPlacemark(places.first));
    } catch (e) {
      return _GeocodeResult(error: 'Geocoding failed: $e');
    }
  }

  Future<_GeocodeResult> _webReverseGeocode(LatLng latLng) async {
    if (!AppConfig.hasMapsKey) {
      return const _GeocodeResult(
        error:
            'Web reverse-geocoding needs GOOGLE_MAPS_API_KEY via --dart-define.',
      );
    }
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${latLng.latitude},${latLng.longitude}'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final res = await http.get(uri);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        return _GeocodeResult(
          address: data['results'][0]['formatted_address'] as String?,
        );
      }
      final status = data['status'] ?? 'UNKNOWN';
      final msg = data['error_message'];
      return _GeocodeResult(
        error: msg == null ? 'Geocoding API: $status' : '$status — $msg',
      );
    } catch (e) {
      return _GeocodeResult(error: 'Network error: $e');
    }
  }

  Future<_WebForwardResult> _webForwardGeocode(String query) async {
    if (!AppConfig.hasMapsKey) {
      return const _WebForwardResult(
        error:
            'Web search needs GOOGLE_MAPS_API_KEY via --dart-define at launch.',
      );
    }
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeQueryComponent(query)}'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final res = await http.get(uri);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK' || (data['results'] as List).isEmpty) {
        final status = data['status'] ?? 'UNKNOWN';
        final msg = data['error_message'];
        return _WebForwardResult(
          error: msg == null ? 'Geocoding API: $status' : '$status — $msg',
        );
      }
      final top = data['results'][0];
      final loc = top['geometry']['location'];
      return _WebForwardResult(
        latLng: LatLng(
            (loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()),
        address: top['formatted_address'] as String?,
      );
    } catch (e) {
      return _WebForwardResult(error: 'Network error: $e');
    }
  }

  String _formatPlacemark(Placemark p) {
    String s(String? v) => (v ?? '').trim();
    final street = [s(p.street), s(p.subThoroughfare)]
        .where((e) => e.isNotEmpty)
        .join(' ');
    final parts = <String>[
      street,
      s(p.subLocality),
      s(p.locality),
      s(p.administrativeArea),
      s(p.postalCode),
      s(p.country),
    ];
    final seen = <String>{};
    return parts.where((e) => e.isNotEmpty && seen.add(e)).join(', ');
  }

  String _formatLatLng(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

  void _confirm() {
    if (_pin == null) {
      setState(() => _error = 'Drop a pin or search for an address first.');
      return;
    }
    if (_address.isEmpty) {
      setState(
          () => _error = 'Type or accept an address before confirming.');
      return;
    }
    Navigator.of(context).pop(SelectedLocation(
      address: _address,
      latitude: _pin!.latitude,
      longitude: _pin!.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      if (_pin != null)
        Marker(markerId: const MarkerId('selected'), position: _pin!),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick a location'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          if (_pin != null)
            TextButton(
              onPressed: _busy ? null : _confirm,
              child: const Text(
                'CONFIRM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialCamera,
              zoom: _pin != null ? 15 : 11,
            ),
            markers: markers,
            myLocationButtonEnabled: true,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (c) {
              if (!_mapController.isCompleted) _mapController.complete(c);
            },
            onTap: _onMapTap,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: _geocode,
                decoration: InputDecoration(
                  hintText: 'Search address, place, city…',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF6B7280)),
                  suffixIcon: _busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward,
                              color: Color(0xFF2563EB)),
                          onPressed: () => _geocode(_searchCtrl.text),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (_pin != null || _error != null)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_pin != null) ...[
                        const Text(
                          'Address',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _addressCtrl,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                'e.g., 123 Medical Plaza, Beirut, Lebanon',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatLatLng(_pin!),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _confirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Use this location'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GeocodeResult {
  final String? address;
  final String? error;
  const _GeocodeResult({this.address, this.error});
}

class _WebForwardResult {
  final LatLng? latLng;
  final String? address;
  final String? error;
  const _WebForwardResult({this.latLng, this.address, this.error});
}
