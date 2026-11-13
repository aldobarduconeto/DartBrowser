import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';
import '../browser_settings.dart';

class ShieldDialog extends StatelessWidget {
  const ShieldDialog({super.key, required this.browser, required this.tab});

  final BrowserController browser;
  final BrowserTab tab;

  static Future<void> show(
    BuildContext context, {
    required BrowserController browser,
    required BrowserTab tab,
  }) async {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => ShieldDialog(browser: browser, tab: tab),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 440,
            child: ShieldDialog(browser: browser, tab: tab),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final host = tab.host;

    return ListenableBuilder(
      listenable: browser,
      builder: (context, _) {
        final isWhitelisted = browser.isHostWhitelisted(host);
        final isProtectionActive =
            (browser.data.adBlockEnabled || browser.data.antiTrackingEnabled) &&
            !isWhitelisted;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // CABEÇALHO DO ESCUDO
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isProtectionActive
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isProtectionActive
                          ? Icons.shield_rounded
                          : Icons.shield_outlined,
                      size: 28,
                      color: isProtectionActive ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isProtectionActive
                              ? 'Proteção Ativa'
                              : 'Proteção Pausada',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isProtectionActive
                                ? Colors.green.shade800
                                : colors.onSurface,
                          ),
                        ),
                        Text(
                          host.isNotEmpty ? host : 'Página atual',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: !isWhitelisted,
                    activeThumbColor: Colors.green,
                    onChanged: (val) {
                      browser.toggleWhitelistHost(host);
                      browser.reload();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // CARDS DE ESTATÍSTICAS DA ABA
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      icon: Icons.block_flipped,
                      title: 'Anúncios',
                      count: tab.blockedAdsCount,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      icon: Icons.track_changes_rounded,
                      title: 'Rastreadores',
                      count: tab.blockedTrackersCount,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // PROTEÇÕES ATIVAS
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      context,
                      icon: Icons.fingerprint_rounded,
                      title: 'Anti-Fingerprint (Canvas & Áudio)',
                      active: browser.data.antiFingerprintEnabled,
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureRow(
                      context,
                      icon: Icons.link_off_rounded,
                      title: 'Limpeza de Parâmetros de URL',
                      active: browser.data.stripTrackingParams,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // TOTAL HISTÓRICO ACUMULADO
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Total histórico bloqueado no DartBrowser: ${browser.data.totalBlockedAds + browser.data.totalBlockedTrackers}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // BOTÃO PARA CONFIGURAÇÕES DE PRIVACIDADE
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Configurações de Privacidade'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => BrowserSettings(browser: browser),
                        ),
                      );
                    },
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Concluído'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool active,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: active ? colors.primary : colors.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: active
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            active ? 'Ativo' : 'Desativado',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: active ? Colors.green.shade800 : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
