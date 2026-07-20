import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import '../services/itunes_service.dart';
import '../app.dart';

enum SearchFilter { all, songs, artists, albums }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Track> _songResults = [];
  List<Map<String, dynamic>> _artistResults = [];
  List<Map<String, dynamic>> _albumResults = [];
  bool _loading = false;
  Set<String> _favArtists = {};
  Set<String> _affArtists = {};
  SearchFilter _filter = SearchFilter.all;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _loading = true);

    var state = context.read<AppState>();
    var pid = state.profileId;
    if (pid != null) {
      _favArtists = state.profileArtists.toSet();
      var affs = await DatabaseService.getAffinities(pid, limit: 20);
      _affArtists = affs.map((r) => r['artist_name'] as String).toSet();
    }

    var songs = await ItunesService.searchSongs(q.trim(), limit: 15);
    var artists = await ItunesService.searchArtists(q.trim(), limit: 8);
    var albums = await ItunesService.searchAlbums(q.trim(), limit: 8);

    songs.sort((a, b) {
      var sa = _personalScore(a);
      var sb = _personalScore(b);
      return sb.compareTo(sa);
    });

    setState(() {
      _songResults = songs;
      _artistResults = artists;
      _albumResults = albums;
      _loading = false;
    });
  }

  double _personalScore(Track t) {
    double s = 0;
    if (_favArtists.contains(t.artist)) s += 10;
    if (_affArtists.contains(t.artist)) s += 5;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    var hasResults =
        _songResults.isNotEmpty || _artistResults.isNotEmpty || _albumResults.isNotEmpty;

    return Scaffold(
      backgroundColor: Tmp3App.bg,
      appBar: AppBar(
        backgroundColor: Tmp3App.bg,
        title: TextField(
          controller: _ctrl,
          style: const TextStyle(color: Tmp3App.txt),
          decoration: InputDecoration(
            hintText: 'Search songs, artists, albums...',
            hintStyle: TextStyle(color: Tmp3App.txt3),
            filled: true,
            fillColor: Tmp3App.card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.search, color: Tmp3App.txt3),
          ),
          onSubmitted: _search,
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Tmp3App.green))
          : !hasResults
              ? const Center(
                  child: Text('Search for music',
                      style: TextStyle(color: Tmp3App.txt3)))
              : Column(
                  children: [
                    _buildFilterChips(),
                    Expanded(child: _buildResults()),
                  ],
                ),
    );
  }

  Widget _buildFilterChips() {
    var filters = SearchFilter.values;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          var selected = _filter == f;
          var count = f == SearchFilter.all
              ? _songResults.length + _artistResults.length + _albumResults.length
              : f == SearchFilter.songs
                  ? _songResults.length
                  : f == SearchFilter.artists
                      ? _artistResults.length
                      : _albumResults.length;
          if (f != SearchFilter.all && count == 0) return const SizedBox.shrink();
          var label = f == SearchFilter.all
              ? 'All'
              : f == SearchFilter.songs
                  ? 'Songs'
                  : f == SearchFilter.artists
                      ? 'Artists'
                      : 'Albums';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$label ($count)'),
              selected: selected,
              selectedColor: Tmp3App.green.withValues(alpha: 0.3),
              backgroundColor: Tmp3App.card,
              labelStyle: TextStyle(
                color: selected ? Tmp3App.green : Tmp3App.txt3,
                fontSize: 12,
              ),
              side: BorderSide(
                color: selected ? Tmp3App.green : Tmp3App.card,
              ),
              onSelected: (_) => setState(() => _filter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResults() {
    if (_filter == SearchFilter.artists) return _buildArtistList();
    if (_filter == SearchFilter.albums) return _buildAlbumList();
    if (_filter == SearchFilter.songs) return _buildSongList();
    return _buildAllResults();
  }

  Widget _buildAllResults() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (_artistResults.isNotEmpty) ...[
          _sectionHeader('Artists'),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _artistResults.length,
              itemBuilder: (_, i) => _artistCard(_artistResults[i]),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_albumResults.isNotEmpty) ...[
          _sectionHeader('Albums'),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _albumResults.length,
              itemBuilder: (_, i) => _albumCard(_albumResults[i]),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_songResults.isNotEmpty) ...[
          _sectionHeader('Songs'),
          ..._songResults.map((t) => _songRow(t)),
        ],
      ],
    );
  }

  Widget _buildSongList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _songResults.map((t) => _songRow(t)).toList(),
    );
  }

  Widget _buildArtistList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _artistResults.map((a) => _artistRow(a)).toList(),
    );
  }

  Widget _buildAlbumList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _albumResults.map((a) => _albumRow(a)).toList(),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              color: Tmp3App.txt,
              fontSize: 16,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _artistCard(Map<String, dynamic> x) {
    var name = x['artistName'] as String;
    var genre = x['primaryGenreName'] as String? ?? '';
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
                style: const TextStyle(color: Tmp3App.txt, fontSize: 20)),
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

  Widget _albumCard(Map<String, dynamic> x) {
    var name = x['collectionName'] as String? ?? '';
    var artist = x['artistName'] as String? ?? '';
    var art = x['artworkUrl100'] as String? ?? '';
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
            child: art.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(art, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.album, color: Tmp3App.txt3)),
                  )
                : const Icon(Icons.album, color: Tmp3App.txt3),
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
            onPressed: () => _showAlbumTracks(name, artist),
            child: const Text('View Tracks',
                style: TextStyle(color: Tmp3App.green, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _artistRow(Map<String, dynamic> x) {
    var name = x['artistName'] as String;
    var genre = x['primaryGenreName'] as String? ?? '';
    var isFav = _favArtists.contains(name);
    return InkWell(
      onTap: () => _showArtistSongs(name),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Tmp3App.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Tmp3App.elev,
              child: Text(name[0].toUpperCase(),
                  style: const TextStyle(color: Tmp3App.txt, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Tmp3App.txt,
                              fontWeight: FontWeight.w600)),
                      if (isFav)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.star,
                              color: Tmp3App.green, size: 14),
                        ),
                    ],
                  ),
                  Text(genre,
                      style: const TextStyle(
                          color: Tmp3App.txt3, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Tmp3App.txt3),
          ],
        ),
      ),
    );
  }

  Widget _albumRow(Map<String, dynamic> x) {
    var name = x['collectionName'] as String? ?? '';
    var artist = x['artistName'] as String? ?? '';
    var art = x['artworkUrl100'] as String? ?? '';
    return InkWell(
      onTap: () => _showAlbumTracks(name, artist),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Tmp3App.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Tmp3App.elev,
                borderRadius: BorderRadius.circular(6),
              ),
              child: art.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(art, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.album, color: Tmp3App.txt3)),
                    )
                  : const Icon(Icons.album, color: Tmp3App.txt3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Tmp3App.txt,
                          fontWeight: FontWeight.w600)),
                  Text(artist,
                      style: const TextStyle(
                          color: Tmp3App.txt3, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Tmp3App.txt3),
          ],
        ),
      ),
    );
  }

  Widget _songRow(Track t) {
    var isFav = _favArtists.contains(t.artist);
    var score = _personalScore(t);
    return InkWell(
      onTap: () => context.read<AppState>().playNow(t),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: score > 0
              ? Tmp3App.card.withValues(alpha: 0.9)
              : Tmp3App.card,
          borderRadius: BorderRadius.circular(8),
          border: score > 0
              ? Border.all(color: Tmp3App.green.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Tmp3App.elev,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: isFav
                    ? const Icon(Icons.favorite,
                        color: Tmp3App.green, size: 20)
                    : const Icon(Icons.music_note,
                        color: Tmp3App.txt3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Tmp3App.txt,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (isFav)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.star,
                              color: Tmp3App.green, size: 14),
                        ),
                    ],
                  ),
                  Text(t.artist,
                      style: const TextStyle(
                          color: Tmp3App.txt3, fontSize: 12)),
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

  void _showAlbumTracks(String album, String artist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Tmp3App.bg,
      builder: (_) => _TrackListSheet(
        title: album,
        future: ItunesService.getAlbumTracks(album, artist),
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
