import 'dart:convert';
import 'package:http/http.dart' as http;

class LyricsLine {
  final double time; // seconds
  final String text;
  LyricsLine(this.time, this.text);
}

class LyricsService {
  static const _base = 'https://lrclib.net/api';

  static Future<List<LyricsLine>?> getSynced(String title, String artist) async {
    try {
      var uri = Uri.parse('$_base/get?artist_name=${Uri.encodeComponent(artist)}&track_name=${Uri.encodeComponent(title)}');
      var r = await http.get(uri, headers: {'User-Agent': 'tmp3/1.0'});
      if (r.statusCode != 200) return null;
      var j = json.decode(r.body) as Map<String, dynamic>;
      var raw = j['syncedLyrics'] as String?;
      if (raw == null || raw.isEmpty) {
        raw = j['plainLyrics'] as String?;
        if (raw == null || raw.isEmpty) return null;
        return raw.split('\n').where((l) => l.trim().isNotEmpty).map((l) => LyricsLine(-1, l.trim())).toList();
      }
      return _parseLrc(raw);
    } catch (_) {
      return null;
    }
  }

  static List<LyricsLine> _parseLrc(String lrc) {
    var lines = <LyricsLine>[];
    var regex = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)');
    for (var line in lrc.split('\n')) {
      var m = regex.firstMatch(line);
      if (m != null) {
        var min = int.parse(m.group(1)!);
        var sec = double.parse(m.group(2)!);
        var text = m.group(3)?.trim() ?? '';
        if (text.isNotEmpty) {
          lines.add(LyricsLine(min * 60.0 + sec, text));
        }
      }
    }
    return lines;
  }
}
