import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/app_state.dart';
import '../services/database_service.dart';
import '../services/recommendation_service.dart';
import '../widgets/artwork.dart';
import '../app.dart';

class MixScreen extends StatefulWidget {
  final String artist;
  final List<String>? clusterArtists;
  final Track? seedTrack;

  const MixScreen({super.key, required this.artist, this.clusterArtists, this.seedTrack});

  bool get isRadio => clusterArtists == null;

  @override
  State<MixScreen> createState() => _MixScreenState();
}

class _MixScreenState extends State<MixScreen> {
  List<Track> _songs = [];
  bool _loading = true;
  final Set<String> _sessionHidden = {};
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _title => widget.isRadio ? '${widget.artist} Radio' : '${widget.artist} Mix';

  Future<void> _load() async {
    try {
      var state = context.read<AppState>();
      var yt = state.ytDlp;
      var pid = state.profileId;

      // For cluster mode (For You), keep existing behavior
      if (widget.clusterArtists != null && widget.clusterArtists!.length > 1) {
        List<Track> all = [];
        Set<String> seen = {};
        for (var a in widget.clusterArtists!) {
          var results = await yt.searchAudio(a, limit: 10);
          for (var t in results) {
            if (t.duration > 30 && t.duration < 600 && seen.add(t.dbKey)) {
              all.add(t);
            }
          }
        }
        if (all.isNotEmpty) {
          var firstId = all.first.youtubeId;
          if (firstId != null && firstId.isNotEmpty) {
            var related = await yt.getRelated(firstId, limit: 15);
            for (var r in related) {
              if (r.duration > 30 && r.duration < 600 && seen.add(r.dbKey)) {
                all.add(r);
              }
            }
          }
        }
        all.shuffle();
        if (mounted) setState(() { _songs = all.take(40).toList(); _loading = false; });
        return;
      }

      // ── Radio mode: 50-track buffer with drift ──────────────────────
      var seedArtist = widget.artist;

      // Phase 1: seed artist's top tracks (topic + general search for variety)
      var topic = await yt.searchAudio(seedArtist, limit: 20);
      var hits = await yt.search(seedArtist, limit: 10);
      var seedTracks = [
        ...topic,
        ...hits,
      ].where((t) => t.duration > 30 && t.duration < 600).toList();
      var seenSeed = <String>{};
      var topHits = <Track>[];
      for (var t in seedTracks) {
        if (seenSeed.add(t.dbKey)) topHits.add(t);
      }

      // Place 2-3 signature tracks at the very start to anchor the radio
      var rng = Random();
      var anchorCount = topHits.length >= 3 ? 3 : (topHits.length >= 2 ? 2 : 1);
      var anchor = topHits.take(anchorCount).toList();
      anchor.shuffle(rng);

      var allTracks = [...anchor];
      var seen = <String>{};
      for (var t in anchor) { seen.add(t.dbKey); }

      // Remaining seed tracks go into the pool
      var remainingSeed = <Track>[];
      for (var t in topHits.skip(anchorCount)) {
        if (seen.add(t.dbKey)) remainingSeed.add(t);
      }

      // Get related from first video
      List<Track> related = [];
      var firstId = topHits.first.youtubeId ?? (topHits.length > 1 ? topHits.last.youtubeId : null);
      if (firstId != null && firstId.isNotEmpty) {
        var rel = await yt.getRelated(firstId, limit: 30);
        related = rel.where((t) => t.duration > 30 && t.duration < 600).toList();
      }

      // Phase 2: interleave remaining seed + related (tight but expanding)
      int p = 0, r = 0;
      while (allTracks.length < 25) {
        if (p < remainingSeed.length) {
          if (seen.add(remainingSeed[p].dbKey)) allTracks.add(remainingSeed[p]);
          p++;
        }
        for (var i = 0; i < 2 && r < related.length && allTracks.length < 25; i++, r++) {
          if (seen.add(related[r].dbKey)) allTracks.add(related[r]);
        }
        if (p >= remainingSeed.length && r >= related.length) break;
      }

      // Phase 3: genre-similar artists from affinity (wider)
      if (pid != null) {
        var affs = await DatabaseService.getAffinities(pid, limit: 8);
        var similarArtists = affs
            .map((a) => a['artist_name'] as String)
            .where((a) => a != seedArtist)
            .toList();
        similarArtists.shuffle(rng);
        for (var a in similarArtists.take(4)) {
          var results = await yt.searchAudio(a, limit: 5);
          for (var t in results) {
            if (t.duration > 30 && t.duration < 600 && seen.add(t.dbKey)) {
              allTracks.add(t);
              if (allTracks.length >= 45) break;
            }
          }
          if (allTracks.length >= 45) break;
        }
      }

      // Phase 4: fill up to 50 with remaining related + remaining seed
      while (allTracks.length < 50) {
        if (r < related.length) {
          if (seen.add(related[r].dbKey)) allTracks.add(related[r]);
          r++;
        } else if (p < remainingSeed.length) {
          if (seen.add(remainingSeed[p].dbKey)) allTracks.add(remainingSeed[p]);
          p++;
        } else {
          break;
        }
      }

      // Shuffle everything after the anchor tracks for variety
      var afterAnchor = allTracks.skip(anchorCount).toList();
      afterAnchor.shuffle(rng);
      allTracks = [...allTracks.take(anchorCount), ...afterAnchor];
      if (mounted) setState(() { _songs = allTracks; _loading = false; });
    } catch (e) {
      debugPrint('[MIX] load error: $e');
      if (mounted) setState(() { _songs = []; _loading = false; });
    }
  }

