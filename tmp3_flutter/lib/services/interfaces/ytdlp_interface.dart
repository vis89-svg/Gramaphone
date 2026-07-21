import '../../models/track.dart';

abstract class YtDlpInterface {
  Future<List<Track>> search(String query, {int limit = 8});
  Future<List<Track>> getRelated(String videoId, {int limit = 8});
  Future<String?> getAudioUrl(String videoId);
}
