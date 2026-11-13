import 'package:flutter/material.dart';

String browserText(BuildContext context, String source) {
  final translations = _translations[source];
  if (translations == null) return source;
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => translations.$1,
    'es' => translations.$2,
    _ => source,
  };
}

class BrowserText extends StatelessWidget {
  const BrowserText(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) => Text(browserText(context, source));
}

const _translations = <String, (String, String)>{
  'Tema': ('Theme', 'Tema'),
  'Sistema': ('System', 'Sistema'),
  'Claro': ('Light', 'Claro'),
  'Escuro': ('Dark', 'Oscuro'),
  'Abas na lateral': ('Vertical tabs', 'Pestañas verticales'),
  'Abas no topo': ('Tabs on top', 'Pestañas arriba'),
  'Boas-vindas ao Dart Browser': (
    'Welcome to Dart Browser',
    'Te damos la bienvenida a Dart Browser',
  ),
  'Escolha seu buscador, o tema e a posição das abas. Você pode mudar essas opções nas configurações.':
      (
        'Choose your search engine, theme and tab position. You can change them in Settings.',
        'Elige el buscador, el tema y la posición de las pestañas. Puedes cambiarlos en Configuración.',
      ),
  'Começar a navegar': ('Start browsing', 'Empezar a navegar'),
  'Salvando…': ('Saving…', 'Guardando…'),
  'Não foi possível salvar a configuração inicial.': (
    'Could not save the initial settings.',
    'No se pudo guardar la configuración inicial.',
  ),
  'Mecanismo de busca': ('Search engine', 'Buscador'),
  'Escolher buscador': ('Choose search engine', 'Elegir buscador'),
  'Configurações': ('Settings', 'Configuración'),
  'Favoritos': ('Bookmarks', 'Marcadores'),
  'Histórico': ('History', 'Historial'),
  'Lista de Leitura': ('Reading list', 'Lista de lectura'),
  'Nova aba': ('New tab', 'Nueva pestaña'),
  'Duplicar aba': ('Duplicate tab', 'Duplicar pestaña'),
  'Reabrir aba fechada': ('Reopen closed tab', 'Reabrir pestaña cerrada'),
  'Fechar aba': ('Close tab', 'Cerrar pestaña'),
  'Voltar': ('Back', 'Atrás'),
  'Avançar': ('Forward', 'Adelante'),
  'Página inicial': ('Home page', 'Página de inicio'),
  'Cancelar': ('Cancel', 'Cancelar'),
  'Salvar': ('Save', 'Guardar'),
  'Fechar': ('Close', 'Cerrar'),
  'Nova Guia Anônima': ('New private tab', 'Nueva pestaña privada'),
  'Central de Downloads': ('Downloads', 'Descargas'),
  'Extensões Web': ('Web extensions', 'Extensiones web'),
  'Extensões': ('Extensions', 'Extensiones'),
  'Navegação': ('Navigation', 'Navegación'),
  'Privacidade e dados': ('Privacy and data', 'Privacidad y datos'),
  'Aparência e Personalização': (
    'Appearance and personalization',
    'Apariencia y personalización',
  ),
  'Nova aba e inicialização': ('New tab and startup', 'Nueva pestaña e inicio'),
  'Motor de navegação': ('Browser engine', 'Motor del navegador'),
  'Complementos': ('Add-ons', 'Complementos'),
  'Tema do aplicativo': ('App theme', 'Tema de la aplicación'),
  'Cor de destaque': ('Accent color', 'Color de acento'),
  'Restaurar abas ao iniciar': (
    'Restore tabs on startup',
    'Restaurar pestañas al iniciar',
  ),
  'Salvar histórico': ('Save history', 'Guardar historial'),
  'Limpar histórico': ('Clear history', 'Borrar historial'),
  'Limpar cookies': ('Clear cookies', 'Borrar cookies'),
  'Limpar cache': ('Clear cache', 'Borrar caché'),
  'Idioma do aplicativo': ('App language', 'Idioma de la aplicación'),
  'Seguir o sistema': ('Follow system', 'Seguir el sistema'),
  'Escolher idioma': ('Choose language', 'Elegir idioma'),
  'Menu de opções': ('Options menu', 'Menú de opciones'),
  'Acesso rápido': ('Quick access', 'Acceso rápido'),
  'Recentes': ('Recent', 'Recientes'),
  'Localizar na página (Ctrl+F)': (
    'Find in page (Ctrl+F)',
    'Buscar en la página (Ctrl+F)',
  ),
  'Modo Leitura Limpa': ('Reader mode', 'Modo de lectura'),
  'Mídias da página': ('Page media', 'Contenido multimedia'),
  'Exibir código-fonte': ('View source', 'Ver código fuente'),
  'Compartilhar via QR Code': (
    'Share via QR code',
    'Compartir mediante código QR',
  ),
  'Favoritar abas abertas': ('Bookmark open tabs', 'Guardar pestañas abiertas'),
  'Gerenciar extensões e scripts': (
    'Manage extensions and scripts',
    'Gestionar extensiones y scripts',
  ),
  'Barra lateral à direita': (
    'Sidebar on the right',
    'Barra lateral a la derecha',
  ),
  'Barra lateral compacta': ('Compact sidebar', 'Barra lateral compacta'),
  'Mostrar sites recentes na nova aba': (
    'Show recent sites in new tabs',
    'Mostrar sitios recientes en pestañas nuevas',
  ),
  'Mostrar acesso rápido na nova aba': (
    'Show quick access in new tabs',
    'Mostrar acceso rápido en pestañas nuevas',
  ),
  'Abrir a página inicial ao iniciar': (
    'Open home page on startup',
    'Abrir la página de inicio al arrancar',
  ),
  'Paleta de Comandos (Ctrl+K)': (
    'Command palette (Ctrl+K)',
    'Paleta de comandos (Ctrl+K)',
  ),
  'Captura de Tela da Web (Ctrl+Shift+S)': (
    'Capture page (Ctrl+Shift+S)',
    'Capturar página (Ctrl+Shift+S)',
  ),
  'Traduzir Página para Português': (
    'Translate page into Portuguese',
    'Traducir página al portugués',
  ),
  'Anotações deste Site': ('Site notes', 'Notas del sitio'),
  'Fixar aba': ('Pin tab', 'Fijar pestaña'),
  'Desafixar aba': ('Unpin tab', 'Desfijar pestaña'),
  'Tema claro': ('Light theme', 'Tema claro'),
  'Tema escuro': ('Dark theme', 'Tema oscuro'),
};
