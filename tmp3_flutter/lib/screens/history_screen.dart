import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/track.dart';
import '../widgets/artwork.dart';
import '../app.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Tmp3App.bg,
      appBar: AppBar(
        backgroundColor: Tmp3App.bg,
        title: const Text('History',
            style: TextStyle(color: Tmp3App.txt, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: state.recentlyPlayed.isEmpty
          ? const Center(
              child: Text('No listening history yet',
                  style: TextStyle(color: Tmp3App.txt3)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.recentlyPlayed.length,
              itemBuilder: (_, i) {
                var h = state.recentlyPlayed[i];
                var title = h['title'] as String;
                var artist = h['artist'] as String;
                var art = h['artwork_url'] as String? ?? '';
                return InkWell(
                  onTap: () {
                    var t = Track(title: title, artist: artist);
                    context.read<AppState>().playNow(t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: Tmp3App.card,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Artwork(art, size: 40, borderRadius: 6),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Tmp3App.txt, fontWeight: FontWeight.w600)),
                              Text(artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Tmp3App.txt3, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_outline,
                            color: Tmp3App.green, size: 28),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
