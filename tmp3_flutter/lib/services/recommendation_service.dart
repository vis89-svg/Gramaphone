import 'dart:math';
import '../models/track.dart';
import 'database_service.dart';
import 'itunes_service.dart';
import 'ytdlp_service.dart';

class RecommendationService {
  static final Map<String, String?> _genreCache = {};

  static Future<String?> _getGenre(String artist) async {
    if (_genreCache.containsKey(artist)) return _genreCache[artist];
    var g = await ItunesService.getArtistGenre(artist);
    _genreCache[artist] = g;
    return g;
  }

  static List<String> _adjacentGenres(String genre) {
    var map = {
      'Pop': ['Indie Pop', 'Synth Pop', 'Dance Pop'],
      'Rock': ['Alternative Rock', 'Indie Rock', 'Hard Rock'],
      'Hip Hop/Rap': ['Trap', 'Conscious Rap', 'Cloud Rap'],
      'R&B/Soul': ['Neo Soul', 'Contemporary R&B', 'Funk'],
      'Electronic': ['House', 'Techno', 'Ambient'],
      'Country': ['Country Rock', 'Bluegrass', 'Americana'],
      'Metal': ['Thrash Metal', 'Death Metal', 'Doom Metal'],
      'Jazz': ['Fusion', 'Smooth Jazz', 'Bebop'],
      'Classical': ['Orchestral', 'Chamber', 'Minimalist'],
      'Folk': ['Indie Folk', 'Singer/Songwriter', 'Folk Rock'],
      'Latin': ['Reggaeton', 'Salsa', 'Bachata'],
      'K-Pop': ['K-R&B', 'K-Hip Hop', 'J-Pop'],
    };
    return map[genre] ?? ['Pop', 'Rock', 'Indie'];
  }

  static Future<List<Map<String, dynamic>>> getTasteGenres(int pid) async {
    var taste = await DatabaseService.getTasteProfile(pid);
    if (taste.isNotEmpty) return taste;
    var artists = await DatabaseService.getProfileArtists(pid);
    Map<String, int> counts = {};
    int total = 0;
    for (var a in artists) {
      var g = await _getGenre(a);
      if (g != null) {
        counts[g] = (counts[g] ?? 0) + 1;
        total++;
      }
    }
    if (total == 0) {
      return [{'genre': 'Pop', 'percentage': 100.0}];
    }
    return counts.entries
        .map((e) => {'genre': e.key, 'percentage': (e.value / total * 100)})
        .toList()
      ..sort((a, b) => (b['percentage'] as num).compareTo(a['percentage'] as num));
  }

  static double _recencyWeight(String playedAt) {
    var dt = DateTime.tryParse(playedAt);
    if (dt == null) return 0.5;
    var days = DateTime.now().difference(dt).inDays;
    if (days <= 7) return 1.0;
    if (days <= 30) return 0.8;
    if (days <= 90) return 0.6;
    if (days <= 365) return 0.3;
    return 0.1;
  }

  static Future<void> recalculateAffinities(int pid) async {
    var history = await DatabaseService.getListeningHistory(pid, limit: 1000);
    Map<String, Map<String, double>> artistData = {};
    for (var h in history) {
      var artist = h['artist'] as String;
      var weight = _recencyWeight(h['played_at'] as String);
      var completed = (h['completed'] as int? ?? 0).toDouble() * weight;
      var skipped = (h['skipped'] as int? ?? 0).toDouble() * weight;
      var dur = (h['play_duration'] as num?)?.toDouble() ?? 0;
      var durBonus = dur * weight / 60;
      artistData.putIfAbsent(artist, () => {
        'play_count': 0.0, 'completed_count': 0.0,
        'skip_count': 0.0, 'dur_bonus': 0.0
      });
      var d = artistData[artist]!;
      d['play_count'] = d['play_count']! + weight;
      d['completed_count'] = d['completed_count']! + completed;
      d['skip_count'] = d['skip_count']! + skipped;
      d['dur_bonus'] = d['dur_bonus']! + min(durBonus, 50);
    }

    var playlists = await DatabaseService.getPlaylists(pid);
    Map<String, int> favCount = {};
    for (var pl in playlists) {
      var tracks = await DatabaseService.getPlaylistTracks(pl['id'] as int);
      for (var t in tracks) {
        var a = t['artist'] as String;
        favCount[a] = (favCount[a] ?? 0) + 1;
      }
    }

    List<Map<String, dynamic>> affs = [];
    for (var entry in artistData.entries) {
      var d = entry.value;
      var score = (d['play_count']! * 1.0 +
          d['completed_count']! * 2.0 -
          d['skip_count']! * 0.5 +
          (favCount[entry.key] ?? 0) * 3.0 +
          min(d['dur_bonus']!, 50));
      affs.add({
        'artist_name': entry.key,
        'play_count': d['play_count']!,
        'completed_count': d['completed_count']!,
        'skip_count': d['skip_count']!,
        'fav_count': favCount[entry.key] ?? 0,
        'affinity_score': max(0.0, score),
      });
    }
    affs.sort((a, b) =>
        (b['affinity_score'] as num).compareTo(a['affinity_score'] as num));
    await DatabaseService.saveAffinities(pid, affs);
    await _recalculateTasteProfile(pid);
  }

