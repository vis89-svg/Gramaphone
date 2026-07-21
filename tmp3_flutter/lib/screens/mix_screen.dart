import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/app_state.dart';
import '../app.dart';

class MixScreen extends StatefulWidget {
  final String artist;

  const MixScreen({super.key, required this.artist});

  @override
  State<MixScreen> createState() => _MixScreenState();
}

class _MixScreenState extends State<MixScreen> {
  List<Track>? _songs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var yt = context.read<AppState>().ytDlp;
    var tracks = await yt.search(widget.artist, limit: 50);
    var songs = tracks.where((t) => t.duration > 30 && t.duration < 600).take(15).toList();
    if (mounted) setState(() { _songs = songs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tmp3App.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Tmp3App.side,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Tmp3App.card, Tmp3App.bg],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Tmp3App.elev,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(Icons.music_note, color: Tmp3App.green, size: 40),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.artist,
                          style: const TextStyle(
                              color: Tmp3App.txt,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      if (_songs != null)
                        Text('${_songs!.length} songs',
                            style: const TextStyle(color: Tmp3App.txt3, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            title: Text(widget.artist,
                style: const TextStyle(color: Tmp3App.txt, fontSize: 18)),
          ),
          SliverToBoxAdapter(
            child: _loading
                ? const SizedBox(
                    height: 200,
                    child: Center(
                        child: CircularProgressIndicator(color: Tmp3App.green)))
                : _songs == null || _songs!.isEmpty
                    ? SizedBox(
                        height: 200,
                        child: Center(
                            child: Text('No songs found',
                                style: TextStyle(color: Tmp3App.txt3))))
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _playAll(0),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Tmp3App.green,
                foregroundColor: Tmp3App.bg,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        ...List.generate(_songs!.length, (i) {
          var t = _songs![i];
          return ListTile(
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Tmp3App.elev,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${i + 1}',
                  style: const TextStyle(color: Tmp3App.txt3, fontSize: 13)),
            ),
            title: Text(t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Tmp3App.txt, fontSize: 14)),
            subtitle: Text(t.artist,
                style: const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_outline,
                  color: Tmp3App.green, size: 24),
              onPressed: () => _playAll(i),
            ),
            onTap: () => _playAll(i),
          );
        }),
      ],
    );
  }

  void _playAll(int startIndex) {
    var state = context.read<AppState>();
    state.clearQueue();
    state.playNow(_songs![startIndex]);
    for (var j = 0; j < _songs!.length; j++) {
      if (j != startIndex) state.enqueue(_songs![j]);
    }
  }
}
