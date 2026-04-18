import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/api_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/operations_language.dart';
import 'operations_style.dart';

class TripMapCard extends StatelessWidget {
  const TripMapCard({
    super.key,
    required this.trip,
    required this.lang,
    required this.isDark,
    this.onOpenFullMap,
  });

  final TripData trip;
  final AppLanguage lang;
  final bool isDark;
  final VoidCallback? onOpenFullMap;

  bool _isValidPoint(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  List<_TripPoint> _tripPoints() {
    final points = <_TripPoint>[];
    if (_isValidPoint(trip.startLat, trip.startLng)) {
      points.add(
        _TripPoint(
          point: LatLng(trip.startLat!, trip.startLng!),
          isStart: true,
        ),
      );
    }
    if (_isValidPoint(trip.endLat, trip.endLng)) {
      points.add(
        _TripPoint(point: LatLng(trip.endLat!, trip.endLng!), isStart: false),
      );
    }
    return points;
  }

  LatLng _initialCenter(List<_TripPoint> points) {
    if (points.length == 1) return points.first.point;
    final lat =
        points.map((p) => p.point.latitude).reduce((a, b) => a + b) /
        points.length;
    final lng =
        points.map((p) => p.point.longitude).reduce((a, b) => a + b) /
        points.length;
    return LatLng(lat, lng);
  }

  double _initialZoom(List<_TripPoint> points) {
    if (points.length <= 1) return 15;
    final dLat = (points[0].point.latitude - points[1].point.latitude).abs();
    final dLng = (points[0].point.longitude - points[1].point.longitude).abs();
    final delta = dLat > dLng ? dLat : dLng;

    if (delta < 0.02) return 13.8;
    if (delta < 0.08) return 12.8;
    if (delta < 0.2) return 11.8;
    return 10.6;
  }

  @override
  Widget build(BuildContext context) {
    final muted = OperationsStyle.fgMuted(isDark);
    final points = _tripPoints();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                OperationsLanguage.get('trip_map_heading', lang),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onOpenFullMap,
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
              label: Text(
                OperationsLanguage.get('trip_map_open_fullscreen', lang),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: OperationsStyle.card(isDark),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 250,
              child: points.isEmpty
                  ? Container(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        OperationsLanguage.get('trip_map_no_location', lang),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: muted,
                          height: 1.35,
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: _initialCenter(points),
                            initialZoom: _initialZoom(points),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.cuchum.app',
                            ),
                            if (points.length > 1)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: points.map((e) => e.point).toList(),
                                    strokeWidth: 4,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: points
                                  .map(
                                    (p) => Marker(
                                      point: p.point,
                                      width: 36,
                                      height: 36,
                                      child: _TripMapMarker(isStart: p.isStart),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
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
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendChip(String label, Color color, bool isDark) {
    final bg = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.88);
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
}

class _TripMapMarker extends StatelessWidget {
  const _TripMapMarker({required this.isStart});

  final bool isStart;

  @override
  Widget build(BuildContext context) {
    final color = isStart ? AppColors.success : AppColors.error;
    final icon = isStart ? Icons.play_arrow_rounded : Icons.flag_rounded;
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

class _TripPoint {
  const _TripPoint({required this.point, required this.isStart});

  final LatLng point;
  final bool isStart;
}
