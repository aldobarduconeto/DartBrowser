import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowService {
  const WindowService._();

  static const _channel = MethodChannel('dart_browser/window');

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  static Future<void> startDragging() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod<void>('startDragging');
    } catch (_) {}
  }

  static Future<void> minimize() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod<void>('minimize');
    } catch (_) {}
  }

  static Future<void> maximize() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod<void>('maximize');
    } catch (_) {}
  }

  static Future<void> close() async {
    if (!isDesktop) return;
    try {
      await _channel.invokeMethod<void>('close');
    } catch (_) {}
  }

  static Future<bool> isMaximized() async {
    if (!isDesktop) return false;
    try {
      return await _channel.invokeMethod<bool>('isMaximized') ?? false;
    } catch (_) {
      return false;
    }
  }
}
