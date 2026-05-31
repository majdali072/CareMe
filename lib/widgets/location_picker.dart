import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class SelectedLocation {
  final String address;
  final double latitude;
  final double longitude;
  /// ISO 3166-1 alpha-2 country code (e.g. "LB"), derived from the geocoder.
  final String? country;

  const SelectedLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.country,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        if (country != null && country!.isNotEmpty) 'country': country,
      };

  factory SelectedLocation.fromParts({
    required String address,
    double? latitude,
    double? longitude,
    String? country,
  }) {
    return SelectedLocation(
      address: address,
      latitude: latitude ?? 0.0,
      longitude: longitude ?? 0.0,
      country: country,
    );
  }

  bool get hasCoords => latitude != 0.0 || longitude != 0.0;
}

class LocationAddressField extends StatelessWidget {
  final String label;
  final SelectedLocation? value;
  final ValueChanged<SelectedLocation> onChanged;
  /// When true and no initial value is set, the picker tries to seed itself
  /// with the phone's current GPS location. Pass `true` from non-admin screens.
  final bool autoDetect;

  const LocationAddressField({
    super.key,
    this.label = 'Address',
    required this.value,
    required this.onChanged,
    this.autoDetect = false,
  });

  Future<void> _open(BuildContext context) async {
    final result = await Navigator.of(context).push<SelectedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: value,
          autoDetect: autoDetect && value == null,
        ),
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
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
              color: AppColors.surfaceAlt(context),
              border: Border.all(color: AppColors.border(context)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasValue
                        ? value!.address
                        : AppLocalizations.of(context).t('loc_tap_pick'),
                    style: TextStyle(
                      fontSize: 14,
                      color: hasValue
                          ? AppColors.textPrimary(context)
                          : AppColors.textMuted(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: AppColors.textMuted(context), size: 20),
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
  final bool autoDetect;

  const LocationPickerScreen({
    super.key,
    this.initial,
    this.autoDetect = false,
  });

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
  String? _country;

  String get _address => _addressCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _country = init?.country;
    if (init != null && init.hasCoords) {
      _pin = LatLng(init.latitude, init.longitude);
      _addressCtrl.text = init.address;
    } else if (init != null && init.address.isNotEmpty) {
      _addressCtrl.text = init.address;
      Future.microtask(() => _geocode(init.address));
    } else if (widget.autoDetect) {
      Future.microtask(_useCurrentLocation);
    }
  }

  /// Fetch the phone's current GPS location, drop the pin there, and reverse
  /// geocode for a street address. Called automatically when `autoDetect` is
  /// true and there's no initial address; can also be triggered manually from
  /// the "Use current location" button.
  Future<void> _useCurrentLocation() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context).t('loc_services_off');
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error =
              AppLocalizations.of(context).t('loc_permission_denied_manual');
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = latLng);
      await _moveCameraTo(latLng);
      final result = await _reverseGeocode(latLng);
      if (!mounted) return;
      setState(() {
        if (result.address != null) _addressCtrl.text = result.address!;
        if (result.country != null) _country = result.country;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context)
            .t('loc_detect_failed', {'error': e.toString()});
      });
    }
  }

  Future<void> _moveCameraTo(LatLng target) async {
    try {
      final ctrl = await _mapController.future
          .timeout(const Duration(seconds: 2));
      await ctrl.animateCamera(
        CameraUpdate.newLatLngZoom(target, 15),
      );
    } catch (_) {
      // Map not ready yet; initial camera will pick up _pin anyway.
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
            AppLocalizations.of(context).t('loc_pin_resolve_failed');
      }
      if (result.country != null) _country = result.country;
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
      final results = await locationFromAddress(query);
      if (results.isEmpty) {
        setState(() {
          _busy = false;
          _error = AppLocalizations.of(context)
              .t('loc_no_results_query', {'query': query});
        });
        return;
      }
      final latLng = LatLng(results.first.latitude, results.first.longitude);
      final reverse = await _reverseGeocode(latLng);
      setState(() {
        _pin = latLng;
        _addressCtrl.text = reverse.address ?? query;
        if (reverse.country != null) _country = reverse.country;
        _busy = false;
      });
      final ctrl = await _mapController.future;
      await ctrl.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
    } catch (e) {
      setState(() {
        _busy = false;
        _error = AppLocalizations.of(context)
            .t('loc_search_failed', {'error': e.toString()});
      });
    }
  }

  Future<_GeocodeResult> _reverseGeocode(LatLng latLng) async {
    try {
      final places = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (places.isEmpty) {
        return _GeocodeResult(
            error: AppLocalizations.of(context).t('loc_pin_no_address'));
      }
      final p = places.first;
      final iso = (p.isoCountryCode ?? '').trim();
      return _GeocodeResult(
        address: _formatPlacemark(p),
        country: iso.isNotEmpty ? iso.toUpperCase() : null,
      );
    } catch (e) {
      return _GeocodeResult(
          error: AppLocalizations.of(context)
              .t('loc_geocoding_failed', {'error': e.toString()}));
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
      setState(() =>
          _error = AppLocalizations.of(context).t('loc_drop_pin_first'));
      return;
    }
    if (_address.isEmpty) {
      setState(() => _error =
          AppLocalizations.of(context).t('loc_accept_before_confirm'));
      return;
    }
    Navigator.of(context).pop(SelectedLocation(
      address: _address,
      latitude: _pin!.latitude,
      longitude: _pin!.longitude,
      country: _country,
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
        title: Text(AppLocalizations.of(context).t('loc_pick_title')),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          if (_pin != null)
            TextButton(
              onPressed: _busy ? null : _confirm,
              child: Text(
                AppLocalizations.of(context).t('loc_confirm_caps'),
                style: const TextStyle(
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
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _geocode,
                    decoration: InputDecoration(
                      hintText:
                          AppLocalizations.of(context).t('loc_search_placeholder'),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF6B7280)),
                      suffixIcon: _busy
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _busy ? null : _useCurrentLocation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.my_location,
                                size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Text(AppLocalizations.of(context).t('loc_use_current'),
                                style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
                        Text(
                          AppLocalizations.of(context).t('loc_address_label'),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _addressCtrl,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                AppLocalizations.of(context).t('loc_search_hint'),
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
                            child: Text(AppLocalizations.of(context)
                                .t('loc_use_this_location')),
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
  final String? country;
  final String? error;
  const _GeocodeResult({this.address, this.country, this.error});
}
