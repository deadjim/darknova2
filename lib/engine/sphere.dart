// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/solar_system.dart';

/// The galaxy lives on the surface of a sphere.
///
/// System `x`/`y` fields are kept for save compatibility and reinterpreted
/// as spherical coordinates: x (0..150) is longitude, y (0..110) is
/// latitude. All gameplay distance is great-circle distance on a sphere
/// of [radius] parsecs — no edges, no corners, and trade routes wrap the
/// world.
class SphereGeo {
  SphereGeo._();

  /// Sphere radius in parsecs. Chosen so total surface area is
  /// 4πR² ≈ 54 700 pc² at N=400 systems (~137 pc² per system) — the same
  /// density as the original 120-system / R=36pc chart.
  static const double radius = 66.0;

  /// Longitude in radians (0..2π) from a chart x coordinate.
  static double lonOf(num x) => x / 150.0 * 2 * pi;

  /// Latitude in radians (−π/2..π/2) from a chart y coordinate.
  static double latOf(num y) => (y / 110.0 - 0.5) * pi;

  /// Chart coordinates from angles (inverse of lonOf/latOf).
  static (double, double) chartOf(double lon, double lat) {
    final x = (lon % (2 * pi)) / (2 * pi) * 150.0;
    final y = (lat / pi + 0.5) * 110.0;
    return (x, y);
  }

  /// Unit vector for a system's position on the sphere.
  static (double, double, double) unitOf(num x, num y) {
    final lon = lonOf(x);
    final lat = latOf(y);
    return (
      cos(lat) * cos(lon),
      sin(lat),
      cos(lat) * sin(lon),
    );
  }

  /// Great-circle distance between two systems, in parsecs.
  static double distance(SolarSystem a, SolarSystem b) {
    final (ax, ay, az) = unitOf(a.x, a.y);
    final (bx, by, bz) = unitOf(b.x, b.y);
    final dot = (ax * bx + ay * by + az * bz).clamp(-1.0, 1.0);
    return radius * acos(dot);
  }

  /// Angular separation in radians between two chart points.
  static double angleBetween(num x1, num y1, num x2, num y2) {
    final (ax, ay, az) = unitOf(x1, y1);
    final (bx, by, bz) = unitOf(x2, y2);
    return acos((ax * bx + ay * by + az * bz).clamp(-1.0, 1.0));
  }

  /// The farthest any two points can be: half the circumference.
  static double get maxDistance => pi * radius;
}
