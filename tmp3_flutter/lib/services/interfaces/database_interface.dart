import '../../models/track.dart';

abstract class DatabaseInterface {
  Future<int> ensureProfile(String name, List<String> languages);
  Future<List<Map<String, dynamic>>> getProfiles();
  Future<void> saveProfileArtists(int pid, List<String> artists);
  Future<List<String>> getProfileArtists(int pid);
  Future<void> logPlay(int pid, Track t, double duration, bool completed, bool skipped);
  Future<List<Map<String, dynamic>>> getListeningHistory(int pid, {int limit = 50});
  Future<List<Map<String, dynamic>>> getAffinities(int pid, {int limit = 20});
  Future<void> saveAffinities(int pid, List<Map<String, dynamic>> affs);
  Future<List<Map<String, dynamic>>> getTasteProfile(int pid);
  Future<void> saveTasteProfile(int pid, List<Map<String, dynamic>> tastes);
  Future<void> addRecommendationHistory(int pid, String type, String key, String name);
  Future<Set<String>> getRecentRecommendations(int pid, String type);
  Future<List<Map<String, dynamic>>> getPlaylists(int pid, {String? type});
  Future<int> createPlaylist(int pid, String name, String type);
  Future<List<Map<String, dynamic>>> getPlaylistTracks(int plid);
}
