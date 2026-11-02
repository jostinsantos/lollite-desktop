import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Barra de título Windows: fondo negro, botones negros (no transparentes).
/// Se oculta en pantalla completa.
/// Incluye botón de retroceso (navegación app) al lado del minimizar.
class CustomTitleBar extends StatefulWidget {
  final String title;
  final Color? backgroundColor;
  final double height;
  /// Callback de volver. Si es null, intenta Navigator.maybePop con [navigatorKey].
  final VoidCallback? onBack;
  /// Key del Navigator de la app (p.ej. desktopNavigatorKey) para poder hacer pop.
  final GlobalKey<NavigatorState>? navigatorKey;

  const CustomTitleBar({
    super.key,
    this.title = 'LOL Lite',
    this.backgroundColor,
    this.height = 36,
    this.onBack,
    this.navigatorKey,
  });

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _refresh();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    final m = await windowManager.isMaximized();
    final f = await windowManager.isFullScreen();
    if (mounted) {
      setState(() {
        _isMaximized = m;
        _isFullscreen = f;
      });
    }
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    // Forzar refresco: a veces el flag se queda true y la barra no vuelve
    if (mounted) setState(() => _isFullscreen = false);
    // Revalidar por si el SO aún no terminó de salir
    Future<void>.delayed(const Duration(milliseconds: 150), () async {
      try {
        final f = await windowManager.isFullScreen();
        if (mounted && _isFullscreen != f) {
          setState(() => _isFullscreen = f);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    // En pantalla completa no se muestra la barra
    if (_isFullscreen) return const SizedBox.shrink();

    final bg = widget.backgroundColor ?? Colors.black;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (_isMaximized) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: widget.height,
        color: bg,
        child: Row(
          children: [
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/app_icon.ico',
                width: 18,
                height: 18,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/tray_icon.ico',
                  width: 18,
                  height: 18,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            DefaultTextStyle.merge(
              style: const TextStyle(decoration: TextDecoration.none),
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                ),
              ),
            ),
            const Spacer(),
            // Botón de retroceso (navegación app) — al lado del minimizar
            _TitleButton(
              icon: Icons.arrow_back_rounded,
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                  return;
                }
                final nav = widget.navigatorKey?.currentState;
                if (nav != null && nav.canPop()) {
                  nav.pop();
                  return;
                }
                // Fallback: intentar con el contexto del overlay si existe
                final ctx = widget.navigatorKey?.currentContext;
                if (ctx != null && Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
              },
            ),
            _TitleButton(
              icon: Icons.remove,
              onTap: () => windowManager.minimize(),
            ),
            _TitleButton(
              icon: _isMaximized
                  ? Icons.filter_none
                  : Icons.crop_square,
              iconSize: _isMaximized ? 12 : 14,
              onTap: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _TitleButton(
              icon: Icons.close,
              hoverColor: const Color(0xFFE81123),
              onTap: () => windowManager.close(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? hoverColor;
  final double iconSize;

  const _TitleButton({
    required this.icon,
    required this.onTap,
    this.hoverColor,
    this.iconSize = 16,
  });

  @override
  State<_TitleButton> createState() => _TitleButtonState();
}

class _TitleButtonState extends State<_TitleButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    // Fondo negro sólido; hover gris / rojo en cerrar
    final Color bg = _hover
        ? (widget.hoverColor ?? const Color(0xFF2A2A2A))
        : Colors.black;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: double.infinity,
          color: bg,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
