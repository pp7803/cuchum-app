import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─── Models ──────────────────────────────────────────────────────────────────

class ProvinceData {
  final String code;
  final String name;

  ProvinceData({required this.code, required this.name});

  factory ProvinceData.fromJson(Map<String, dynamic> json) {
    return ProvinceData(
      code: json['code']?.toString() ?? '',
      name: json['name'] ?? '',
    );
  }

  @override
  String toString() => name;
}

class CommuneData {
  final String code;
  final String name;
  final String provinceCode;

  CommuneData({required this.code, required this.name, required this.provinceCode});

  factory CommuneData.fromJson(Map<String, dynamic> json) {
    return CommuneData(
      code: json['code']?.toString() ?? '',
      name: json['name'] ?? '',
      provinceCode: json['provinceCode']?.toString() ?? '',
    );
  }

  @override
  String toString() => name;
}

/// Combined result from the 3-part address picker
class AddressResult {
  final String street;
  final CommuneData? commune;
  final ProvinceData? province;

  const AddressResult({
    this.street = '',
    this.commune,
    this.province,
  });

  bool get isComplete =>
      street.trim().isNotEmpty && commune != null && province != null;

  /// Combined display string: "41 Đường A, Phường B, Thành phố C"
  String get combined {
    final parts = <String>[];
    if (street.trim().isNotEmpty) parts.add(street.trim());
    if (commune != null) parts.add(commune!.name);
    if (province != null) parts.add(province!.name);
    return parts.join(', ');
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class AddressService {
  static const String _baseUrl = 'https://production.cas.so/address-kit';
  static const String _effectiveDate = '2025-07-01';

  // Simple in-memory cache
  static List<ProvinceData>? _provincesCache;
  static final Map<String, List<CommuneData>> _communesCache = {};

  /// Fetch all provinces (cached after first call)
  static Future<List<ProvinceData>> getProvinces() async {
    if (_provincesCache != null) return _provincesCache!;

    try {
      final url = '$_baseUrl/$_effectiveDate/provinces';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final list = json['provinces'] as List<dynamic>;
        _provincesCache = list
            .map((e) => ProvinceData.fromJson(e as Map<String, dynamic>))
            .toList();
        return _provincesCache!;
      }
    } catch (e) {
      debugPrint('AddressService.getProvinces error: $e');
    }
    return [];
  }

  /// Fetch communes for a given province code (cached)
  static Future<List<CommuneData>> getCommunes(String provinceCode) async {
    if (_communesCache.containsKey(provinceCode)) {
      return _communesCache[provinceCode]!;
    }

    try {
      final url = '$_baseUrl/$_effectiveDate/provinces/$provinceCode/communes';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final list = json['communes'] as List<dynamic>;
        final communes = list
            .map((e) => CommuneData.fromJson(e as Map<String, dynamic>))
            .toList();
        _communesCache[provinceCode] = communes;
        return communes;
      }
    } catch (e) {
      debugPrint('AddressService.getCommunes error: $e');
    }
    return [];
  }

  /// Clear all caches (e.g. on locale change)
  static void clearCache() {
    _provincesCache = null;
    _communesCache.clear();
  }
}
