// Pure Dart — no Flutter imports beyond dart:ui geometry.
import 'dart:math';
import 'dart:ui';

import '../engine/sphere.dart';
import '../models/government_def.dart';
import '../models/solar_system.dart';

/// Threat tier for map color coding. Derived from the government's
/// pirate/police profile — the one fact a captain wants at a glance.
enum ThreatLevel { safe, contested, hostile }

ThreatLevel threatLevel(SolarSystem system) {
  final gov = GovernmentDef.forType(system.government);
  final danger = gov.pirateStrength - (gov.policeStrength ~/ 2);
  if (danger >= 4) return ThreatLevel.hostile;
  if (danger >= 2) return ThreatLevel.contested;
  return ThreatLevel.safe;
}

/// Map threat tier to its display color.
Color threatColor(ThreatLevel level) {
  switch (level) {
    case ThreatLevel.safe:
      return const Color(0xFF2dd4bf); // teal
    case ThreatLevel.contested:
      return const Color(0xFFfbbf24); // amber
    case ThreatLevel.hostile:
      return const Color(0xFFf87171); // red
  }
}

/// A projected point: screen position plus depth (z > 0 faces the viewer).
class GlobePoint {
  final Offset screen;
  final double z; // −1..1 after rotation; front hemisphere is z > 0
  final double scale; // perspective size factor
  const GlobePoint(this.screen, this.z, this.scale);
  bool get front => z > 0;
}

/// Orbit camera around the galactic sphere.
///
/// Yaw spins the globe, pitch tips it (clamped shy of the poles), and
/// [radiusPx] is the globe's on-screen radius — the zoom.
class GlobeCamera {
  GlobeCamera({
    required this.yaw,
    required this.pitch,
    required this.radiusPx,
  });

  double yaw;
  double pitch;
  double radiusPx;
  Size viewport = Size.zero;

  static const double maxPitch = 1.45; // just shy of the pole

  /// Mild perspective: the near side of the globe reads slightly larger.
  static const double _persp = 0.22;

  Offset get center => Offset(viewport.width / 2, viewport.height / 2);

  /// Rotate a unit vector into camera space.
  (double, double, double) rotate(double ux, double uy, double uz) {
    // Yaw about the y (polar) axis.
    final cy = cos(yaw), sy = sin(yaw);
    final x1 = ux * cy + uz * sy;
    final z1 = -ux * sy + uz * cy;
    // Pitch about the x (screen-horizontal) axis.
    final cp = cos(pitch), sp = sin(pitch);
    final y2 = uy * cp - z1 * sp;
    final z2 = uy * sp + z1 * cp;
    return (x1, y2, z2);
  }

  /// Project a system's chart coordinates to the screen.
  GlobePoint projectChart(num x, num y) {
    final (ux, uy, uz) = SphereGeo.unitOf(x, y);
    return projectUnit(ux, uy, uz);
  }

  GlobePoint projectUnit(double ux, double uy, double uz) {
    final (rx, ry, rz) = rotate(ux, uy, uz);
    final scale = 1.0 / (1.0 - rz * _persp);
    return GlobePoint(
      center + Offset(rx, -ry) * radiusPx * scale,
      rz,
      scale,
    );
  }

  /// Spin the globe by a screen-space drag — grabbing the surface.
  void dragBy(Offset delta) {
    yaw -= delta.dx / radiusPx;
    pitch -= delta.dy / radiusPx;
    pitch = pitch.clamp(-maxPitch, maxPitch);
    yaw = _wrapAngle(yaw);
  }

  /// Yaw/pitch that bring the given chart point to face the viewer
  /// dead-center.
  static (double, double) faceAngles(num x, num y) {
    final lon = SphereGeo.lonOf(x);
    final lat = SphereGeo.latOf(y);
    // x1 = cos(lat)·cos(lon − yaw) = 0 with z1 = cos(lat)·sin(lon − yaw) > 0
    //   ⇒ yaw = lon − π/2.
    // Then v1 = (0, sin lat, cos lat) and pitch = lat zeroes y and puts
    // the point at (0, 0, 1) — dead center, facing the viewer.
    final yaw = _wrapAngle(lon - pi / 2);
    final pitch = lat.clamp(-maxPitch, maxPitch);
    return (yaw, pitch);
  }

  static double _wrapAngle(double a) {
    var r = a % (2 * pi);
    if (r > pi) r -= 2 * pi;
    if (r < -pi) r += 2 * pi;
    return r;
  }

  /// Shortest-path interpolation between two yaw angles.
  static double lerpYaw(double a, double b, double t) {
    final diff = _wrapAngle(b - a);
    return _wrapAngle(a + diff * t);
  }

  GlobeCamera copy() =>
      GlobeCamera(yaw: yaw, pitch: pitch, radiusPx: radiusPx)
        ..viewport = viewport;
}

/// Interpolate camera poses for fly-to animations (yaw takes the short
/// way around; zoom interpolates in log space).
GlobeCamera lerpGlobe(GlobeCamera a, GlobeCamera b, double t) {
  return GlobeCamera(
    yaw: GlobeCamera.lerpYaw(a.yaw, b.yaw, t),
    pitch: a.pitch + (b.pitch - a.pitch) * t,
    radiusPx: exp(log(a.radiusPx) + (log(b.radiusPx) - log(a.radiusPx)) * t),
  )..viewport = a.viewport;
}
