import 'dart:io';
import '../models/track.dart';
import 'interfaces/ytdlp_interface.dart';
import 'innertube_service.dart';

class YtDlpService implements YtDlpInterface {
  static final YtDlpService _instance = YtDlpService._();
  factory YtDlpService() => _instance;
  YtDlpService._();

  final _innerTube = InnerTubeService();

  @override
  Future<List<Track>> search(String query, {int limit = 8}) async {
    return _innerTube.search(query, limit: limit);
  }

  @override
  Future<List<Track>> searchAudio(String query, {int limit = 8}) async {
    return _innerTube.searchAudio(query, limit: limit);
  }

  @override
  Future<List<Track>> getRelated(String videoId, {int limit = 8}) async {
    return _innerTube.getRelated(videoId, limit: limit);
  }

  @override
  Future<List<Map<String, dynamic>>> searchPlaylists(String query, {int limit = 8}) async {
    return _innerTube.searchPlaylists(query, limit: limit);
  }

  @override
  Future<List<Track>> getPlaylistVideos(String playlistId) async {
    return _innerTube.getPlaylistVideos(playlistId);
  }

  @override
  Future<String?> getAudioUrl(String videoId) async {
    try {
      var r = await Process.run('python', [
        '-m', 'yt_dlp',
        '--get-url',
        '--format', 'bestaudio[ext=m4a]/bestaudio',
        '--', 'https://www.youtube.com/watch?v=$videoId',
      ]);
      if (r.exitCode != 0) return null;
      var url = (r.stdout as String).trim();
      if (url.isEmpty) return null;
      return url;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AlbumInfo>> searchAlbums(String query, {int limit = 6}) async {
    return _innerTube.searchAlbums(query, limit: limit);
  }

  @override
  Future<List<Track>> getAlbumTracks(String browseId) async {
    return _innerTube.getAlbumTracks(browseId);
  }
}