  Future<void> _saveAsPlaylist() async {
    var pid = context.read<AppState>().profileId;
    if (pid == null || _songs.isEmpty) return;
    var plid = await DatabaseService.createPlaylist(pid, _title, 'radio');
    for (var t in _songs) {
      await DatabaseService.addPlaylistTrack(plid, t);
    }
    if (mounted) setState(() => _saved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved "${_title}" to your playlists',
              style: const TextStyle(color: Tmp3App.txt)),
          backgroundColor: Tmp3App.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _hideTrack(Track t) async {
    var pid = context.read<AppState>().profileId;
    if (pid != null) {
      await RecommendationService.addNegativeFeedback(pid, 'radio', t.dbKey, t.title);
    }
    setState(() {
      _sessionHidden.add(t.dbKey);
      _songs.removeWhere((s) => s.dbKey == t.dbKey);
    });
  }

  void _playAll(int startIndex) {
    var state = context.read<AppState>();
    var playable = _songs.where((t) => !_sessionHidden.contains(t.dbKey)).toList();
    if (playable.isEmpty) return;
    state.clearQueue();
    var idx = startIndex.clamp(0, playable.length - 1);
    state.playNow(playable[idx]);
    for (var j = 0; j < playable.length; j++) {
      if (j != idx) state.enqueue(playable[j]);
    }
  }

  @override
  Widget build(BuildContext context) {
    var isRadio = widget.isRadio;
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
                        child: Icon(
                          isRadio ? Icons.radio_rounded : Icons.music_note,
                          color: Tmp3App.green, size: 40),
                      ),
                      const SizedBox(height: 12),
                      Text(_title,
                          style: const TextStyle(
                              color: Tmp3App.txt,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      if (_songs.isNotEmpty)
                        Text('${_songs.length} songs',
                            style: const TextStyle(color: Tmp3App.txt3, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            title: Text(_title,
                style: const TextStyle(color: Tmp3App.txt, fontSize: 18)),
            actions: [
              if (isRadio && _songs.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _saved ? Icons.check : Icons.bookmark_border,
                    color: _saved ? Tmp3App.green : Tmp3App.txt3,
                  ),
                  tooltip: 'Save Radio',
                  onPressed: _saved ? null : _saveAsPlaylist,
                ),
              if (isRadio && _songs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Tmp3App.txt3),
                  tooltip: 'Refresh Station',
                  onPressed: () {
                    setState(() { _songs = []; _loading = true; });
                    _load();
                  },
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: _loading
                ? const SizedBox(
                    height: 200,
                    child: Center(
                        child: CircularProgressIndicator(color: Tmp3App.green)))
                : _songs.isEmpty
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
    var playable = _songs.where((t) => !_sessionHidden.contains(t.dbKey)).toList();
    if (playable.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('All tracks hidden. Refresh to get new ones.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Tmp3App.txt3, fontSize: 14)),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _playAll(0),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(widget.isRadio ? 'Start Radio' : 'Play All'),
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
        if (widget.isRadio)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.autorenew, color: Tmp3App.txt3, size: 14),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Infinite — new tracks added as you listen',
                      style: TextStyle(color: Tmp3App.txt3, fontSize: 11)),
                ),
              ],
            ),
          ),
        for (var i = 0; i < _songs.length; i++)
          if (!_sessionHidden.contains(_songs[i].dbKey))
            _trackTile(i),
      ],
    );
  }

  Widget _trackTile(int i) {
    var t = _songs[i];
    var displayArtist = t.artist.isNotEmpty ? t.artist : 'Unknown';
    return ListTile(
      leading: Artwork(t.effectiveArtworkUrl, size: 36, borderRadius: 8),
      title: Text(t.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Tmp3App.txt,
              fontWeight: FontWeight.w400,
              fontSize: 14)),
      subtitle: Row(
        children: [
          Text(displayArtist,
              style: const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
          if (t.duration > 0)
            Text(' · ${t.durationDisplay}',
                style: const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isRadio)
            IconButton(
              icon: const Icon(Icons.do_not_disturb_alt_outlined,
                  color: Tmp3App.txt3, size: 18),
              tooltip: 'Not interested',
              onPressed: () => _hideTrack(t),
            ),
          IconButton(
            icon: const Icon(Icons.play_circle_outline,
                color: Tmp3App.green, size: 24),
            onPressed: () => _playAll(i),
          ),
        ],
      ),
      onTap: () => _playAll(i),
    );
  }
}
