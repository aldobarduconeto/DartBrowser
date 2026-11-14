import 'dart:io';

import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';
import '../../models/browser_data.dart';
import '../browser_view.dart';

Future<void> openPrivateWindow(
  BuildContext context,
  BrowserController browser,
) async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      if (Platform.isMacOS) {
        final bundle = File(Platform.resolvedExecutable).parent.parent.parent;
        final result = await Process.run('/usr/bin/open', [
          '-n',
          '-a',
          bundle.path,
          '--args',
          '--private-window',
        ]);
        if (result.exitCode != 0) {
          throw ProcessException(
            '/usr/bin/open',
            [],
            'Não foi possível abrir a janela.',
          );
        }
      } else {
        await Process.start(Platform.resolvedExecutable, [
          '--private-window',
        ], mode: ProcessStartMode.detached);
      }
      return;
    } on ProcessException {
      if (!context.mounted) return;
    }
  }

  if (!context.mounted) return;
  final privateBrowser = BrowserController(
    BrowserData(browser.data.preferences),
    privateWindow: true,
  )..addIncognitoTab();
  final route = MaterialPageRoute<void>(
    builder: (_) => BrowserView(browser: privateBrowser),
  );
  await Navigator.of(context).push(route);
  await route.completed;
  privateBrowser.dispose();
}