  static Future<void> _recalculateTasteProfile(int pid) async {
    var artists = await DatabaseService.getProfileArtists(pid);
    var history = await DatabaseService.getListeningHistory(pid, limit: 200);
    Map<String, int> genreCounts = {};
    int total = 0;
    for (var h in history) {
      var g = await _getGenre(h['artist'] as String);
      if (g != null) {
        genreCounts[g] = (genreCounts[g] ?? 0) + 1;
        total++;
      }
    }
    for (var a in artists) {
      var g = await _getGenre(a);
      if (g != null) {
        genreCounts[g] = (genreCounts[g] ?? 0) + 2;
        total += 2;
      }
    }
    if (total == 0) return;
    var tastes = genreCounts.entries
        .map((e) => {
              'genre': e.key,
              'percentage': (e.value / total * 100).roundToDouble(),
            })
        .toList()
      ..sort((a, b) => (b['percentage'] as num).compareTo(a['percentage'] as num));
    await DatabaseService.saveTasteProfile(pid, tastes);
  }

  static Future<Map<String, dynamic>> getSuggestions(int pid, {String? anchorYoutubeId, Track? anchorTrack}) async {
    var artists = await DatabaseService.getProfileArtists(pid);
    var favs = artists.take(5).toList();
    var taste = await getTasteGenres(pid);
    var topGenres = taste.take(4).map((t) => t['genre'] as String).toList();
    if (topGenres.isEmpty) topGenres = ['Pop'];
    // Adjacent genre exploration
    if (topGenres.isNotEmpty) {
      var adj = _adjacentGenres(topGenres[0]);
      for (var ag in adj.take(2)) {
        if (!topGenres.contains(ag)) {
          topGenres.add(ag);
          break;
        }
      }
    }

    var affRows = await DatabaseService.getAffinities(pid, limit: 10);
    var affArtists = affRows.map((r) => r['artist_name'] as String).toSet();

    var recentArtists = await DatabaseService.getRecentRecommendations(pid, 'artist');
    var recentSongs = await DatabaseService.getRecentRecommendations(pid, 'song');

    var heardSongs = <String>{};
    var history = await DatabaseService.getListeningHistory(pid, limit: 500);
    for (var h in history) {
      heardSongs.add('${h['title']}||${h['artist']}');
    }

    // Suggested Artists
    List<Map<String, dynamic>> artistsResult = [];
    Set<String> seenArtists = {...favs, ...affArtists};
    for (var g in topGenres.take(2)) {
      var results = await ItunesService.searchByGenre(g, entity: 'musicArtist');
      for (var x in results) {
        var aname = x['artistName'] as String;
        if (!seenArtists.contains(aname) && !recentArtists.contains(aname)) {
          seenArtists.add(aname);
          artistsResult.add(x);
        }
      }
    }

    // Suggested Albums (via YouTube)
    List<Map<String, dynamic>> albumsResult = [];
    Set<String> seenTracks = {};
    var albumArtists = affArtists.take(4).toList();
    if (albumArtists.isEmpty) albumArtists = favs.take(3).toList();
    var yt = YtDlpService();
    for (var a in albumArtists) {
      var tracks = await yt.search('$a - topic', limit: 6);
      for (var t in tracks) {
        var key = '${t.title}||${t.artist}';
        if (seenTracks.add(key)) {
          albumsResult.add({
            'title': t.title,
            'artist': t.artist,
            'youtubeId': t.youtubeId ?? '',
            'artworkUrl': t.artworkUrl,
          });
        }
      }
    }

    // Suggested Songs
    List<Track> songsResult = [];
    Map<String, int> artistSongCount = {};
    bool ok(Track t) {
      if (t.title.isEmpty || t.artist.isEmpty) return false;
      if (heardSongs.contains(t.dbKey) || recentSongs.contains(t.dbKey)) return false;
      if (artistSongCount.putIfAbsent(t.artist, () => 0) >= 2) return false;
      return true;
    }

    // YouTube Next / anchor-based (Echo Music style)
    if (anchorYoutubeId != null) {
      var related = await YtDlpService().getRelated(anchorYoutubeId);
      for (var s in related) {
        if (ok(s)) {
          artistSongCount[s.artist] = (artistSongCount[s.artist] ?? 0) + 1;
          songsResult.add(s);
        }
      }
    } else if (anchorTrack != null) {
      var related = await YtDlpService().searchAudio(
          '${anchorTrack.title} ${anchorTrack.artist}', limit: 6);
      for (var s in related) {
        if (ok(s)) {
          artistSongCount[s.artist] = (artistSongCount[s.artist] ?? 0) + 1;
          songsResult.add(s);
        }
      }
    }

    // YouTube genre search (replaces iTunes genre search)
    for (var g in topGenres.take(2)) {
      var songs = await YtDlpService().searchAudio(g, limit: 6);
      for (var s in songs) {
        if (ok(s)) {
          artistSongCount[s.artist] = (artistSongCount[s.artist] ?? 0) + 1;
          songsResult.add(s);
        }
      }
    }

    // Affinity artist songs from YouTube
    for (var a in affArtists.take(3)) {
      var songs = await YtDlpService().searchAudio(a, limit: 4);
      for (var s in songs) {
        if (ok(s)) {
          artistSongCount[s.artist] = (artistSongCount[s.artist] ?? 0) + 1;
          songsResult.add(s);
        }
      }
    }

    // Collaborative filtering
    var others = (await DatabaseService.getProfiles())
        .map((p) => p['id'] as int)
        .where((id) => id != pid)
        .toList();
    List<Track> collabSongs = [];
    var mySet = history.map((h) => '${h['title']}||${h['artist']}').toSet();
    for (var uid in others) {
      var theirHistory = await DatabaseService.getListeningHistory(uid, limit: 200);
      var theirSet = theirHistory.map((h) => '${h['title']}||${h['artist']}').toSet();
      var inter = mySet.intersection(theirSet).length;
      var union = mySet.union(theirSet).length;
      if (union > 0 && inter / union > 0.1) {
        for (var h in theirHistory) {
          var key = '${h['title']}||${h['artist']}';
          if (!mySet.contains(key)) {
            collabSongs.add(Track(
              title: h['title'] as String,
              artist: h['artist'] as String,
              album: h['album'] as String? ?? '',
            ));
            if (collabSongs.length >= 5) break;
          }
        }
      }
      if (collabSongs.length >= 5) break;
    }
    for (var cs in collabSongs) {
      if (ok(cs)) {
        artistSongCount[cs.artist] = (artistSongCount[cs.artist] ?? 0) + 1;
        songsResult.add(cs);
      }
    }

    // Save recommendation history
    for (var x in artistsResult.take(8)) {
      await DatabaseService.addRecommendationHistory(pid, 'artist',
          x['artistName'] as String, x['artistName'] as String);
    }
    for (var x in albumsResult.take(8)) {
      await DatabaseService.addRecommendationHistory(pid, 'album',
          '${x['collectionName']}||${x['artistName']}',
          x['collectionName'] as String);
    }
    for (var s in songsResult) {
      await DatabaseService.addRecommendationHistory(pid, 'song', s.dbKey, s.title);
    }

    return {
      'artists': artistsResult.take(8).toList(),
      'albums': albumsResult.take(8).toList(),
      'songs': songsResult.take(12).toList(),
    };
  }
}
