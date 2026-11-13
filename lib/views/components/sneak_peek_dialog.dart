import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_all/webview_all.dart';

import '../../controllers/browser_controller.dart';
import '../../models/browser_data.dart';

class SneakPeekDialog extends StatefulWidget {
  const SneakPeekDialog({
    super.key,
    required this.url,
    this.title,
    required this.browser,
    this.onOpenFull,
  });

  final String url;
  final String? title;
  final BrowserController browser;
  final ValueChanged<String>? onOpenFull;

  static Future<void> show(
    BuildContext context, {
    required String url,
    String? title,
    required BrowserController browser,
    ValueChanged<String>? onOpenFull,
  }) {
    final isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
        Theme.of(context).platform == TargetPlatform.iOS ||
        MediaQuery.sizeOf(context).width < 600;

    if (isMobile) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.88,
          child: SneakPeekDialog(
            url: url,
            title: title,
            browser: browser,
            onOpenFull: onOpenFull,
          ),
        ),
      );
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 960,
            maxHeight: 680,
            minWidth: 400,
            minHeight: 300,
          ),
          child: SneakPeekDialog(
            url: url,
            title: title,
            browser: browser,
            onOpenFull: onOpenFull,
          ),
        ),
      ),
    );
  }

  @override
  State<SneakPeekDialog> createState() => _SneakPeekDialogState();
}

class _SneakPeekDialogState extends State<SneakPeekDialog> {
  final WebViewController _controller = WebViewController();
  int _progress = 0;
  String? _pageTitle;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _pageTitle = widget.title;
    _initController();
  }

  Future<void> _initController() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (url) async {
          final t = await _controller.getTitle();
          if (mounted) {
            setState(() {
              _progress = 100;
              if (t != null && t.isNotEmpty) _pageTitle = t;
            });
          }
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() => _hasError = true);
          }
        },
      ),
    );

    final uri = Uri.tryParse(widget.url);
    if (uri != null && BrowserData.isWeb(uri)) {
      await _controller.loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final uri = Uri.tryParse(widget.url);
    final host = uri?.host ?? widget.url;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // CABEÇALHO DO SNEAK & PEEK
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Badge do Sneak & Peek
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.remove_red_eye_rounded,
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sneak & Peek',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Título e Host da página pré-visualizada
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _pageTitle ?? host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Ações do cabeçalho
                Tooltip(
                  message: 'Copiar link',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copiado!')),
                      );
                    },
                  ),
                ),
                Tooltip(
                  message: 'Abrir em nova aba',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.browser.addTab(address: widget.url);
                    },
                  ),
                ),
                if (widget.onOpenFull != null)
                  Tooltip(
                    message: 'Navegar para este link nesta aba',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenFull!(widget.url);
                      },
                    ),
                  ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Fechar visualização',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          // BARRA DE PROGRESSO DE CARREGAMENTO
          if (_progress < 100 && !_hasError)
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            )
          else
            const SizedBox(height: 2.5),

          // CONTEÚDO AO VIVO DA PÁGINA (WEBVIEW)
          Expanded(
            child: _hasError
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 40,
                          color: colors.error,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Não foi possível pré-visualizar este link.',
                        ),
                        const SizedBox(height: 14),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.browser.addTab(address: widget.url);
                          },
                          child: const Text('Abrir em nova aba normal'),
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(18),
                    ),
                    child: WebViewWidget(controller: _controller),
                  ),
          ),
        ],
      ),
    );
  }
}
