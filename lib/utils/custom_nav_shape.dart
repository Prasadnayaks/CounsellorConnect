// lib/main_navigation_shell.dart OR lib/utils/custom_nav_shape.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class WavyBottomAppBarShape implements NotchedShape {
  final double fabMargin; // Margin around the FAB for the notch
  final double waveHeight; // How high the "waves" on the sides rise

  const WavyBottomAppBarShape({
    this.fabMargin = 8.0,
    this.waveHeight = 20.0, // Adjust this for the "peak" of the wave
  });

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    final Path path = Path();

    if (guest == null || !host.overlaps(guest)) {
      // No FAB or no overlap - draw a simple rectangle (or you could add simple top curves)
      path.moveTo(host.left, host.top);
      path.lineTo(host.right, host.top);
      path.lineTo(host.right, host.bottom);
      path.lineTo(host.left, host.bottom);
      path.close();
      return path;
    }

    // FAB properties
    final double fabDiameter = guest.width;
    final double fabRadius = fabDiameter / 2.0;
    final double fabCenterX = guest.center.dx;

    // The effective radius of the circular notch around the FAB
    final double notchRadius = fabRadius + fabMargin;

    // Start drawing from the bottom-left of the host (BottomAppBar)
    path.moveTo(host.left, host.bottom);
    path.lineTo(host.left, host.top); // Straight line up on the left side

    // --- Left Wave ---
    // The wave starts from host.left, host.top and curves up, then down to meet the notch
    // The "peak" of the wave will be at some x-coordinate between host.left and the notch start
    // Let's simplify: the wave will be a Bezier curve from the left edge to the start of the notch.
    // Control point for the left wave:
    // Control X1: host.left + (fabCenterX - notchRadius - host.left) / 2
    // Control Y1: host.top - waveHeight (making it curve upwards)
    // End X1: fabCenterX - notchRadius (start of the notch)
    // End Y1: host.top

    // For the style in the image, the "top" of the bar itself is curved.
    // The bar doesn't have a flat host.top line from which waves emerge.
    // Instead, host.top IS the wave line.

    // Let's define the path from left to right along the top edge.
    // Y-coordinate for the "trough" or lowest point of the wave (sides of FAB notch)
    final double troughY = host.top;
    // Y-coordinate for the "crest" or highest point of the wave (at screen edges)
    final double crestY = host.top - waveHeight; // Wave goes *above* the nominal top

    // Start from the left edge, at the crest of the wave
    path.moveTo(host.left, crestY);

    // Bezier curve from left crest down to the left side of the notch
    // Control point: somewhere between left edge and notch start, at crestY
    // End point: (fabCenterX - notchRadius, troughY)
    path.quadraticBezierTo(
        host.left + host.width * 0.15, // Control point X (adjust for curve shape)
        crestY,                         // Control point Y
        fabCenterX - notchRadius,       // End point X (start of notch)
        troughY                         // End point Y (top of notch side)
    );

    // --- FAB Notch (Circular Arc) ---
    // Arc from the left side of the notch to the right side.
    // The angle is calculated to make a smooth circular cut for the FAB.
    // Angle of the point where the arc meets the straight line (host.top)
    final double angle = math.acos((fabRadius) / notchRadius); // Simplified, assumes notch top is fabRadius deep

    path.arcTo(
      Rect.fromCircle(center: Offset(fabCenterX, troughY), radius: notchRadius),
      math.pi + angle, // Start angle on the left side of the circle
      (math.pi - 2 * angle) * -1, // Sweep angle for the notch (negative for direction)
      false,
    );

    // --- Right Wave ---
    // Bezier curve from the right side of the notch up to the right crest
    // Start point: (fabCenterX + notchRadius, troughY)
    // Control point: somewhere between notch end and right edge, at crestY
    // End point: (host.right, crestY)
    path.quadraticBezierTo(
        host.right - host.width * 0.15, // Control point X (adjust for curve shape)
        crestY,                          // Control point Y
        host.right,                      // End point X (right edge)
        crestY                           // End point Y (crest of wave)
    );

    // Complete the path by drawing the right and bottom edges
    path.lineTo(host.right, host.bottom);
    path.lineTo(host.left, host.bottom);
    path.close();

    return path;
  }
}