import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/track.dart';
import '../services/itunes_service.dart';
import '../app.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var state = context.read<AppState>();
    if (state.recentlyPlayed.isEmpty && state.heavyRotation.isEmpty && state.profile.loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => state.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    var state = context.watch<AppState>();
    var sug = state.suggestions;

    return Scaffold(
      backgroundColor: Tmp3App.bg,
      appBar: AppBar(
        backgroundColor: Tmp3App.bg,
        title: const Text('tmp3',
            style: TextStyle(
                color: Tmp3App.green,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              state.smartShuffle ? Icons.shuffle_on : Icons.shuffle,
              color: state.smartShuffle ? Tmp3App.green : Tmp3App.txt3,
            ),
            onPressed: () => state.toggleSmartShuffle(),
            tooltip: 'Smart Shuffle',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Tmp3App.txt3),
            onPressed: () => _showAiPlaylistDialog(context),
            tooltip: 'AI Playlist',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.recentlyPlayed.isNotEmpty) ...[
              _sectionHeader('Recently Played'),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.recentlyPlayed.length,
                  itemBuilder: (_, i) {
                    var h = state.recentlyPlayed[i];
                    return _recentCard(
                      h['title'] as String,
                      h['artist'] as String,
                      () {
                        var t = Track(title: h['title'], artist: h['artist']);
                        state.playNow(t);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (state.heavyRotation.isNotEmpty) ...[
              _sectionHeader('Heavy Rotation'),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.heavyRotation.length,
                  itemBuilder: (_, i) {
                    var h = state.heavyRotation[i];
                    return _recentCard(
                      h['title'] as String,
                      h['artist'] as String,
                      () {
                        var t = Track(title: h['title'], artist: h['artist']);
                        state.playNow(t);
                      },
                      subtitle: '${h['play_count']} plays',
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (state.dailyMixes.isNotEmpty) ...[
              _sectionHeader('Daily Mixes'),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.dailyMixes.length,
                  itemBuilder: (_, i) {
                    var m = state.dailyMixes[i];
                    return _mixCard(m, () => _showMixSheet(m.artist));
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (state.newReleases.isNotEmpty) ...[
              _sectionHeader('New Releases'),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.newReleases.length,
                  itemBuilder: (_, i) {
                    var n = state.newReleases[i];
                    return _mixCard(n, () => _showMixSheet(n.artist));
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (sug['artists'] != null && (sug['artists'] as List).isNotEmpty) ...[
              _sectionHeader('Suggested Artists'),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (sug['artists'] as List).length,
                  itemBuilder: (_, i) {
                    var x = (sug['artists'] as List)[i];
                    return _artistCard(
                      x['artistName'] as String,
                      x['primaryGenreName'] as String? ?? '',
                      x['artworkUrl100'] as String? ?? '',
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (sug['albums'] != null && (sug['albums'] as List).isNotEmpty) ...[
              _sectionHeader('Suggested Albums'),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (sug['albums'] as List).length,
                  itemBuilder: (_, i) {
                    var x = (sug['albums'] as List)[i];
                    var t = Track(
                      title: x['title'] as String? ?? '',
                      artist: x['artist'] as String? ?? '',
                      artworkUrl: x['artworkUrl'] as String? ?? '',
                      youtubeId: x['youtubeId'] as String?,
                    );
                    return _albumCard(t);
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (sug['songs'] != null && (sug['songs'] as List).isNotEmpty) ...[
              _sectionHeader('Suggested Songs'),
              ...((sug['songs'] as List).take(12)).map((s) {
                var t = s as Track;
                return _songRow(t);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: const TextStyle(
              color: Tmp3App.txt,
              fontSize: 18,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _recentCard(String title, String artist, VoidCallback onTap, {String? subtitle}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Tmp3App.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, color: Tmp3App.txt3, size: 28),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Tmp3App.txt, fontWeight: FontWeight.w600)),
            ),
            Text(artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
            if (subtitle != null)
              Text(subtitle,
                  style: const TextStyle(color: Tmp3App.green, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _mixCard(Track t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Tmp3App.card, Tmp3App.green.withValues(alpha: 0.2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(t.collectionId?.startsWith('new_') == true
                ? Icons.new_releases
                : Icons.queue_music_rounded,
                color: Tmp3App.green, size: 28),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(t.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Tmp3App.txt, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artistCard(String name, String genre, String art) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Tmp3App.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Tmp3App.elev,
            child: Text(name[0].toUpperCase(),
                style: const TextStyle(
                    color: Tmp3App.txt, fontSize: 20)),
          ),
          const SizedBox(height: 8),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Tmp3App.txt, fontWeight: FontWeight.w600)),
          Text(genre,
              style: const TextStyle(color: Tmp3App.txt3, fontSize: 10)),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _showArtistSongs(name),
            child: const Text('View Songs',
                style: TextStyle(color: Tmp3App.green, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _albumCard(Track t) {
    return GestureDetector(
      onTap: () => context.read<AppState>().playNow(t),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Tmp3App.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Tmp3App.elev,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.music_note, color: Tmp3App.txt3),
            ),
            const SizedBox(height: 8),
            Text(t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Tmp3App.txt, fontWeight: FontWeight.w600)),
            Text(t.artist,
                style: const TextStyle(color: Tmp3App.txt3, fontSize: 10)),
            const Icon(Icons.play_circle_outline,
                color: Tmp3App.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _songRow(Track t) {
    return InkWell(
      onTap: () => context.read<AppState>().playNow(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Tmp3App.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Tmp3App.elev,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.music_note, color: Tmp3App.txt3),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Tmp3App.txt3, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_outline,
                color: Tmp3App.green, size: 28),
          ],
        ),
      ),
    );
  }

  void _showAiPlaylistDialog(BuildContext context) {
    var controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Tmp3App.side,
        title: const Text('AI Playlist',
            style: TextStyle(color: Tmp3App.txt)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Tmp3App.txt),
          decoration: const InputDecoration(
            hintText: 'Describe a playlist...',
            hintStyle: TextStyle(color: Tmp3App.txt3),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Tmp3App.txt3),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Tmp3App.green),
            ),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              context.read<AppState>().createAiPlaylist(v.trim());
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Tmp3App.txt3)),
          ),
          TextButton(
            onPressed: () {
              var v = controller.text.trim();
              if (v.isNotEmpty) {
                context.read<AppState>().createAiPlaylist(v);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create',
                style: TextStyle(color: Tmp3App.green)),
          ),
        ],
      ),
    );
  }

  void _showMixSheet(String artist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Tmp3App.bg,
      isScrollControlled: true,
      builder: (ctx) {
        var state = context.read<AppState>();
        return FutureBuilder<List<Track>>(
          future: state.ytDlp.search(artist, limit: 20).then((tracks) =>
            tracks.where((t) => t.duration > 30 && t.duration < 600).take(15).toList()),
          builder: (_, snap) {
            if (!snap.hasData) {
              return SizedBox(
                height: 300,
                child: const Center(child: CircularProgressIndicator(color: Tmp3App.green)),
              );
            }
            var songs = snap.data!;
            if (songs.isEmpty) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text('No songs found for $artist',
                      style: const TextStyle(color: Tmp3App.txt3)),
                ),
              );
            }
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('$artist Mix',
                      style: const TextStyle(
                          color: Tmp3App.txt,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${songs.length} songs',
                      style: const TextStyle(color: Tmp3App.txt3, fontSize: 12)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: songs.length,
                      itemBuilder: (_, i) {
                        var t = songs[i];
                        return ListTile(
                          leading: Text('${i + 1}',
                              style: const TextStyle(color: Tmp3App.txt3)),
                          title: Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Tmp3App.txt)),
                          subtitle: Text(t.artist,
                              style: const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
                          trailing: const Icon(Icons.play_circle_outline,
                              color: Tmp3App.green, size: 24),
                          onTap: () {
                            state.clearQueue();
                            state.playNow(songs[i]);
                            for (var j = 0; j < songs.length; j++) {
                              if (j != i) state.enqueue(songs[j]);
                            }
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showArtistSongs(String artist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Tmp3App.bg,
      builder: (_) => _TrackListSheet(
        title: artist,
        future: ItunesService.getArtistTopSongs(artist),
      ),
    );
  }

}

class _TrackListSheet extends StatelessWidget {
  final String title;
  final Future<List<Track>> future;

  const _TrackListSheet({required this.title, required this.future});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(
                  color: Tmp3App.txt,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Track>>(
              future: future,
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: Tmp3App.green));
                }
                var tracks = snap.data!;
                if (tracks.isEmpty) {
                  return const Center(
                      child: Text('No tracks found',
                          style: TextStyle(color: Tmp3App.txt3)));
                }
                return ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (_, i) {
                    var t = tracks[i];
                    return ListTile(
                      leading: Text('${i + 1}',
                          style: const TextStyle(color: Tmp3App.txt3)),
                      title: Text(t.title,
                          style: const TextStyle(color: Tmp3App.txt)),
                      subtitle: Text(t.album,
                          style: const TextStyle(color: Tmp3App.txt3)),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow,
                            color: Tmp3App.green),
                        onPressed: () {
                          context.read<AppState>().playNow(t);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
