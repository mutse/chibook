import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 72,
    this.radius = 20,
    this.backgroundColor,
    this.padding,
  });

  final double size;
  final double radius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: padding ?? EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180C1A3B),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius * 0.65),
        child: Image.asset(
          'logo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF76C7FF), Color(0xFF7E7BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
