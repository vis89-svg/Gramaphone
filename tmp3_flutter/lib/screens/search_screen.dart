import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import '../services/itunes_service.dart';
import '../services/innertube_service.dart' show AlbumInfo;
import 'artist_screen.dart';
import 'album_screen.dart';
import '../widgets/artwork.dart';
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
  List<AlbumInfo> _ytAlbumResults = [];
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
    var artists = ItunesService.deduplicateArtists(
        await ItunesService.searchArtists(q.trim(), limit: 12));
    var albums = await ItunesService.searchAlbums(q.trim(), limit: 8);
    var ytAlbums = await state.ytDlp.searchAlbums(q.trim(), limit: 6);

    songs.sort((a, b) {
      var sa = _personalScore(a);
      var sb = _personalScore(b);
      return sb.compareTo(sa);
    });

    setState(() {
      _songResults = songs;
      _artistResults = artists;
      _albumResults = albums;
      _ytAlbumResults = ytAlbums;
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
        _songResults.isNotEmpty || _artistResults.isNotEmpty || _albumResults.isNotEmpty || _ytAlbumResults.isNotEmpty;

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
        if (_ytAlbumResults.isNotEmpty) ...[
          _sectionHeader('YouTube Albums'),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _ytAlbumResults.length,
              itemBuilder: (_, i) => _ytAlbumCard(_ytAlbumResults[i]),
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ArtistScreen(artist: name))),
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
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AlbumScreen(
          albumTitle: name,
          artist: artist,
        ))),
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
          ],
        ),
      ),
    );
  }

  Widget _ytAlbumCard(AlbumInfo x) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AlbumScreen(
          albumTitle: x.title,
          artist: x.artist,
          browseId: x.browseId,
        ))),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Artwork(x.artworkUrl, size: 56, borderRadius: 8),
              ),
            ),
            const SizedBox(height: 8),
            Text(x.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Tmp3App.txt, fontWeight: FontWeight.w600)),
            Text(x.artist,
                style: const TextStyle(color: Tmp3App.txt3, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _artistRow(Map<String, dynamic> x) {
    var name = x['artistName'] as String;
    var genre = x['primaryGenreName'] as String? ?? '';
    var isFav = _favArtists.contains(name);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArtistScreen(artist: name))),
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
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AlbumScreen(
          albumTitle: name,
          artist: artist,
        ))),
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
            Artwork(t.effectiveArtworkUrl, size: 44, borderRadius: 6),
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
                  Row(
                    children: [
                      Text(t.artist,
                          style: const TextStyle(
                              color: Tmp3App.txt3, fontSize: 12)),
                      if (t.duration > 0)
                        Text(' · ${t.durationDisplay}',
                            style: const TextStyle(color: Tmp3App.txt3, fontSize: 12)),
                    ],
                  ),
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

}
