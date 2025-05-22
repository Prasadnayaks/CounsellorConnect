// lib/widgets/bouncing_widget.dart (NEW FILE)
import 'package:flutter/material.dart';

class BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed; // Callback when the widget is tapped
  final Duration animationDuration;
  final double scaleFactor; // How much to scale down on press

  const BouncingWidget({
    Key? key,
    required this.child,
    this.onPressed,
    this.animationDuration = const Duration(milliseconds: 150), // Quick animation
    this.scaleFactor = 0.95, // Scale down to 95%
  }) : super(key: key);

  @override
  _BouncingWidgetState createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
      reverseDuration: widget.animationDuration, // For a quick bounce back
    );

    // Animate from 1.0 (normal) to scaleFactor (pressed) and back
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut, // Smooth in and out
      // For a more pronounced bounce on release, you might use Curves.elasticOut
      // when reversing, but that requires a more complex setup.
      // For now, easeInOut on reverse is fine.
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward(); // Scale down
  }

  void _handleTapUp(TapUpDetails details) {
    // Animate back to original size with a slight bounce
    _controller.reverse().then((value) {
      // If you want a more springy bounce back, you might play a short forward-reverse sequence here
      // or use a spring simulation. For simplicity, a quick reverse is often enough.
    });
    widget.onPressed?.call(); // Trigger the actual press callback
  }

  void _handleTapCancel() {
    _controller.reverse(); // Scale back if tap is cancelled
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      onTap: widget.onPressed != null ? () { /* Actual onTap is handled by onTapUp to ensure animation plays */ } : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}