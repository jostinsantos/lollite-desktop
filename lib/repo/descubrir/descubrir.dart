import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/repo_manifest.dart';
import '../../../data/services/content_service.dart';
import '../contenido/contenido.dart';
import '../home/catalogo_individual.dart';

const _card = Color(0xFF161A22);
const _border = Color(0xFF1E2430);
const _accent = Color(0xFFE50914);

class _RepoFilter {
  final String id;
  final String label;
  final List<({String id, String label})> options;
  String? selectedId;

  _RepoFilter({required this.id, required this.label, required this.options, this.selectedId});

  String get selectedLabel {
    if (selectedId == null || selectedId!.isEmpty) return label;
    for (final o in options) {
      if (o.id == selectedId) return o.label;
    }
    return label;
  }
}

/// Descubrir — misma lógica de filtros que TV.
class DiscoverPage extends StatefulWidget {
  final InstalledRepo repo;
  const DiscoverPage({super.key, required this.repo});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _scroll = ScrollController();
  final List<_RepoFilter> _filters = [];
  List<ContentItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  Future<void> _bootstrap() async {
    await _loadFilterDefs();
    await _reload();
  }

  Map<String, dynamic> get _filterMap {
    final m = <String, dynamic>{};
    for (final f in _filters) {
      if (f.selectedId != null && f.selectedId!.isNotEmpty) {
        m[f.id] = f.selectedId;
      }
    }
    return m;
  }

  Future<void> _loadFilterDefs() async {
    final raw = await ContentService.instance.getDiscoverFilters(
      widget.repo,
      filters: _filterMap,
    );
    final parsed = <_RepoFilter>[];
    for (final f in raw.take(3)) {
      final id = (f['id'] ?? f['key'] ?? '').toString();
      final label = (f['label'] ?? f['name'] ?? id).toString();
      final optsRaw = f['options'] ?? f['values'] ?? f['items'];
      final options = <({String id, String label})>[];
      if (optsRaw is List) {
        for (final o in optsRaw) {
          if (o is Map) {
            final oid = (o['id'] ?? o['value'] ?? o['key'] ?? '').toString();
            final olab = (o['label'] ?? o['name'] ?? oid).toString();
            if (oid.isNotEmpty) options.add((id: oid, label: olab));
          } else if (o != null) {
            final s = o.toString();
            options.add((id: s, label: s));
          }
        }
      }
      if (options.isEmpty && id.isNotEmpty) {
        options.add((id: id, label: label));
      }
      if (id.isNotEmpty) {
        parsed.add(_RepoFilter(
          id: id,
          label: label,
          options: options,
          selectedId: options.isNotEmpty ? options.first.id : null,
        ));
      }
    }
    if (parsed.isEmpty && raw.isNotEmpty) {
      final options = raw.map((f) {
        final id = (f['id'] ?? '').toString();
        final label = (f['label'] ?? id).toString();
        return (id: id, label: label);
      }).where((e) => e.id.isNotEmpty).toList();
      if (options.isNotEmpty) {
        parsed.add(_RepoFilter(id: 'filter', label: 'Filtro', options: options, selectedId: options.first.id));
      }
    }
    for (final f in parsed) {
      final prev = _filters.where((x) => x.id == f.id).toList();
      if (prev.isNotEmpty && prev.first.selectedId != null) {
        final still = f.options.any((o) => o.id == prev.first.selectedId);
        if (still) f.selectedId = prev.first.selectedId;
      }
    }
    if (!mounted) return;
    setState(() {
      _filters..clear()..addAll(parsed);
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _items = [];
      _hasMore = true;
    });
    try {
      final result = await ContentService.instance.getDiscover(
        widget.repo,
        filters: _filterMap,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = _page + 1;
      final result = await ContentService.instance.getDiscover(
        widget.repo,
        filters: _filterMap,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _items = [..._items, ...result.items];
        _page = page;
        _hasMore = result.hasMore && result.items.isNotEmpty;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _pickFilter(_RepoFilter f) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(f.label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              ...f.options.map((o) {
                final active = o.id == f.selectedId;
                return ListTile(
                  title: Text(o.label, style: TextStyle(color: active ? _accent : Colors.white)),
                  trailing: active ? const Icon(Icons.check, color: _accent) : null,
                  onTap: () => Navigator.pop(ctx, o.id),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    if (selected != null && selected != f.selectedId) {
      setState(() => f.selectedId = selected);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filtros (selects) — igual que TV
        if (_filters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: _filters.map((f) {
                return ActionChip(
                  label: Text(f.selectedLabel),
                  avatar: const Icon(Icons.filter_list_rounded, size: 16, color: Colors.white70),
                  backgroundColor: _card,
                  side: const BorderSide(color: _border),
                  labelStyle: const TextStyle(color: Colors.white),
                  onPressed: () => _pickFilter(f),
                );
              }).toList(),
            ),
          ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _reload, child: const Text('Reintentar')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: _accent,
                      onRefresh: _reload,
                      child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No hay contenido', style: TextStyle(color: Colors.white38))),
                          ],
                        )
                      : GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: _scroll,
                          padding: const EdgeInsets.all(24),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.58,
                          ),
                          itemCount: _items.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= _items.length) {
                              return const Center(child: CircularProgressIndicator(color: _accent));
                            }
                            final item = _items[i];
                            return GestureDetector(
                              onTap: () {
                                if (item.type == 'catalog') {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => CatalogDetailPage(repo: widget.repo, catalogId: item.id, title: item.title),
                                  ));
                                  return;
                                }
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => DetailsPage(repo: widget.repo, itemId: item.id),
                                ));
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: item.poster != null && item.poster!.isNotEmpty
                                          ? CachedNetworkImage(imageUrl: item.poster!, fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Container(color: const Color(0xFF12151C)))
                                          : Container(color: const Color(0xFF12151C)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
        ),
      ],
    );
  }
}
