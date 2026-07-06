// Pure Dart — no Flutter imports beyond dart:ui geometry.
import 'dart:math';
import 'dart:ui';

import '../models/government_def.dart';
import '../models/solar_system.dart';

/// Threat tier for map color coding. Derived from the government's
/// pirate/police profile — the one fact a captain wants at a glance.
enum ThreatLevel { safe, contested, hostile }

ThreatLevel threatLevel(SolarSystem system) {
  final gov = GovernmentDef.forType(system.government);
  // Lots of pirates and little law = hostile; strong law = safe.
  final danger = gov.pirateStrength - (gov.policeStrength ~/ 2);
  if (danger >= 4) return ThreatLevel.hostile;
  if (danger >= 2) return ThreatLevel.contested;
  return ThreatLevel.safe;
}

/// A pseudo-3D camera over the galactic plane.
///
/// The world is the flat 150×110 parsec chart; the camera looks at it
/// from a fixed tilt, so rows farther "north" foreshorten and shrink —
/// a star-chart-on-the-bridge look. Positions stay honest: screen
/// distance is a monotonic function of plane distance along each axis.
class StarMapCamera {
  StarMapCamera({
    required this.targetX,
    required this.targetZ,
    required this.zoom,
  });

  /// Look-at point on the plane, in parsecs.
  double targetX;
  double targetZ;

  /// Pixels per parsec at the look-at point.
  double zoom;

  Size viewport = Size.zero;

  /// Camera tilt from vertical. ~50° reads as 3D without mangling
  /// distances.
  static const double tilt = 0.88;

  /// Focal length in parsecs — controls perspective strength.
  static const double focal = 170.0;

  static final double _sinT = sin(tilt);
  static final double _cosT = cos(tilt);

  /// Perspective factor for a plane point: >1 nearer (below the target),
  /// <1 farther (above). Clamped so points can't blow up behind the eye.
  double perspectiveAt(double wz) {
    // wz above the target (smaller z) is farther away: depth grows.
    final depth = focal + (targetZ - wz) * _sinT;
    return (focal / max(depth, focal * 0.25)).clamp(0.2, 3.0);
  }

  Offset project(double wx, double wz) {
    final p = perspectiveAt(wz);
    return Offset(
      viewport.width / 2 + (wx - targetX) * zoom * p,
      viewport.height / 2 + (wz - targetZ) * zoom * _cosT * p,
    );
  }

  /// Exact inverse of [project]. The projection is a 1D homography in z,
  /// which solves in closed form:
  ///   sy - cy = u·zoom·cosT·focal / (focal - u·sinT), u = wz - targetZ
  ///   ⇒ u = focal·(sy - cy) / (zoom·cosT·focal + (sy - cy)·sinT)
  (double, double) unproject(Offset s) {
    final dy = s.dy - viewport.height / 2;
    final u = focal * dy / (zoom * _cosT * focal + dy * _sinT);
    final wz = targetZ + u;
    final p = perspectiveAt(wz);
    final wx = targetX + (s.dx - viewport.width / 2) / (zoom * p);
    return (wx, wz);
  }

  /// Reposition the camera so plane point (wx, wz) appears at [screen].
  void lookThrough(Offset screen, double wx, double wz) {
    final dy = screen.dy - viewport.height / 2;
    final v = focal * dy / (zoom * _cosT * focal + dy * _sinT);
    targetZ = wz - v;
    final p = perspectiveAt(wz);
    targetX = wx - (screen.dx - viewport.width / 2) / (zoom * p);
    clampTarget();
  }

  /// Pan by a screen-space delta (finger drag).
  void panScreen(Offset delta) {
    final p = perspectiveAt(targetZ);
    targetX -= delta.dx / (zoom * p);
    targetZ -= delta.dy / (zoom * _cosT * p);
    clampTarget();
  }

  /// Zoom about a screen point so the plane location under the fingers
  /// stays under the fingers.
  void zoomAt(Offset focalPoint, double factor, double minZoom, double maxZoom) {
    final (bx, bz) = unproject(focalPoint);
    zoom = (zoom * factor).clamp(minZoom, maxZoom);
    lookThrough(focalPoint, bx, bz);
  }

  void clampTarget() {
    targetX = targetX.clamp(0.0, 150.0);
    targetZ = targetZ.clamp(0.0, 110.0);
  }

  /// Zoom that fits the whole chart in the viewport.
  double fitZoom() {
    if (viewport == Size.zero) return 4.0;
    final zx = viewport.width / 165.0;
    final zz = viewport.height / (120.0 * _cosT);
    return min(zx, zz);
  }

  StarMapCamera copy() =>
      StarMapCamera(targetX: targetX, targetZ: targetZ, zoom: zoom)
        ..viewport = viewport;
}

/// Interpolate between camera poses for fly-to animations.
StarMapCamera lerpCamera(StarMapCamera a, StarMapCamera b, double t) {
  double l(double x, double y) => x + (y - x) * t;
  return StarMapCamera(
    targetX: l(a.targetX, b.targetX),
    targetZ: l(a.targetZ, b.targetZ),
    // Zoom feels better interpolated logarithmically.
    zoom: exp(l(log(a.zoom), log(b.zoom))),
  )..viewport = a.viewport;
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
