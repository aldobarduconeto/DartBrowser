import 'package:flutter/material.dart';

/// Shared surface treatment for browser navigation controls.
ShapeDecoration navigationSurface(
  ColorScheme colors, {
  bool focused = false,
  bool private = false,
}) => ShapeDecoration(
  color: private
      ? Color.alphaBlend(
          colors.tertiary.withValues(alpha: .12),
          focused ? colors.surface : colors.surfaceContainerLow,
        )
      : focused
      ? colors.surface
      : colors.surfaceContainerLow,
  shape: StadiumBorder(
    side: BorderSide(
      color: private
          ? colors.tertiary
          : focused
          ? colors.primary
          : colors.outlineVariant.withValues(alpha: .45),
    ),
  ),
);
