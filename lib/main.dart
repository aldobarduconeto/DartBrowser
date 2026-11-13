import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_all/webview_all.dart';

import 'controllers/browser_controller.dart';
import 'models/browser_data.dart';
import 'l10n/browser_locale.dart';
import 'views/browser_view.dart';
import 'views/welcome_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final data = BrowserData(await SharedPreferences.getInstance());
  final browser = BrowserController(data);
  String? startupError;
  if (WebViewPlatform.instance == null) {
    startupError = 'O motor de navegação não foi inicializado.';
  } else if (browser.engine.usesWebView2) {
    final fixedPath = browser.fixedRuntimePath;
    try {
      if (fixedPath != null) {
        await browser.engine.initializeFixedRuntime(fixedPath);
        browser.engineVersion = 'Fixed Version';
      } else {
        browser.engineVersion = await browser.engine.runtimeVersion();
        if (browser.engineVersion == null) {
          startupError = 'Instale o Microsoft Edge WebView2 Runtime e abra o Dart Browser novamente.';
        }
      }
    } catch (_) {
      startupError = fixedPath == null
          ? 'Não foi possível verificar o Microsoft Edge WebView2 Runtime.'
          : 'Não foi possível iniciar o WebView2 pela pasta selecionada.';
    }
  }
  if (startupError == null && browser.hasCompletedWelcome) {
    browser.restoreSession();
  }
  var isTv = false;
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      isTv =
          await const MethodChannel('dart_browser/device')
              .invokeMethod<bool>('isTv') ??
          false;
    } on PlatformException {
      isTv = false;
    } on MissingPluginException {
      isTv = false;
    }
  }
  runApp(DartBrowser(browser: browser, startupError: startupError, isTv: isTv));
}

class DartBrowser extends StatefulWidget {
  const DartBrowser({
    super.key,
    required this.browser,
    this.startupError,
    this.isTv = false,
  });

  final BrowserController browser;
  final String? startupError;
  final bool isTv;

  @override
  State<DartBrowser> createState() => _DartBrowserState();
}

class _DartBrowserState extends State<DartBrowser> {
  BrowserController get browser => widget.browser;
  late bool _showWelcome = !browser.hasCompletedWelcome;
  bool _resetRuntime = false;

  Future<void> resetRuntime() async {
    try {
      await browser.setFixedRuntimePath(null);
      if (mounted) setState(() => _resetRuntime = true);
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void finishWelcome() {
    browser.restoreSession();
    setState(() => _showWelcome = false);
  }

  ThemeData _theme(Brightness brightness, BrowserAccent accent) {
    final isDark = brightness == Brightness.dark;
    final isOled = isDark && browser.oledNotifier.value;
    final surface = isOled
        ? Colors.black
        : isDark
        ? const Color(0xFF101319)
        : const Color(0xFFF4F6FA);

    final colors = ColorScheme.fromSeed(
      seedColor: Color(accent.argb),
      brightness: brightness,
      surface: surface,
    );

    final radius = browser.cornerRadiusNotifier.value;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: isOled
            ? const Color(0xFF0D0D0D)
            : isDark
            ? const Color(0xFF191E28)
            : Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: shape.copyWith(
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: shape,
        backgroundColor: isOled
            ? const Color(0xFF121212)
            : isDark
            ? const Color(0xFF202632)
            : Colors.white,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isOled
            ? const Color(0xFF121212)
            : isDark
            ? const Color(0xFF232A38)
            : Colors.white,
        elevation: 6,
        shape: shape,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        browser.themeNotifier,
        browser.localeNotifier,
        browser.accentNotifier,
        browser.oledNotifier,
        browser.cornerRadiusNotifier,
      ]),
      builder: (context, child) => MaterialApp(
        title: 'Dart Browser',
        locale: browser.localeNotifier.value,
        supportedLocales: BrowserLocale.supported,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light, browser.accentNotifier.value),
        darkTheme: _theme(Brightness.dark, browser.accentNotifier.value),
        themeMode: browser.themeNotifier.value,
        home: widget.startupError == null
            ? !_showWelcome
                  ? BrowserView(browser: browser, isTv: widget.isTv)
                  : WelcomePage(browser: browser, onContinue: finishWelcome)
            : Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _resetRuntime
                              ? 'Feche e reabra o Dart Browser para usar o WebView2 do sistema.'
                              : widget.startupError!,
                          textAlign: TextAlign.center,
                        ),
                        if (browser.engine.usesWebView2 &&
                            browser.fixedRuntimePath != null) ...[
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: resetRuntime,
                            child: const Text('Voltar ao WebView2 do sistema'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
