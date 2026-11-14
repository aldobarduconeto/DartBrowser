import 'package:flutter/material.dart';

/// Shared surface treatment for browser navigation controls.
ShapeDecoration navigationSurface(
  ColorScheme colors, {
  bool focused = false,
  bool private = false,
}) => ShapeDecoration(
  color: focused ? colors.surface : colors.surfaceContainerLow,
  shape: StadiumBorder(
    side: BorderSide(
      color: private || focused
          ? colors.primary
          : colors.outlineVariant.withValues(alpha: .45),
    ),
  ),
);
