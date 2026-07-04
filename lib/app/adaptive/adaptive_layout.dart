import 'package:flutter/material.dart';

enum AdaptiveSizeClass { compact, medium, expanded }

class AdaptiveLayoutData {
  const AdaptiveLayoutData({
    required this.width,
    required this.sizeClass,
    required this.horizontalPadding,
    required this.contentMaxWidth,
  });

  factory AdaptiveLayoutData.fromWidth(double width) {
    if (width >= 1100) {
      return AdaptiveLayoutData(
        width: width,
        sizeClass: AdaptiveSizeClass.expanded,
        horizontalPadding: 32,
        contentMaxWidth: 1100,
      );
    }

    if (width >= 840) {
      return AdaptiveLayoutData(
        width: width,
        sizeClass: AdaptiveSizeClass.medium,
        horizontalPadding: 24,
        contentMaxWidth: 960,
      );
    }

    return AdaptiveLayoutData(
      width: width,
      sizeClass: AdaptiveSizeClass.compact,
      horizontalPadding: 20,
      contentMaxWidth: 720,
    );
  }

  factory AdaptiveLayoutData.fromConstraints(
    BoxConstraints constraints, {
    required double fallbackWidth,
  }) {
    final width = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : fallbackWidth;

    return AdaptiveLayoutData.fromWidth(width);
  }

  final double width;
  final AdaptiveSizeClass sizeClass;
  final double horizontalPadding;
  final double contentMaxWidth;

  bool get showsSidebar => sizeClass != AdaptiveSizeClass.compact;

  bool get isCompact => sizeClass == AdaptiveSizeClass.compact;

  int adaptiveColumns({
    required int compact,
    required int medium,
    required int expanded,
  }) {
    return switch (sizeClass) {
      AdaptiveSizeClass.compact => compact,
      AdaptiveSizeClass.medium => medium,
      AdaptiveSizeClass.expanded => expanded,
    };
  }
}

extension AdaptiveLayoutContext on BuildContext {
  AdaptiveLayoutData get adaptiveLayout {
    return AdaptiveLayoutData.fromWidth(MediaQuery.sizeOf(this).width);
  }
}
