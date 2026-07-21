import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/app_state.dart';
import '../services/itunes_service.dart';
import '../app.dart';
import 'album_screen.dart';

class ArtistScreen extends StatefulWidget {
  final String artist;

  const ArtistScreen({super.key, required this.artist});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  List<Track>? _topSongs;
  List<Map<String, dynamic>>? _albums;
  List<Track>? _collabs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var yt = context.read<AppState>().ytDlp;
    var results = await Future.wait([
      yt.searchAudio(widget.artist, limit: 50),
      ItunesService.searchAlbums(widget.artist, limit: 10),
      yt.search('${widget.artist} feat', limit: 20),
    ]);
    if (!mounted) return;
    setState(() {
      _topSongs = (results[0] as List<Track>).where((t) => t.duration > 30 && t.duration < 3600).take(20).toList();
      _albums = results[1] as List<Map<String, dynamic>>;
      _collabs = (results[2] as List<Track>).where((t) => t.duration > 30 && t.duration < 3600).take(10).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tmp3App.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Tmp3App.green))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 180,
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
                              child: Icon(Icons.person, color: Tmp3App.green, size: 40),
                            ),
                            const SizedBox(height: 12),
                            Text(widget.artist,
                                style: const TextStyle(
                                    color: Tmp3App.txt, fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  title: Text(widget.artist,
                      style: const TextStyle(color: Tmp3App.txt, fontSize: 18)),
                ),
                if (_topSongs != null && _topSongs!.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Top Songs',
                              style: TextStyle(
                                  color: Tmp3App.txt, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                var state = context.read<AppState>();
                                state.clearQueue();
                                state.playNow(_topSongs!.first);
                                for (var j = 1; j < _topSongs!.length; j++) {
                                  state.enqueue(_topSongs![j]);
                                }
                              },
                              icon: const Icon(Icons.play_arrow_rounded, size: 16),
                              label: const Text('Play All', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Tmp3App.green,
                                foregroundColor: Tmp3App.bg,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_topSongs != null)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        var t = _topSongs![i];
                        return ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Tmp3App.elev,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${i + 1}',
                                style: const TextStyle(color: Tmp3App.txt3, fontSize: 12)),
                          ),
                          title: Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Tmp3App.txt, fontSize: 14)),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_circle_outline, color: Tmp3App.green, size: 22),
                            onPressed: () {
                              var state = context.read<AppState>();
                              state.clearQueue();
                              state.playNow(t);
                              for (var j = 0; j < _topSongs!.length; j++) {
                                if (j != i) state.enqueue(_topSongs![j]);
                              }
                            },
                          ),
                          onTap: () {
                            var state = context.read<AppState>();
                            state.clearQueue();
                            state.playNow(t);
                            for (var j = 0; j < _topSongs!.length; j++) {
                              if (j != i) state.enqueue(_topSongs![j]);
                            }
                          },
                        );
                      },
                      childCount: _topSongs!.length,
                    ),
                  ),
                if (_albums != null && _albums!.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Albums',
                          style: const TextStyle(
                              color: Tmp3App.txt, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _albums!.length,
                        itemBuilder: (_, i) {
                          var album = _albums![i];
                          var title = album['collectionName'] as String? ?? '';
                          var artUrl = album['artworkUrl100'] as String? ?? '';
                          var trackCount = album['trackCount'] as int? ?? 0;
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AlbumScreen(
                                albumTitle: title,
                                artist: widget.artist,
                              )),
                            ),
                            child: Container(
                              width: 130,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Tmp3App.card,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Tmp3App.elev,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: artUrl.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.network(artUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons.album,
                                                        color: Tmp3App.txt3, size: 24)),
                                          )
                                        : const Icon(Icons.album,
                                            color: Tmp3App.txt3, size: 24),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Tmp3App.txt, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                  if (trackCount > 0)
                                    Text('$trackCount tracks',
                                        style: const TextStyle(color: Tmp3App.txt3, fontSize: 9)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                if (_collabs != null && _collabs!.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Mixes & Collabs',
                          style: const TextStyle(
                              color: Tmp3App.txt, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        var t = _collabs![i];
                        return ListTile(
                          leading: Icon(Icons.merge_type, color: Tmp3App.txt3, size: 20),
                          title: Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Tmp3App.txt, fontSize: 14)),
                          subtitle: Text(t.artist,
                              style: const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_circle_outline, color: Tmp3App.green, size: 22),
                            onPressed: () => context.read<AppState>().playNow(t),
                          ),
                          onTap: () => context.read<AppState>().playNow(t),
                        );
                      },
                      childCount: _collabs!.length,
                    ),
                  ),
                ],
                SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }
}
