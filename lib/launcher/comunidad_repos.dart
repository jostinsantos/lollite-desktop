import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/services/repo_manager.dart';
import '../../data/services/library_service.dart';
import '../../data/services/github_service.dart';
import '../../data/models/repo_manifest.dart';
import '../../ui/shared/install_repo_dialog.dart';

const _bg = Color(0xFF0B0D10);
const _card = Color(0xFF161A22);
const _border = Color(0xFF1E2430);
const _accent = Color(0xFFE50914);
const _textMuted = Color(0x99FFFFFF);

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  List<CommunityRepoItem> _items = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  final _searchCtrl = TextEditingController();
  final Map<String, String?> _iconCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<RepoManager>().fetchCommunity();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
      _prefetchIcons(list);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _prefetchIcons(List<CommunityRepoItem> list) async {
    final mgr = context.read<RepoManager>();
    final limit = list.length > 24 ? 24 : list.length;
    for (var i = 0; i < limit; i++) {
      final item = list[i];
      if (!mounted) return;
      if (_iconCache.containsKey(item.repo)) continue;
      try {
        final icon = await mgr.peekIcon(item.repo);
        if (!mounted) return;
        setState(() => _iconCache[item.repo] = icon);
      } catch (_) {
        _iconCache[item.repo] = null;
      }
    }
  }

  bool _isInstalled(String userRepo) {
    final installed = context.read<RepoManager>().installed;
    final key = userRepo.toLowerCase();
    return installed.any((r) {
      final id = r.manifest.id.toLowerCase();
      final source = r.sourceUrl.toLowerCase();
      final repoField = r.manifest.repo.toLowerCase();
      return id == key ||
          source.contains(key) ||
          key.contains(id) ||
          repoField == key;
    });
  }

  List<CommunityRepoItem> get _filtered {
    if (_query.trim().isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items.where((e) {
      return e.name.toLowerCase().contains(q) ||
          e.repo.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _install(CommunityRepoItem item) async {
    final mgr = context.read<RepoManager>();

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _accent)),
    );

    try {
      final preview = await mgr.previewFromGithub(item.repo);
      if (!mounted) return;
      Navigator.of(context).pop(); // cerrar loading

      final ok = await showInstallRepoDialog(
        context,
        manifest: preview.manifest,
        contract: preview.contract,
        userRepo: item.repo,
        fallbackAvatarUrl: item.avatarUrl,
      );

      if (ok == true && mounted) {
        // loading otra vez mientras instala
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: _accent)),
        );
        try {
          await mgr.installFromPreview(preview);
          if (!mounted) return;
          Navigator.of(context).pop();
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.name} instalado'),
              backgroundColor: _accent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          if (!mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al instalar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // cerrar loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _uninstall(CommunityRepoItem item) async {
    final mgr = context.read<RepoManager>();
    final installed = mgr.installed;
    final key = item.repo.toLowerCase();
    InstalledRepo? match;
    for (final r in installed) {
      final id = r.manifest.id.toLowerCase();
      final source = r.sourceUrl.toLowerCase();
      final repoField = r.manifest.repo.toLowerCase();
      if (id == key || source.contains(key) || key.contains(id) || repoField == key) {
        match = r;
        break;
      }
    }
    if (match == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Desinstalar', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Desinstalar ${item.name}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desinstalar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await mgr.uninstall(match.manifest.id);
      try {
        await context.read<LibraryService>().clearRepoData(match.manifest.id);
      } catch (_) {}
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final list = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar repositorios...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.white38),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1A1F2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        // Count
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
          child: Text(
            '${list.length} repositorio${list.length == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),

        // Grid
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text('No se encontraron repositorios', style: TextStyle(color: Colors.white38)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final item = list[i];
                    final installed = _isInstalled(item.repo);
                    final icon = _iconCache[item.repo];
                    return _CommunityCard(
                      item: item,
                      iconUrl: icon,
                      installed: installed,
                      onInstall: () => _install(item),
                      onUninstall: () => _uninstall(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CommunityCard extends StatefulWidget {
  final CommunityRepoItem item;
  final String? iconUrl;
  final bool installed;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;

  const _CommunityCard({
    required this.item,
    required this.iconUrl,
    required this.installed,
    required this.onInstall,
    required this.onUninstall,
  });

  @override
  State<_CommunityCard> createState() => _CommunityCardState();
}

class _CommunityCardState extends State<_CommunityCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hover ? _accent.withValues(alpha: 0.5) : _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen arriba
            Expanded(
              child: widget.iconUrl != null && widget.iconUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.iconUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _iconPlaceholder(),
                    )
                  : _iconPlaceholder(),
            ),
            // Título + botón
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.installed)
                    OutlinedButton(
                      onPressed: widget.onUninstall,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      child: const Text('Desinstalar'),
                    )
                  else
                    FilledButton(
                      onPressed: widget.onInstall,
                      style: FilledButton.styleFrom(backgroundColor: _accent),
                      child: const Text('Instalar'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconPlaceholder() {
    return Container(
      color: const Color(0xFF12151C),
      child: const Center(child: Icon(Icons.extension_rounded, color: Colors.white24, size: 40)),
    );
  }
}
