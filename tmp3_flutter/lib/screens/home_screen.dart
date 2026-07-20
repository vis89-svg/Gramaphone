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
                    );
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
                    return _albumCard(
                      x['collectionName'] as String,
                      x['artistName'] as String,
                      x['artworkUrl100'] as String? ?? '',
                      collectionId: x['collectionId']?.toString(),
                    );
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

  Widget _recentCard(String title, String artist) {
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
        ],
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

  Widget _albumCard(String name, String artist, String art, {String? collectionId}) {
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Tmp3App.elev,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.album, color: Tmp3App.txt3),
          ),
          const SizedBox(height: 8),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Tmp3App.txt, fontWeight: FontWeight.w600)),
          Text(artist,
              style: const TextStyle(color: Tmp3App.txt3, fontSize: 10)),
          TextButton(
            onPressed: () => _showAlbumTracks(name, artist, collectionId: collectionId),
            child: const Text('View Tracks',
                style: TextStyle(color: Tmp3App.green, fontSize: 10)),
          ),
        ],
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

  void _showAlbumTracks(String album, String artist, {String? collectionId}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Tmp3App.bg,
      builder: (_) => _TrackListSheet(
        title: album,
        future: ItunesService.getAlbumTracks(album, artist, collectionId: collectionId),
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
