import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';

class InnerTubeService {
  static const _musicBase = 'https://music.youtube.com/youtubei/v1';
  static const _webKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

  final YoutubeExplode _yt = YoutubeExplode();
  final http.Client _http = http.Client();

  static final InnerTubeService _instance = InnerTubeService._();
  factory InnerTubeService() => _instance;
  InnerTubeService._();

  http.Client get httpClient => _http;

  final Map<String, List<Track>> _searchCache = {};
  final Map<String, List<Track>> _relatedCache = {};

  Future<List<Track>> search(String query, {int limit = 8}) async {
    var key = 'search:$query:$limit';
    if (_searchCache.containsKey(key)) {
      return _searchCache[key]!.take(limit).toList();
    }
    try {
      var results = await _yt.search.search(query);
      var tracks = <Track>[];
      for (var r in results) {
        if (tracks.length >= limit) break;
        tracks.add(Track(
          title: r.title,
          artist: r.author,
          duration: r.duration?.inSeconds ?? 0,
          artworkUrl: r.thumbnails.highResUrl,
          youtubeId: r.id.value,
        ));
      }
      _searchCache[key] = tracks;
      return tracks;
    } catch (_) {
      return [];
    }
  }

  Future<List<Track>> getRelated(String videoId, {int limit = 8}) async {
    var cacheKey = 'related:$videoId';
    if (_relatedCache.containsKey(cacheKey)) {
      return _relatedCache[cacheKey]!.take(limit).toList();
    }
    try {
      var body = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240101.00.00',
            'hl': 'en',
            'gl': 'US',
          }
        },
        'videoId': videoId,
        'playlistId': 'RDAMVM$videoId',
      };
      var r = await _http.post(
        Uri.parse('$_musicBase/next?key=$_webKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (r.statusCode != 200) return [];
      var j = json.decode(r.body) as Map<String, dynamic>;

      var tabs = j['contents']?['singleColumnMusicWatchNextResultsRenderer']
          ?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs']
          as List<dynamic>?;
      if (tabs == null || tabs.isEmpty) return [];

      var items = tabs[0]?['tabRenderer']?['content']?['musicQueueRenderer']
          ?['content']?['playlistPanelRenderer']?['contents']
          as List<dynamic>?;
      if (items == null) return [];

      var tracks = <Track>[];
      for (var item in items) {
        var ppr = item['playlistPanelVideoRenderer'] as Map<String, dynamic>?;
        ppr ??= item['playlistPanelVideoWrapperRenderer']
            ?['primaryRenderer']?['playlistPanelVideoRenderer']
            as Map<String, dynamic>?;
        if (ppr == null) continue;

        var vid = ppr['videoId'] as String?;
        if (vid == null || vid.isEmpty || vid == videoId) continue;

        var title = _runsText(ppr['title'] as Map<String, dynamic>?);
        if (title.isEmpty) continue;

        var artist = _runsText(ppr['longBylineText'] as Map<String, dynamic>?);
        artist = artist.replaceAll(RegExp(r'\s*[•·]\s*\d+[KMB]?\s*views.*$'), '').trim();
        artist = artist.replaceAll(RegExp(r'\s*•\s*\d+[KMB]?\s*$'), '').trim();

        var duration = _parseDuration(ppr['lengthText']);

        var thumbnail = '';
        var thumbs = ppr['thumbnail']?['thumbnails'] as List<dynamic>?;
        if (thumbs != null && thumbs.isNotEmpty) {
          thumbnail = thumbs.last['url'] as String? ?? '';
        }

        tracks.add(Track(
          title: title,
          artist: artist,
          duration: duration,
          artworkUrl: thumbnail,
          youtubeId: vid,
        ));
        if (tracks.length >= limit) break;
      }
      _relatedCache[cacheKey] = tracks;
      return tracks;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchPlaylists(String query, {int limit = 8}) async {
    try {
      var results = await _yt.search.searchContent(query, filter: TypeFilters.playlist);
      var playlists = <Map<String, dynamic>>[];
      for (var r in results) {
        if (playlists.length >= limit) break;
        if (r is SearchPlaylist) {
          var thumb = r.thumbnails.isNotEmpty ? r.thumbnails.last.url : '';
          playlists.add({
            'title': r.title,
            'playlistId': r.id.value,
            'videoCount': r.videoCount,
            'thumbnailUrl': thumb,
          });
        }
      }
      return playlists;
    } catch (_) {
      return [];
    }
  }

  Future<List<Track>> getPlaylistVideos(String playlistId) async {
    try {
      var videos = await _yt.playlists.getVideos(playlistId).toList();
      return videos.map((v) => Track(
                title: v.title,
                artist: v.author,
                duration: v.duration?.inSeconds ?? 0,
                artworkUrl: v.thumbnails.highResUrl,
                youtubeId: v.id.value,
              )).toList();
    } catch (_) {
      return [];
    }
  }

  Future<StreamInfo?> getBestAudioStream(String videoId) async {
    try {
      var manifest = await _yt.videos.streams.getManifest(videoId);
      var audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return null;

      var preferredTags = [140, 251, 250, 249, 139];
      for (var tag in preferredTags) {
        try {
          return audioStreams.firstWhere((s) => s.tag == tag);
        } catch (_) {}
      }
      return audioStreams.first;
    } catch (_) {
      return null;
    }
  }

  /// Downloads audio data for a [StreamInfo] using youtube_explode_dart's
  /// HTTP client which sends proper headers (CONSENT cookie, User-Agent, etc.)
  Stream<List<int>> downloadStream(StreamInfo info) {
    return _yt.videos.streams.get(info);
  }

  Future<String?> getAudioStreamUrl(String videoId) async {
    var info = await getBestAudioStream(videoId);
    return info?.url.toString();
  }

  void clearCache() {
    _searchCache.clear();
    _relatedCache.clear();
  }

  void dispose() {
    _yt.close();
    _http.close();
  }

  String _runsText(Map<String, dynamic>? obj) {
    if (obj == null) return '';
    var runs = obj['runs'] as List<dynamic>?;
    if (runs == null) return '';
    return runs.map((r) => r['text'] as String? ?? '').join();
  }

  int _parseDuration(dynamic lengthText) {
    if (lengthText is! Map) return 0;
    var text = _runsText(lengthText as Map<String, dynamic>?);
    if (text.isEmpty) {
      text = lengthText['simpleText'] as String? ?? '';
    }
    var parts = text.split(':');
    if (parts.length == 2) {
      return int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;
    } else if (parts.length == 3) {
      return int.tryParse(parts[0])! * 3600 +
          int.tryParse(parts[1])! * 60 +
          int.tryParse(parts[2])!;
    }
    return 0;
  }
}
