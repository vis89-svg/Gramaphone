import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';

class AlbumInfo {
  final String browseId;
  final String title;
  final String artist;
  final String artworkUrl;
  final String? playlistId;
  AlbumInfo({required this.browseId, required this.title, required this.artist, this.artworkUrl = '', this.playlistId});
}

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

  Future<List<Track>> searchAudio(String query, {int limit = 8}) async {
    var results = await search('$query - topic', limit: limit);
    if (results.isEmpty) {
      results = await search(query, limit: limit);
    }
    return results;
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

  // ── Album features ──────────────────────────────────────────

  static const _albumParams = 'EgWKAQIYAWoMEA4QChADEAQQCRAF';

  Future<List<AlbumInfo>> searchAlbums(String query, {int limit = 6}) async {
    try {
      var albums = await _searchAlbumsFiltered(query, limit: limit);
      if (albums.isNotEmpty) return albums;
      return await _searchAlbumsGeneral(query, limit: limit);
    } catch (_) {
      return [];
    }
  }

  Future<List<AlbumInfo>> _searchAlbumsFiltered(String query, {int limit = 6}) async {
    var body = {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20240101.00.00',
          'hl': 'en',
          'gl': 'US',
        }
      },
      'query': query,
      'params': _albumParams,
    };
    var r = await _http.post(
      Uri.parse('$_musicBase/search?key=$_webKey'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (r.statusCode != 200) return [];

    var j = json.decode(r.body) as Map<String, dynamic>;
    var tabs = j['contents']?['tabbedSearchResultsRenderer']
        ?['tabs'] as List<dynamic>?;
    if (tabs == null || tabs.isEmpty) return [];

    var contents = tabs[0]?['tabRenderer']?['content']
        ?['sectionListRenderer']?['contents'] as List<dynamic>?;
    if (contents == null) return [];

    List<AlbumInfo> albums = [];
    for (var section in contents) {
      if (albums.length >= limit) break;

      // Parse top result (musicCardShelfRenderer) — often contains the exact album
      var card = section['musicCardShelfRenderer'] as Map<String, dynamic>?;
      if (card != null) {
        var album = _parseCardAlbum(card);
        if (album != null) albums.add(album);
        continue;
      }

      // Parse shelf items (musicShelfRenderer)
      var items = section['musicShelfRenderer']?['contents']
          as List<dynamic>?;
      if (items == null) continue;
      for (var item in items) {
        if (albums.length >= limit) break;
        var album = _parseListItemAlbum(item);
        if (album != null) albums.add(album);
      }
    }
    return albums;
  }

  Future<List<AlbumInfo>> _searchAlbumsGeneral(String query, {int limit = 6}) async {
    var body = {
      'context': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20240101.00.00',
          'hl': 'en',
          'gl': 'US',
        }
      },
      'query': query,
    };
    var r = await _http.post(
      Uri.parse('$_musicBase/search?key=$_webKey'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (r.statusCode != 200) return [];

    var j = json.decode(r.body) as Map<String, dynamic>;
    var tabs = j['contents']?['tabbedSearchResultsRenderer']
        ?['tabs'] as List<dynamic>?;
    if (tabs == null || tabs.isEmpty) return [];

    var contents = tabs[0]?['tabRenderer']?['content']
        ?['sectionListRenderer']?['contents'] as List<dynamic>?;
    if (contents == null) return [];

    List<AlbumInfo> albums = [];
    for (var section in contents) {
      if (albums.length >= limit) break;

      var card = section['musicCardShelfRenderer'] as Map<String, dynamic>?;
      if (card != null) {
        var album = _parseCardAlbum(card);
        if (album != null) albums.add(album);
        continue;
      }

      var items = section['musicShelfRenderer']?['contents']
          as List<dynamic>?;
      if (items == null) continue;
      for (var item in items) {
        if (albums.length >= limit) break;
        var album = _parseListItemAlbum(item);
        if (album != null) albums.add(album);
      }
    }
    return albums;
  }

  AlbumInfo? _parseCardAlbum(Map<String, dynamic> card) {
    try {
      var ne = card['onTap'] as Map<String, dynamic>?;
      var bid = ne?['browseEndpoint']?['browseId'] as String?;
      var thumbPl = ne?['watchEndpoint']?['playlistId'] as String?;
      // Accept MPREb_ (browse) or OLAK5uy_ (playlist)
      if (bid == null || (!bid.startsWith('MPREb_') && !bid.startsWith('OLAK5uy_'))) {
        if (thumbPl != null && thumbPl.startsWith('OLAK5uy_')) bid = thumbPl;
        else return null;
      }

      var title = _runsText(card['title'] as Map<String, dynamic>?);
      if (title.isEmpty) return null;

      var runs = card['subtitle']?['runs'] as List<dynamic>?;
      var artist = '';
      if (runs != null) {
        artist = runs.map((r) => r['text'] as String? ?? '').join();
        artist = artist.replaceAll(RegExp(r'\s*•\s*202\d.*$'), '').trim();
      }

      var thumbs = card['thumbnail']?['musicThumbnailRenderer']
          ?['thumbnail']?['thumbnails'] as List<dynamic>?;
      var art = (thumbs != null && thumbs.isNotEmpty)
          ? thumbs.last['url'] as String? ?? ''
          : '';

      // Extract playlistId from button or onTap
      var pl = thumbPl;
      if (pl == null) {
        var btn = card['buttons']?[0]?['buttonRenderer']?['command'] as Map<String, dynamic>?;
        pl = btn?['watchEndpoint']?['playlistId'] as String?;
      }

      return AlbumInfo(browseId: bid!, title: title, artist: artist, artworkUrl: art, playlistId: pl);
    } catch (_) {
      return null;
    }
  }

  AlbumInfo? _parseListItemAlbum(dynamic item) {
    try {
      var rir = item['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
      if (rir == null) return null;

      var ne = rir['navigationEndpoint'] as Map<String, dynamic>?;
      var bid = ne?['browseEndpoint']?['browseId'] as String?;

      // Extract playlistId from the play button
      var pl = '';
      var menu = rir['menu']?['menuRenderer']?['items'] as List<dynamic>?;
      if (menu != null) {
        for (var m in menu) {
          var pb = m['menuNavigationItemRenderer']?['navigationEndpoint']
              ?['watchEndpoint']?['playlistId'] as String?;
          if (pb != null && pb.startsWith('OLAK5uy_')) { pl = pb; break; }
        }
      }
      // Also check playButton
      if (pl.isEmpty) {
        pl = rir['playButton']?['playNavigationEndpoint']
            ?['watchEndpoint']?['playlistId'] as String? ?? '';
      }

      // Accept MPREb_ (browse) or OLAK5uy_ (playlist)
      if (bid == null || (!bid.startsWith('MPREb_') && !bid.startsWith('OLAK5uy_'))) {
        if (pl.startsWith('OLAK5uy_')) bid = pl;
        else return null;
      }

      var title = _runsText(rir['title'] as Map<String, dynamic>?);
      if (title.isEmpty) return null;

      var columns = rir['flexColumns'] as List<dynamic>?;
      var subtitle = '';
      var thumbs = rir['thumbnail']?['musicThumbnailRenderer']
          ?['thumbnail']?['thumbnails'] as List<dynamic>?;
      var art = (thumbs != null && thumbs.isNotEmpty)
          ? thumbs.last['url'] as String? ?? ''
          : '';

      if (columns != null && columns.length > 1) {
        var runs = columns[1]?['musicResponsiveListItemFlexColumnRenderer']
            ?['text']?['runs'] as List<dynamic>?;
        if (runs != null) {
          subtitle = runs.map((r) => r['text'] as String? ?? '').join();
        }
      }

      return AlbumInfo(
        browseId: bid,
        title: title,
        artist: subtitle.replaceAll(RegExp(r'\s*•\s*202\d.*$'), '').trim(),
        artworkUrl: art,
        playlistId: pl.isNotEmpty ? pl : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<Track>> getAlbumTracks(String browseId) async {
    try {
      // OLAK5uy_ IDs are playlist IDs; use playlist endpoint instead of browse
      if (browseId.startsWith('OLAK5uy_')) {
        return getPlaylistVideos(browseId);
      }

      var body = {
        'context': {
          'client': {
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240101.00.00',
            'hl': 'en',
            'gl': 'US',
          }
        },
        'browseId': browseId,
      };
      var r = await _http.post(
        Uri.parse('$_musicBase/browse?key=$_webKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (r.statusCode != 200) return [];

      var j = json.decode(r.body) as Map<String, dynamic>;
      var tabs = j['contents']?['singleColumnBrowseResultsRenderer']
          ?['tabs'] as List<dynamic>?;
      if (tabs == null || tabs.isEmpty) return [];

      var contents = tabs[0]?['tabRenderer']?['content']
          ?['sectionListRenderer']?['contents'] as List<dynamic>?;
      if (contents == null) return [];

      List<Track> tracks = [];
      for (var section in contents) {
        var items = section['musicShelfRenderer']?['contents']
            as List<dynamic>?;
        if (items == null) continue;
        for (var item in items) {
          var rir = item['musicResponsiveListItemRenderer'] as Map<String, dynamic>?;
          if (rir == null) continue;

          var vid = rir['playlistItemData']?['videoId'] as String?;
          vid ??= rir['navigationEndpoint']?['watchEndpoint']?['videoId'] as String?;
          if (vid == null || vid.isEmpty) continue;

          var title = _runsText(rir['title'] as Map<String, dynamic>?);
          if (title.isEmpty) continue;

          var columns = rir['flexColumns'] as List<dynamic>?;
          var artist = '';
          if (columns != null && columns.length > 1) {
            var runs = columns[1]?['musicResponsiveListItemFlexColumnRenderer']
                ?['text']?['runs'] as List<dynamic>?;
            if (runs != null) {
              artist = runs.map((r) => r['text'] as String? ?? '').join();
            }
          }

          var duration = _parseDuration(rir['fixedColumns']?[0]
              ?['musicResponsiveListItemFixedColumnRenderer']?['text']);

          var thumbs = rir['thumbnail']?['musicThumbnailRenderer']
              ?['thumbnail']?['thumbnails'] as List<dynamic>?;
          var art = (thumbs != null && thumbs.isNotEmpty)
              ? thumbs.last['url'] as String? ?? ''
              : '';

          tracks.add(Track(
            title: title,
            artist: artist,
            duration: duration,
            artworkUrl: art,
            youtubeId: vid,
            collectionId: browseId,
          ));
        }
      }
      return tracks;
    } catch (_) {
      return [];
    }
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
