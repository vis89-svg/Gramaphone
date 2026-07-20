import 'dart:convert';
import 'dart:io';
import '../models/track.dart';

class YtDlpService {
  static Future<List<Track>> search(String query, {int limit = 8}) async {
    try {
      var r = await Process.run('python', [
        '-m', 'yt_dlp',
        '--dump-json',
        '--flat-playlist',
        '--no-warnings',
        '--', 'ytsearch$limit:$query',
      ]);
      if (r.exitCode != 0) return [];
      var lines = (r.stdout as String)
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      List<Track> results = [];
      for (var line in lines) {
        try {
          var j = json.decode(line);
          results.add(Track(
            title: j['title'] ?? '',
            artist: j['uploader'] ?? j['channel'] ?? 'Unknown',
            album: j['album'] ?? '',
            artworkUrl: j['thumbnail'] ?? '',
            duration: (j['duration'] ?? 0) is int
                ? j['duration'] as int
                : int.tryParse('${j['duration']}') ?? 0,
            youtubeId: j['id'] as String?,
          ));
        } catch (_) {}
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  static Future<List<Track>> getRelated(String videoId, {int limit = 8}) async {
    try {
      var r = await Process.run('python', [
        '-m', 'yt_dlp',
        '--dump-json',
        '--flat-playlist',
        '--no-warnings',
        '--', 'https://www.youtube.com/watch?v=$videoId&list=RD$videoId',
      ]);
      if (r.exitCode != 0) return [];
      var lines = (r.stdout as String)
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      List<Track> results = [];
      for (var line in lines.skip(1).take(limit)) {
        try {
          var e = json.decode(line);
          results.add(Track(
            title: e['title'] ?? '',
            artist: e['uploader'] ?? e['channel'] ?? 'Unknown',
            album: '',
            artworkUrl: e['thumbnail'] ?? '',
            duration: (e['duration'] ?? 0) is int
                ? e['duration'] as int
                : int.tryParse('${e['duration']}') ?? 0,
            youtubeId: e['id'] as String?,
          ));
        } catch (_) {}
      }
      return results;
    } catch (_) {
      return [];
    }
  }
}
