import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../app.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var state = context.watch<AppState>();
    var q = state.queue;

    return Scaffold(
      backgroundColor: Tmp3App.bg,
      appBar: AppBar(
        backgroundColor: Tmp3App.bg,
        title: const Text('Queue',
            style: TextStyle(color: Tmp3App.txt, fontWeight: FontWeight.bold)),
        actions: [
          if (q.isNotEmpty)
            TextButton(
              onPressed: () => state.clearQueue(),
              child: const Text('Clear',
                  style: TextStyle(color: Tmp3App.txt3)),
            ),
        ],
      ),
      body: q.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music_rounded,
                      color: Tmp3App.txt3, size: 64),
                  SizedBox(height: 16),
                  Text('Queue is empty',
                      style: TextStyle(
                          color: Tmp3App.txt3, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Play some songs to see them here',
                      style: TextStyle(color: Tmp3App.txt3)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: q.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('${q.length} songs',
                        style: const TextStyle(color: Tmp3App.txt3)),
                  );
                }
                var idx = i - 1;
                var t = q[idx];
                var isCurrent = idx == state.queueIndex;
                return Dismissible(
                  key: Key('queue_$idx'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => state.removeFromQueue(idx),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Tmp3App.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Tmp3App.green.withValues(alpha: 0.15)
                          : Tmp3App.card,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrent
                          ? Border.all(
                              color: Tmp3App.green.withValues(alpha: 0.5))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Tmp3App.green
                                : Tmp3App.elev,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: isCurrent
                                ? const Icon(Icons.play_arrow,
                                    color: Colors.black)
                                : Text('${idx + 1}',
                                    style: const TextStyle(
                                        color: Tmp3App.txt)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Tmp3App.txt,
                                      fontWeight: FontWeight.w600)),
                              Text(t.artist,
                                  style: const TextStyle(
                                      color: Tmp3App.txt3, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (idx != state.queueIndex)
                          IconButton(
                            icon: const Icon(Icons.play_arrow,
                                color: Tmp3App.green),
                            onPressed: () => state.playIndex(idx),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
