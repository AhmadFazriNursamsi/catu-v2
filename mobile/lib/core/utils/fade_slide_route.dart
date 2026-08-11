import 'package:flutter/material.dart';

/// Custom page route dengan animasi fade + slide lembut
/// Dipakai untuk transisi antar halaman auth (Login ↔ Register)
class FadeSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Offset beginOffset;

  FadeSlideRoute({
    required this.page,
    this.beginOffset = const Offset(0.04, 0),
  }) : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: beginOffset,
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
