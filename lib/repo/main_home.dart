import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/repo_manifest.dart';
import 'home/home.dart';
import 'descubrir/descubrir.dart';
import 'buscar/buscar.dart';
import 'biblioteca/biblioteca.dart';
import 'config/config.dart';
import 'live/live.dart';

const _bg = Color(0xFF0B0D10);
const _sidebarBg = Color(0xFF0F1218);
const _border = Color(0xFF1E2430);
const _accent = Color(0xFFE50914);

/// Shell del repositorio para Desktop.
/// Sidebar vertical con iconos + labels (estilo Netflix).
class RepoMainHome extends StatefulWidget {
  final InstalledRepo repo;
  const RepoMainHome({super.key, required this.repo});

  @override
  State<RepoMainHome> createState() => _RepoMainHomeState();
}

class _RepoMainHomeState extends State<RepoMainHome> {
  int _index = 0;
  late List<({String id, Widget page, IconData icon, IconData selectedIcon, String label})> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs();
  }

  @override
  void didUpdateWidget(covariant RepoMainHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repo.manifest.id != widget.repo.manifest.id) {
      _tabs = _buildTabs();
      _index = 0;
    }
  }

  List<({String id, Widget page, IconData icon, IconData selectedIcon, String label})> _buildTabs() {
    final repo = widget.repo;
    final order = repo.manifest.resolvedTabs;
    final out = <({String id, Widget page, IconData icon, IconData selectedIcon, String label})>[];

    for (final id in order) {
      switch (id) {
        case 'home':
          out.add((
            id: id,
            page: RepoHomePage(repo: repo),
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Inicio',
          ));
        case 'discover':
          out.add((
            id: id,
            page: DiscoverPage(repo: repo),
            icon: Icons.explore_outlined,
            selectedIcon: Icons.explore_rounded,
            label: 'Descubrir',
          ));
        case 'search':
          out.add((
            id: id,
            page: RepoSearchPage(repo: repo),
            icon: Icons.search_rounded,
            selectedIcon: Icons.search_rounded,
            label: 'Buscar',
          ));
        case 'live':
          out.add((
            id: id,
            page: RepoLivePage(repo: repo),
            icon: Icons.live_tv_outlined,
            selectedIcon: Icons.live_tv_rounded,
            label: 'TV Online',
          ));
        case 'library':
          out.add((
            id: id,
            page: BibliotecaPage(repo: repo),
            icon: Icons.video_library_outlined,
            selectedIcon: Icons.video_library_rounded,
            label: 'Biblioteca',
          ));
        case 'settings':
        case 'config':
          out.add((
            id: id,
            page: RepoConfigPage(repo: repo),
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: 'Ajustes',
          ));
      }
    }

    if (out.isEmpty) {
      out.addAll([
        (
          id: 'home',
          page: RepoHomePage(repo: repo),
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Inicio',
        ),
        (
          id: 'search',
          page: RepoSearchPage(repo: repo),
          icon: Icons.search_rounded,
          selectedIcon: Icons.search_rounded,
          label: 'Buscar',
        ),
        (
          id: 'library',
          page: BibliotecaPage(repo: repo),
          icon: Icons.video_library_outlined,
          selectedIcon: Icons.video_library_rounded,
          label: 'Biblioteca',
        ),
        (
          id: 'config',
          page: RepoConfigPage(repo: repo),
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
          label: 'Ajustes',
        ),
      ]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final safeIndex = _index.clamp(0, tabs.length - 1);
    final m = widget.repo.manifest;

    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          // ── SIDEBAR DEL REPO ────────────────────────────────────────────
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: _sidebarBg,
              border: Border(right: BorderSide(color: _border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header con botón volver + logo del repo
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Volver al launcher',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 22),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (m.icon != null && m.icon!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: m.icon!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: const Color(0xFF12151C)),
                        ),
                      ),
                    ),
                  ),

                const Divider(color: _border, height: 1),
                const SizedBox(height: 12),

                // Tabs
                ...List.generate(tabs.length, (i) {
                  final t = tabs[i];
                  final active = i == safeIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: Material(
                      color: active ? _accent.withValues(alpha: 0.14) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _index = i),
                        hoverColor: Colors.white.withValues(alpha: 0.04),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                active ? t.selectedIcon : t.icon,
                                size: 22,
                                color: active ? _accent : Colors.white60,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                                  color: active ? Colors.white : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                const Spacer(),
              ],
            ),
          ),

          // ── CONTENIDO ───────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: safeIndex,
              children: [for (final t in tabs) t.page],
            ),
          ),
        ],
      ),
    );
  }
}
