import 'package:flutter/gestures.dart';

import '../l10n/browser_text.dart';

import 'package:flutter/material.dart';

import '../controllers/browser_controller.dart';
import '../models/tab_group.dart';
import '../services/window_service.dart';
import 'components/browser_context_menu.dart';
import 'components/window_caption_controls.dart';

class BrowserTabs extends StatelessWidget {
  const BrowserTabs({
    super.key,
    required this.browser,
    required this.vertical,
    required this.compact,
    required this.onNewTab,
    required this.onSelect,
    required this.onEditGroup,
  });

  final BrowserController browser;
  final bool vertical;
  final bool compact;
  final void Function(TabGroup?) onNewTab;
  final ValueChanged<int> onSelect;
  final void Function(BrowserTab?, TabGroup?) onEditGroup;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = <Widget>[];
    final shown = <TabGroup>{};
    final membersByGroup = <TabGroup, List<int>>{};
    for (final (index, tab) in browser.tabs.indexed) {
      final group = tab.group;
      if (group != null) (membersByGroup[group] ??= []).add(index);
    }

    for (final (index, tab) in browser.tabs.indexed) {
      final group = tab.group;
      if (group == null) {
        entries.add(_tab(context, index));
      } else if (shown.add(group)) {
        final members = membersByGroup[group]!;
        entries.add(_group(context, group, members.length));
        if (!group.collapsed) {
          entries.addAll(members.map((item) => _tab(context, item)));
        }
      }
    }
    for (final group in browser.groups.where(
      (group) => !shown.contains(group),
    )) {
      entries.add(_group(context, group, 0));
    }

    // BOTÃO "+" COLOCADO DIRETAMENTE AO LADO DA ÚLTIMA ABA NO MODO HORIZONTAL
    entries.add(
      DragTarget<BrowserTab>(
        onWillAcceptWithDetails: (_) => browser.tabs.isNotEmpty,
        onAcceptWithDetails: (details) {
          final anchor = browser.tabs.last;
          if (identical(anchor, details.data)) {
            browser.moveToGroup(details.data, null);
          } else {
            browser.placeTab(details.data, anchor, after: true, ungroup: true);
          }
        },
        builder: (context, candidates, _) => Tooltip(
          message: 'Solte aqui para mover ao fim e retirar do grupo',
          child: Container(
            width: vertical ? null : 30,
            height: 34,
            color: candidates.isEmpty ? null : colors.primaryContainer,
            child: const Icon(Icons.drag_indicator, size: 17),
          ),
        ),
      ),
    );
    if (!vertical) {
      entries.add(_inlineAddButton(context));
    } else {
      entries.add(
        DragTarget<BrowserTab>(
          onWillAcceptWithDetails: (_) => browser.tabs.isNotEmpty,
          onAcceptWithDetails: (details) {
            final last = browser.tabs.last;
            if (identical(last, details.data)) {
              browser.moveToGroup(details.data, null);
            } else {
              browser.placeTab(details.data, last, after: true, ungroup: true);
            }
          },
          builder: (context, candidates, _) => Container(
            height: 42,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: candidates.isNotEmpty
                  ? colors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: candidates.isNotEmpty
                  ? Border.all(color: colors.primary, width: 1.2)
                  : null,
            ),
            child: candidates.isNotEmpty
                ? const Center(
                    child: Text(
                      'Soltar aqui para retirar do grupo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      );
    }

    final list = vertical
        ? ListView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            children: entries,
          )
        : null;

    final addVertical = IconButton(
      tooltip: 'Nova aba (Ctrl+T)',
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: colors.surfaceContainerHigh.withValues(alpha: 0.4),
      ),
      onPressed: () => onNewTab(null),
      icon: const Icon(Icons.add_rounded, size: 20),
    );

    if (!vertical) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: () => WindowService.maximize(),
        onSecondaryTapUp: (details) =>
            DartBrowserContextMenu.showTabBarContextMenu(
              context,
              position: details.globalPosition,
              browser: browser,
            ),
        child: Container(
          width: double.infinity,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              textDirection: TextDirection.ltr,
              children: [
                // No macOS, espaço para os botões semáforo nativos do sistema
                if (WindowService.isMacOS) const SizedBox(width: 78),

                // Identidade e ícone discreto do navegador no canto superior esquerdo
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  child: Tooltip(
                    message: 'Dart Browser',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                ),
                // Faixa de abas rolável com o botão '+' colado na última aba
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        (constraints.maxWidth -
                                34 -
                                (WindowService.isMacOS ? 78 : 0) -
                                (WindowService.isDesktop &&
                                        !WindowService.isMacOS
                                    ? 140
                                    : 0) -
                                40)
                            .clamp(0.0, double.infinity),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: entries,
                    ),
                  ),
                ),
                // Espaço vazio nativo para arrastar a janela e soltar abas fora de grupos
                Expanded(
                  child: DragTarget<BrowserTab>(
                    onWillAcceptWithDetails: (_) => browser.tabs.isNotEmpty,
                    onAcceptWithDetails: (details) {
                      if (browser.tabs.isNotEmpty) {
                        final last = browser.tabs.last;
                        if (identical(last, details.data)) {
                          browser.moveToGroup(details.data, null);
                        } else {
                          browser.placeTab(
                            details.data,
                            last,
                            after: true,
                            ungroup: true,
                          );
                        }
                      }
                    },
                    builder: (context, candidates, _) => Container(
                      decoration: BoxDecoration(
                        color: candidates.isNotEmpty
                            ? colors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanStart: (_) => WindowService.startDragging(),
                        onDoubleTap: () => WindowService.maximize(),
                        onSecondaryTapUp: (details) =>
                            DartBrowserContextMenu.showTabBarContextMenu(
                              context,
                              position: details.globalPosition,
                              browser: browser,
                            ),
                        child: const SizedBox(
                          height: 40,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
                // Controles nativos da janela para Windows e Linux
                if (WindowService.isDesktop && !WindowService.isMacOS)
                  const WindowCaptionControls(height: 40),
              ],
            ),
          ),
        ),
      );
    }

