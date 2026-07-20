import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track.dart';

class ItunesService {
  static const String base = 'https://itunes.apple.com';

  static Uri _build(String path, Map<String, String> params) {
    var uri = Uri.parse('$base/$path');
    return uri.replace(query: Uri(queryParameters: params).query);
  }

  static Future<List<Track>> searchSongs(String query, {int limit = 15}) async {
    try {
      var r = await http
          .get(_build('search', {'term': query, 'entity': 'song', 'limit': '$limit'}))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      var data = json.decode(r.body);
      return (data['results'] as List).map((m) => Track.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchArtists(String query,
      {int limit = 5}) async {
    try {
      var r = await http
          .get(_build('search', {'term': query, 'entity': 'musicArtist', 'limit': '$limit'}))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      var data = json.decode(r.body);
      return (data['results'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchAlbums(String query,
      {int limit = 10}) async {
    try {
      var r = await http
          .get(_build('search', {'term': query, 'entity': 'album', 'limit': '$limit'}))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      var data = json.decode(r.body);
      return (data['results'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Track>> getArtistTopSongs(String artistName,
      {int limit = 15}) async {
    try {
      var r = await http
          .get(_build('search',
              {'term': artistName, 'entity': 'song', 'limit': '$limit'}))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      var data = json.decode(r.body);
      return (data['results'] as List).map((m) => Track.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Track>> getAlbumTracks(String albumName, String artistName,
      {String? collectionId}) async {
    if (collectionId != null) {
      try {
        var r = await http
            .get(_build('lookup', {'id': collectionId, 'entity': 'song'}))
            .timeout(const Duration(seconds: 10));
        if (r.statusCode != 200) return [];
        var data = json.decode(r.body);
        var results = data['results'] as List;
        if (results.length < 2) return [];
        return results.sublist(1).map((m) => Track.fromMap(m)).toList();
      } catch (_) {
        return [];
      }
    }
    try {
      var r = await http
          .get(_build('search', {'term': albumName, 'entity': 'song', 'limit': '20'}))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      var data = json.decode(r.body);
      return (data['results'] as List)
          .where((x) =>
              (x['collectionName'] ?? '') == albumName ||
              (x['artistName'] ?? '') == artistName)
          .map((m) => Track.fromMap(m))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> deduplicateArtists(
      List<Map<String, dynamic>> artists) {
    Map<String, Map<String, dynamic>> merged = {};
    for (var a in artists) {
      var name = a['artistName'] as String;
      if (merged.containsKey(name)) {
        var existing = merged[name]!;
        var g1 = existing['primaryGenreName'] as String? ?? '';
        var g2 = a['primaryGenreName'] as String? ?? '';
        if (g2.isNotEmpty && !g1.contains(g2)) {
          existing['primaryGenreName'] = g1.isNotEmpty ? '$g1, $g2' : g2;
        }
      } else {
        merged[name] = Map.from(a);
      }
    }
    return merged.values.toList();
  }

  static Future<String?> getArtistGenre(String artistName) async {
    try {
      var r = await http
          .get(_build('search', {'term': artistName, 'entity': 'song', 'limit': '1'}))
          .timeout(const Duration(seconds: 4));
      if (r.statusCode != 200) return null;
      var data = json.decode(r.body);
      var results = data['results'] as List;
      if (results.isEmpty) return null;
      return results[0]['primaryGenreName'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> searchByGenre(String genre,
      {String entity = 'musicArtist', int limit = 8}) async {
    try {
      var r = await http
          .get(_build('search', {'term': genre, 'entity': entity, 'limit': '$limit'}))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      var data = json.decode(r.body);
      return (data['results'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Track>> searchAll(String query) async {
    Set<String> seen = {};
    List<Track> results = [];
    try {
      var songs = await searchSongs(query, limit: 15);
      for (var s in songs) {
        if (seen.add(s.dbKey)) results.add(s);
      }
    } catch (_) {}
    try {
      var r = await http
          .get(_build('search', {'term': query, 'entity': 'musicArtist', 'limit': '3'}))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        var data = json.decode(r.body);
        for (var x in (data['results'] as List)) {
          var aname = x['artistName'] as String;
          var songs2 = await getArtistTopSongs(aname, limit: 20);
          for (var s in songs2) {
            if (seen.add(s.dbKey)) results.add(s);
          }
        }
      }
    } catch (_) {}
    return results;
  }
}
