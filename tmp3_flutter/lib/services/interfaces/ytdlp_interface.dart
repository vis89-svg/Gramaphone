import '../../models/track.dart';
import '../innertube_service.dart' show AlbumInfo;

abstract class YtDlpInterface {
  Future<List<Track>> search(String query, {int limit = 8});
  Future<List<Track>> searchAudio(String query, {int limit = 8});
  Future<List<Track>> getRelated(String videoId, {int limit = 8});
  Future<String?> getAudioUrl(String videoId);
  Future<List<Map<String, dynamic>>> searchPlaylists(String query, {int limit = 8});
  Future<List<Track>> getPlaylistVideos(String playlistId);
  Future<List<AlbumInfo>> searchAlbums(String query, {int limit = 6});
  Future<List<Track>> getAlbumTracks(String browseId);
}
