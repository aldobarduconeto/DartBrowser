import 'package:flutter/material.dart';

import '../../services/window_service.dart';

class WindowCaptionControls extends StatefulWidget {
  const WindowCaptionControls({
    super.key,
    this.height = 38.0,
    this.iconSize = 14.0,
  });

  final double height;
  final double iconSize;

  @override
  State<WindowCaptionControls> createState() => _WindowCaptionControlsState();
}

class _WindowCaptionControlsState extends State<WindowCaptionControls>
    with WidgetsBindingObserver {
  bool _isMaximized = false;
  bool _closeHovered = false;
  int _checkGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkMaximized();
  }

  bool _checkScheduled = false;

  @override
  void didChangeMetrics() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _checkMaximized();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    if (!WindowService.isDesktop) return;
    final generation = ++_checkGeneration;
    final max = await WindowService.isMaximized();
    if (mounted && generation == _checkGeneration && max != _isMaximized) {
      setState(() => _isMaximized = max);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!WindowService.isDesktop || WindowService.isMacOS) {
      // macOS usa os botões nativos tipo "semáforo" (traffic lights) no canto superior esquerdo
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    final iconColor = colors.onSurface.withValues(alpha: 0.85);

    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Minimizar
          _CaptionButton(
            width: 46,
            tooltip: 'Minimizar',
            hoverColor: colors.onSurface.withValues(alpha: 0.08),
            onPressed: () {
              WindowService.minimize();
            },
            child: Icon(
              Icons.horizontal_rule_rounded,
              size: widget.iconSize,
              color: iconColor,
            ),
          ),
          // Maximizar / Restaurar
          _CaptionButton(
            width: 46,
            tooltip: _isMaximized ? 'Restaurar tamanho' : 'Maximizar',
            hoverColor: colors.onSurface.withValues(alpha: 0.08),
            onPressed: () async {
              await WindowService.maximize();
              _checkMaximized();
            },
            child: Icon(
              _isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              size: widget.iconSize * 0.9,
              color: iconColor,
            ),
          ),
          // Fechar
          MouseRegion(
            onEnter: (_) => setState(() => _closeHovered = true),
            onExit: (_) => setState(() => _closeHovered = false),
            child: _CaptionButton(
              width: 48,
              tooltip: 'Fechar (Alt+F4)',
              hoverColor: const Color(0xFFE81123),
              onPressed: () {
                WindowService.close();
              },
              child: Icon(
                Icons.close_rounded,
                size: widget.iconSize + 2,
                color: _closeHovered ? Colors.white : iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.width,
    required this.tooltip,
    required this.hoverColor,
    required this.onPressed,
    required this.child,
  });

  final double width;
  final String tooltip;
  final Color hoverColor;
  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 700),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: widget.width,
            color: _hovered ? widget.hoverColor : Colors.transparent,
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
