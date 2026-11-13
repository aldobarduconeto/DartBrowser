import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';
import '../../services/find_in_page_service.dart';

class FindInPageBar extends StatefulWidget {
  const FindInPageBar({super.key, required this.browser});

  final BrowserController browser;

  @override
  State<FindInPageBar> createState() => _FindInPageBarState();
}

class _FindInPageBarState extends State<FindInPageBar> {
  final textController = TextEditingController();
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: textController,
                focusNode: focusNode,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Localizar na página...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (val) => widget.browser.findInPage(val),
                onSubmitted: (_) => widget.browser.findNext(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<FindInPageResult>(
            valueListenable: widget.browser.findResultNotifier,
            builder: (context, result, _) {
              if (textController.text.isEmpty) {
                return const SizedBox.shrink();
              }
              final label = result.count > 0
                  ? '${result.current} de ${result.count}'
                  : '0 de 0';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: result.count > 0 ? colors.onSurface : colors.error,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Anterior',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
            onPressed: widget.browser.findPrevious,
          ),
          IconButton(
            tooltip: 'Próxima',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            onPressed: widget.browser.findNext,
          ),
          IconButton(
            tooltip: 'Fechar (Esc)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: widget.browser.closeFindInPage,
          ),
        ],
      ),
    );
  }
}
