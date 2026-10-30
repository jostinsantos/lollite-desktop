import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/download_item.dart';
import '../../data/services/download_service.dart';
import '../../launcher/home.dart';

/// Overlay flotante arriba-DERECHA. No se muestra en player ni en Descargas.
class DownloadProgressOverlay extends StatefulWidget {
  final Widget child;
  const DownloadProgressOverlay({super.key, required this.child});

  @override
  State<DownloadProgressOverlay> createState() =>
      _DownloadProgressOverlayState();
}

class _DownloadProgressOverlayState extends State<DownloadProgressOverlay> {
  final Map<String, DateTime> _justFinished = {};
  bool _collapsed = false;
  bool _dismissed = false;

  void _goDownloads() {
    LauncherNav.goToTab.value = 3; // pestaña Descargas del launcher
    try {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DownloadService>.value(
      value: DownloadService.instance,
      child: Consumer<DownloadService>(
        builder: (ctx, svc, _) {
          for (final item in svc.items) {
            if (item.status == DownloadStatus.completed &&
                item.updatedAt != null) {
              final age = DateTime.now().difference(item.updatedAt!);
              if (age.inSeconds < 45 &&
                  !_justFinished.containsKey(item.id)) {
                _justFinished[item.id] = item.updatedAt!;
                if (_dismissed) _dismissed = false;
              }
            }
          }
          _justFinished.removeWhere(
              (_, t) => DateTime.now().difference(t).inSeconds > 50);

          final downloading = svc.items
              .where((e) =>
                  e.status == DownloadStatus.downloading ||
                  e.status == DownloadStatus.converting ||
                  e.status == DownloadStatus.queued)
              .take(5)
              .toList();

          final finished = svc.items
              .where((e) =>
                  e.status == DownloadStatus.completed &&
                  _justFinished.containsKey(e.id))
              .take(2)
              .toList();

          final cards = <DownloadItem>[...downloading, ...finished];
          final hideRoute = svc.hideOverlay;

          return Stack(
            children: [
              widget.child,
              if (cards.isNotEmpty && !_dismissed && !hideRoute)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 10,
                  child: Material(
                    color: Colors.transparent,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.topRight,
                      child: _collapsed
                          ? _CollapsedChip(
                              count: cards.length,
                              onExpand: () =>
                                  setState(() => _collapsed = false),
                              onClose: () =>
                                  setState(() => _dismissed = true),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 6, 4, 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xF0141A22),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.download_rounded,
                                          size: 14, color: Color(0xFF7DD3FC)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${cards.length} descarga${cards.length == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11),
                                      ),
                                      InkWell(
                                        onTap: () =>
                                            setState(() => _collapsed = true),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(
                                              Icons.unfold_less_rounded,
                                              size: 16,
                                              color: Colors.white54),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () =>
                                            setState(() => _dismissed = true),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.close,
                                              size: 16, color: Colors.white54),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                for (final item in cards)
                                  _MiniDownloadCard(
                                    item: item,
                                    svc: svc,
                                    onOpenDownloads: _goDownloads,
                                  ),
                              ],
                            ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CollapsedChip extends StatelessWidget {
  final int count;
  final VoidCallback onExpand;
  final VoidCallback onClose;
  const _CollapsedChip({
    required this.count,
    required this.onExpand,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onExpand,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xF0141A22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.download_rounded,
                    color: Color(0xFF7DD3FC), size: 22),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: onClose,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xF0141A22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.close, size: 14, color: Colors.white54),
          ),
        ),
      ],
    );
  }
}

class _MiniDownloadCard extends StatelessWidget {
  final DownloadItem item;
  final DownloadService svc;
  final VoidCallback onOpenDownloads;

  const _MiniDownloadCard({
    required this.item,
    required this.svc,
    required this.onOpenDownloads,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = item.status == DownloadStatus.completed;
    final eta = isDone ? null : svc.etaLabel(item.id);
    final pct = (item.progress * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      width: 260,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xF0141A22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isDone
                    ? Icons.check_circle
                    : (item.status == DownloadStatus.converting
                        ? Icons.movie_creation_outlined
                        : Icons.download_rounded),
                size: 14,
                color: isDone
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF7DD3FC),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Text(
            item.repoName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          if (!isDone) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: item.progress.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.white12,
                color: item.status == DownloadStatus.converting
                    ? Colors.orangeAccent
                    : const Color(0xFF7DD3FC),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.status == DownloadStatus.converting
                      ? 'Convirtiendo a MKV…'
                      : item.status == DownloadStatus.queued
                          ? 'En cola'
                          : '$pct%',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                if (eta != null)
                  Text('~$eta',
                      style: const TextStyle(
                          color: Color(0xFF7DD3FC), fontSize: 10)),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 26,
              child: TextButton(
                onPressed: onOpenDownloads,
                style: TextButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  foregroundColor: const Color(0xFF4CAF50),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Ahora → Descargas',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
