import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/app_state.dart';
import '../widgets/artwork.dart';
import '../app.dart';

class PlaylistScreen extends StatefulWidget {
  final int playlistId;
  final String playlistName;

  const PlaylistScreen({super.key, required this.playlistId, required this.playlistName});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Track>? _tracks;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var rows = await context.read<AppState>().library.database.getPlaylistTracks(widget.playlistId);
    var tracks = rows.map((r) => Track(
      title: r['title'] as String? ?? '',
      artist: r['artist'] as String? ?? '',
      album: r['album'] as String? ?? '',
      artworkUrl: r['artwork_url'] as String? ?? '',
    )).toList();
    if (mounted) setState(() { _tracks = tracks; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tmp3App.bg,
      appBar: AppBar(
        backgroundColor: Tmp3App.bg,
        title: Text(widget.playlistName,
            style: const TextStyle(color: Tmp3App.txt, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Tmp3App.green))
          : _tracks == null || _tracks!.isEmpty
              ? const Center(child: Text('No tracks', style: TextStyle(color: Tmp3App.txt3)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tracks!.length,
                  itemBuilder: (_, i) {
                    var t = _tracks![i];
                    return InkWell(
                      onTap: () => context.read<AppState>().playNow(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: Tmp3App.card,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Artwork(t.effectiveArtworkUrl, size: 40, borderRadius: 6),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Tmp3App.txt, fontWeight: FontWeight.w600)),
                                  Text(t.artist,
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
