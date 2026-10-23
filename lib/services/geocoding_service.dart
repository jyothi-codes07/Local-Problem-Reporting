import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  final Map<String, String> _cache = {};

  /// Reverse geocode coordinates to a concise, human-readable civic address
  Future<String> reverseGeocode(double latitude, double longitude) async {
    final key = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'LocalFixApp/1.0 (civic problem reporting)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final formatted = _formatAddress(address, data['display_name'] as String?);
          if (formatted.isNotEmpty) {
            _cache[key] = formatted;
            return formatted;
          }
        }

        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          final parts = displayName.split(',').map((s) => s.trim()).take(3).toList();
          final res = parts.join(', ');
          _cache[key] = res;
          return res;
        }
      }
    } catch (e) {
      debugPrint('[GeocodingService] Reverse geocode error: $e');
    }

    // Fallback if offline, timeout or rate-limited
    final fallback = 'Ward 12 · ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    _cache[key] = fallback;
    return fallback;
  }

  String _formatAddress(Map<String, dynamic> addr, String? fallbackDisplayName) {
    final road = addr['road'] ?? addr['pedestrian'] ?? addr['residential'] ?? addr['path'];
    final locality = addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'] ?? addr['city_district'];
    final city = addr['city'] ?? addr['town'] ?? addr['municipality'] ?? addr['village'];
    final state = addr['state'];

    final components = <String>[];
    if (road != null && road.toString().isNotEmpty) {
      components.add(road.toString());
    }
    if (locality != null && locality.toString().isNotEmpty && locality != road) {
      components.add(locality.toString());
    }
    if (city != null && city.toString().isNotEmpty && !components.contains(city)) {
      components.add(city.toString());
    } else if (state != null && state.toString().isNotEmpty) {
      components.add(state.toString());
    }

    if (components.isNotEmpty) {
      return components.join(', ');
    }

    if (fallbackDisplayName != null && fallbackDisplayName.isNotEmpty) {
      return fallbackDisplayName.split(',').take(3).map((s) => s.trim()).join(', ');
    }

    return '';
  }
}