    final separator = BorderSide(
      color: colors.outlineVariant.withValues(alpha: 0.5),
    );
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: browser.sidebarOnRight
            ? Border(left: separator)
            : Border(right: separator),
      ),
      child: Column(
        children: [
          if (WindowService.isMacOS && !browser.sidebarOnRight)
            const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!compact) Expanded(child: addVertical),
                if (!compact) const SizedBox(width: 8),
                IconButton(
                  tooltip: compact
                      ? 'Expandir barra lateral'
                      : 'Recolher barra lateral',
                  onPressed: browser.toggleCompactTabs,
                  icon: Icon(
                    (compact != browser.sidebarOnRight)
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          if (compact)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: addVertical,
            ),
          if (list != null) Expanded(child: list),
        ],
      ),
    );
  }

  Widget _inlineAddButton(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: Tooltip(
            message: 'Nova aba (Ctrl+T)',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onNewTab(null),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                ),
                child: const Icon(Icons.add_rounded, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTabContextMenu(
    BuildContext context,
    BrowserTab tab,
    int index,
    Offset position,
  ) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                tab.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(tab.isPinned ? 'Desafixar aba' : 'Fixar aba'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'mute',
          child: Row(
            children: [
              Icon(
                tab.isMuted
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(tab.isMuted ? 'Desativar mudo' : 'Silenciar aba'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.control_point_duplicate_rounded, size: 16),
              SizedBox(width: 8),
              BrowserText('Duplicar aba'),
            ],
          ),
        ),
        if (!tab.isSuspended && tab != browser.current)
          const PopupMenuItem(
            value: 'suspend',
            child: Row(
              children: [
                Icon(Icons.bedtime_outlined, size: 16),
                SizedBox(width: 8),
                Text('Suspender aba (liberar memória)'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'new_group',
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 16),
              SizedBox(width: 8),
              Text('Criar grupo com esta aba'),
            ],
          ),
        ),
        if (tab.group != null)
          const PopupMenuItem(
            value: 'ungroup',
            child: Row(
              children: [
                Icon(Icons.folder_delete_outlined, size: 16),
                SizedBox(width: 8),
                Text('Retirar do grupo'),
              ],
            ),
          ),
        for (final group in browser.groups)
          PopupMenuItem(
            value: 'group_${group.id}',
            enabled: tab.group != group,
            child: Text(
              'Mover para ${group.name}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const PopupMenuDivider(),
        if (browser.tabs.length > 1) ...[
          const PopupMenuItem(
            value: 'close_others',
            child: Text('Fechar outras abas'),
          ),
          if (index < browser.tabs.length - 1)
            const PopupMenuItem(
              value: 'close_right',
              child: Text('Fechar abas à direita'),
            ),
        ],
        const PopupMenuItem(
          value: 'close',
          child: Row(
            children: [
              Icon(Icons.close_rounded, size: 16),
              SizedBox(width: 8),
              BrowserText('Fechar aba'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'pin':
          browser.togglePinTab(tab);
        case 'mute':
          browser.toggleMuteTab(tab);
        case 'duplicate':
          browser.duplicateTab(tab);
        case 'suspend':
          browser.suspendTab(tab);
        case 'new_group':
          onEditGroup(tab, null);
        case 'ungroup':
          browser.moveToGroup(tab, null);
        case 'close_others':
          browser.closeOtherTabs(index);
        case 'close_right':
          browser.closeTabsToTheRight(index);
        case 'close':
          browser.closeTab(index);
        default:
          if (value.startsWith('group_')) {
            final gid = int.tryParse(value.replaceFirst('group_', ''));
            final target = browser.groups.where((g) => g.id == gid).firstOrNull;
            if (target != null) browser.moveToGroup(tab, target);
          }
      }
    });
  }

  Widget _tab(BuildContext context, int index) {
    final tab = browser.tabs[index];
    final label = tab.displayTitle;
    final colors = Theme.of(context).colorScheme;
    final isSelected = browser.current == tab;

    final groupColor = tab.group != null
        ? Color(tab.group!.color)
        : (tab.isIncognito ? Colors.purple : colors.primary);

    final hasFavicon =
        !tab.isIncognito && !tab.isSuspended && tab.effectiveFaviconUrl != null;

    // Avatar com ícone real do site (favicon) ou indicador de status
    final avatar = Tooltip(
      message: tab.isPinned ? '$label (Aba Fixada)' : label,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: hasFavicon
              ? Colors.transparent
              : (tab.isIncognito
                    ? Colors.purple.withValues(alpha: 0.2)
                    : isSelected
                    ? groupColor.withValues(alpha: 0.18)
                    : colors.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: tab.isIncognito
              ? const Icon(
                  Icons.visibility_off_rounded,
                  size: 12,
                  color: Colors.purple,
                )
              : tab.isSuspended
              ? Icon(
                  Icons.bedtime_outlined,
                  size: 12,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                )
              : tab.effectiveFaviconUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    tab.effectiveFaviconUrl!,
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      final cleanHost = tab.host.replaceFirst(
                        RegExp(r'^www\.'),
                        '',
                      );
                      return Image.network(
                        'https://icons.duckduckgo.com/ip3/$cleanHost.ico',
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.public_rounded,
                          size: 14,
                          color: isSelected
                              ? groupColor
                              : colors.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                )
              : Icon(
                  Icons.public_rounded,
                  size: 14,
                  color: isSelected ? groupColor : colors.onSurfaceVariant,
                ),
        ),
      ),
    );

    final tile = _item(
      key: ObjectKey(tab),
      context: context,
      label: label,
      leading: avatar,
      selected: isSelected,
      isSuspended: tab.isSuspended,
      isPinned: tab.isPinned,
      groupColor: tab.group != null ? Color(tab.group!.color) : null,
      onTap: () => onSelect(index),
      onSecondaryTapUp: (details) =>
          _showTabContextMenu(context, tab, index, details.globalPosition),
      actions: [
        if (tab.hasAudio && !tab.isMuted)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Tooltip(
              message: 'Aba reproduzindo áudio. Clique para silenciar',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => browser.toggleMuteTab(tab),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.volume_up_rounded,
                    size: 14,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
          ),
        if (tab.isMuted)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Tooltip(
              message: 'Aba silenciada. Clique para desativar mudo',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => browser.toggleMuteTab(tab),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.volume_off_rounded,
                    size: 14,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
        if (!tab.isPinned)
          Tooltip(
            message: 'Fechar aba',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => browser.closeTab(index),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 14),
              ),
            ),
          ),
      ],
    );
    final dropKey = GlobalKey();
    return DragTarget<BrowserTab>(
      key: ObjectKey(tab),
      onWillAcceptWithDetails: (details) => !identical(details.data, tab),
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject();
        final target = dropKey.currentContext?.findRenderObject();
        final bounds = target is RenderBox ? target : box;
        if (bounds is! RenderBox) return;
        final local = bounds.globalToLocal(details.offset);
        browser.placeTab(
          details.data,
          tab,
          after: vertical
              ? local.dy >= bounds.size.height / 2
              : local.dx >= bounds.size.width / 2,
        );
      },
      builder: (context, candidates, _) => Container(
        key: dropKey,
        color: candidates.isEmpty ? null : colors.primaryContainer,
        child: LongPressDraggable<BrowserTab>(
          data: tab,
          delay: const Duration(milliseconds: 160),
          maxSimultaneousDrags: 1,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _dragPreview(context, label),
          child: _MouseTabDraggable(
            data: tab,

            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _dragPreview(context, label),
            child: tile,
          ),
        ),
      ),
    );
  }

  Widget _group(BuildContext context, TabGroup group, int count) {
    final groupColor = Color(group.color);

    final icon = Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: groupColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: groupColor, shape: BoxShape.circle),
        ),
      ),
    );

    final tile = _item(
      key: ObjectKey(group),
      context: context,
      label: '${group.name} ($count)',
      leading: icon,
      isGroupHeader: true,
      selected: group.collapsed && browser.current.group == group,
      groupColor: groupColor,
      onTap: () => browser.toggleGroup(group),
      onSecondaryTapUp: (details) {
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx,
            details.globalPosition.dy,
          ),
          items: const [
            PopupMenuItem(value: 'add', child: Text('Nova aba neste grupo')),
            PopupMenuItem(value: 'edit', child: Text('Editar nome e cor')),
            PopupMenuItem(value: 'remove', child: Text('Desagrupar abas')),
          ],
        ).then((value) {
          if (value == null) return;
          switch (value) {
            case 'edit':
              onEditGroup(null, group);
            case 'add':
              onNewTab(group);
            case 'remove':
              browser.removeGroup(group);
          }
        });
      },
      actions: const [],
    );
    return DragTarget<BrowserTab>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) =>
          browser.moveToGroup(details.data, group),
      builder: (context, candidates, _) => ColoredBox(
        color: candidates.isEmpty
            ? Colors.transparent
            : groupColor.withValues(alpha: .3),
        child: tile,
      ),
    );
  }

  Widget _dragPreview(BuildContext context, String title) {
    return Material(
      elevation: 4,
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(title, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _item({
    required Key key,
    required BuildContext context,
    required String label,
    required Widget leading,
    required bool selected,
    required VoidCallback onTap,
    required void Function(TapUpDetails) onSecondaryTapUp,
    required List<Widget> actions,
    Color? groupColor,
    bool isGroupHeader = false,
    bool isSuspended = false,
    bool isPinned = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: selected && !isGroupHeader
          ? BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.25),
              width: 0.8,
            )
          : BorderSide.none,
    );

    final tabColor = selected
        ? (isGroupHeader
              ? (groupColor?.withValues(alpha: 0.15) ?? colors.primaryContainer)
              : colors.surfaceContainerHighest.withValues(alpha: 0.75))
        : (isGroupHeader
              ? colors.surfaceContainerHighest.withValues(alpha: 0.3)
              : Colors.transparent);

    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(
        horizontal: vertical ? 4 : 2,
        vertical: vertical ? 2 : 0,
      ),
      child: Center(
        child: SizedBox(
          width: vertical ? null : (isPinned ? 40.0 : 190.0),
          height: vertical ? 36 : 32,
          child: Opacity(
            opacity: isSuspended ? 0.6 : 1.0,
            child: Material(
              color: tabColor,
              shape: shape,
              elevation: selected && !isGroupHeader ? 1 : 0,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              child: InkWell(
                customBorder: shape,
                onTap: onTap,
                onSecondaryTapUp: onSecondaryTapUp,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (compact || isPinned) ? 0 : 8,
                  ),
                  child: Row(
                    mainAxisAlignment: isPinned
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      // Barra vertical indicadora na aba ativa
                      if (selected && !vertical && !isPinned && !isGroupHeader)
                        Container(
                          width: 3,
                          height: 14,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: groupColor ?? colors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      leading,
                      if (!compact && !isPinned) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selected
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...actions,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MouseTabDraggable extends Draggable<BrowserTab> {
  const _MouseTabDraggable({
    required BrowserTab super.data,
    required super.feedback,
    required super.child,
    required super.dragAnchorStrategy,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => ImmediateMultiDragGestureRecognizer(
    supportedDevices: const {
      PointerDeviceKind.mouse,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.stylus,
    },
    allowedButtonsFilter: (buttons) => buttons == kPrimaryMouseButton,
  )..onStart = onStart;
}
