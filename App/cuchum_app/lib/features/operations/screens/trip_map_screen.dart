import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_models.dart';
import '../../../core/services/location_permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/operations_language.dart';

class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key, required this.trip});

  final TripData trip;

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _trackingSub;
  final List<LatLng> _liveTrack = [];
  LatLng? _currentLocation;
  bool _trackingEnabled = false;
  bool _trackingBusy = false;
  bool _didAutoCenter = false;

  @override
  void initState() {
    super.initState();
    if (widget.trip.isOngoing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _toggleTracking(forceEnable: true);
      });
    }
  }

  @override
  void dispose() {
    _trackingSub?.cancel();
    super.dispose();
  }

  bool _isValidPoint(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  List<_TripPoint> _fixedTripPoints() {
    final points = <_TripPoint>[];
    if (_isValidPoint(widget.trip.startLat, widget.trip.startLng)) {
      points.add(
        _TripPoint(
          point: LatLng(widget.trip.startLat!, widget.trip.startLng!),
          kind: _TripPointKind.start,
        ),
      );
    }
    if (_isValidPoint(widget.trip.endLat, widget.trip.endLng)) {
      points.add(
        _TripPoint(
          point: LatLng(widget.trip.endLat!, widget.trip.endLng!),
          kind: _TripPointKind.end,
        ),
      );
    }
    return points;
  }

  List<LatLng> _allPointsForCamera() {
    final points = _fixedTripPoints().map((e) => e.point).toList();
    points.addAll(_liveTrack);
    if (_currentLocation != null) points.add(_currentLocation!);
    return points;
  }

  LatLng _cameraCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(16.047079, 108.20623);
    if (points.length == 1) return points.first;

    final lat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  double _cameraZoom(List<LatLng> points) {
    if (points.isEmpty) return 5.6;
    if (points.length == 1) return 15;

    final minLat = points
        .map((e) => e.latitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLat = points
        .map((e) => e.latitude)
        .reduce((a, b) => a > b ? a : b);
    final minLng = points
        .map((e) => e.longitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLng = points
        .map((e) => e.longitude)
        .reduce((a, b) => a > b ? a : b);

    final delta = (maxLat - minLat) > (maxLng - minLng)
        ? (maxLat - minLat)
        : (maxLng - minLng);

    if (delta < 0.01) return 15.5;
    if (delta < 0.03) return 14;
    if (delta < 0.08) return 13;
    if (delta < 0.2) return 12;
    if (delta < 0.4) return 11;
    return 10;
  }

  void _moveCameraToData() {
    final points = _allPointsForCamera();
    _mapController.move(_cameraCenter(points), _cameraZoom(points));
  }

  Future<void> _toggleTracking({bool forceEnable = false}) async {
    if (_trackingBusy) return;

    if (_trackingEnabled && !forceEnable) {
      await _trackingSub?.cancel();
      if (!mounted) return;
      setState(() {
        _trackingSub = null;
        _trackingEnabled = false;
      });
      return;
    }

    setState(() => _trackingBusy = true);
    final granted = await LocationPermissionService.ensureLocationPermission();
    if (!mounted) return;

    if (!granted) {
      setState(() => _trackingBusy = false);
      final lang = Provider.of<LanguageProvider>(
        context,
        listen: false,
      ).language;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            OperationsLanguage.get('trip_map_tracking_requires_location', lang),
          ),
        ),
      );
      return;
    }

    await _trackingSub?.cancel();
    _trackingSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 8,
          ),
        ).listen((position) {
          if (!mounted) return;
          final next = LatLng(position.latitude, position.longitude);
          setState(() {
            _currentLocation = next;
            if (_liveTrack.isEmpty ||
                (_liveTrack.last.latitude != next.latitude ||
                    _liveTrack.last.longitude != next.longitude)) {
              _liveTrack.add(next);
              if (_liveTrack.length > 500) {
                _liveTrack.removeRange(0, _liveTrack.length - 500);
              }
            }
          });
          if (!_didAutoCenter) {
            _didAutoCenter = true;
            _mapController.move(next, 16);
          }
        });

    setState(() {
      _trackingEnabled = true;
      _trackingBusy = false;
    });
  }

  Widget _legendChip(String label, Color color, bool isDark) {
    final bg = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    final fixedPoints = _fixedTripPoints();
    final mapPoints = _allPointsForCamera();

    final markers = <Marker>[
      ...fixedPoints.map(
        (p) => Marker(
          point: p.point,
          width: 38,
          height: 38,
          child: _MapMarker(kind: p.kind),
        ),
      ),
    ];

    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 38,
          height: 38,
          child: const _MapMarker(kind: _TripPointKind.current),
        ),
      );
    }

    final staticRoute = fixedPoints.map((e) => e.point).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        title: Text(OperationsLanguage.get('trip_map_heading', lang)),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _cameraCenter(mapPoints),
              initialZoom: _cameraZoom(mapPoints),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cuchum.app',
              ),
              if (staticRoute.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: staticRoute,
                      strokeWidth: 4,
                      color: AppColors.primary.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              if (_liveTrack.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _liveTrack,
                      strokeWidth: 5,
                      color: AppColors.warning.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),
          if (mapPoints.isEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(
                    alpha: 0.85,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  OperationsLanguage.get('trip_map_no_location', lang),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'trip_map_center',
                  onPressed: mapPoints.isEmpty ? null : _moveCameraToData,
                  child: const Icon(Icons.center_focus_strong_rounded),
                ),
                if (widget.trip.isOngoing) ...[
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'trip_map_tracking',
                    onPressed: _trackingBusy ? null : _toggleTracking,
                    backgroundColor: _trackingEnabled
                        ? AppColors.success
                        : (isDark ? AppColors.darkSurface : Colors.white),
                    child: Icon(
                      _trackingEnabled
                          ? Icons.location_searching_rounded
                          : Icons.location_disabled_rounded,
                      color: _trackingEnabled
                          ? Colors.white
                          : (isDark ? Colors.white : AppColors.lightText),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _legendChip(
                  OperationsLanguage.get('trip_map_start', lang),
                  AppColors.success,
                  isDark,
                ),
                _legendChip(
                  OperationsLanguage.get('trip_map_end', lang),
                  AppColors.error,
                  isDark,
                ),
                if (widget.trip.isOngoing)
                  _legendChip(
                    OperationsLanguage.get('trip_map_live_tracking', lang),
                    AppColors.warning,
                    isDark,
                  ),
                if (_currentLocation != null)
                  _legendChip(
                    OperationsLanguage.get('trip_map_current_location', lang),
                    AppColors.info,
                    isDark,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TripPointKind { start, end, current }

class _TripPoint {
  const _TripPoint({required this.point, required this.kind});

  final LatLng point;
  final _TripPointKind kind;
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.kind});

  final _TripPointKind kind;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;

    switch (kind) {
      case _TripPointKind.start:
        color = AppColors.success;
        icon = Icons.play_arrow_rounded;
        break;
      case _TripPointKind.end:
        color = AppColors.error;
        icon = Icons.flag_rounded;
        break;
      case _TripPointKind.current:
        color = AppColors.info;
        icon = Icons.navigation_rounded;
        break;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }
}
