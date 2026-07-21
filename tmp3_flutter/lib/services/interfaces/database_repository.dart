import '../../models/track.dart';
import '../database_service.dart';
import 'database_interface.dart';

class DatabaseRepository implements DatabaseInterface {
  @override
  Future<int> ensureProfile(String name, List<String> languages) =>
      DatabaseService.ensureProfile(name, languages);

  @override
  Future<List<Map<String, dynamic>>> getProfiles() =>
      DatabaseService.getProfiles();

  @override
  Future<void> saveProfileArtists(int pid, List<String> artists) =>
      DatabaseService.saveProfileArtists(pid, artists);

  @override
  Future<List<String>> getProfileArtists(int pid) =>
      DatabaseService.getProfileArtists(pid);

  @override
  Future<void> logPlay(int pid, Track t, double duration, bool completed, bool skipped) =>
      DatabaseService.logPlay(pid, t, duration, completed, skipped);

  @override
  Future<List<Map<String, dynamic>>> getListeningHistory(int pid, {int limit = 50}) =>
      DatabaseService.getListeningHistory(pid, limit: limit);

  @override
  Future<List<Map<String, dynamic>>> getAffinities(int pid, {int limit = 20}) =>
      DatabaseService.getAffinities(pid, limit: limit);

  @override
  Future<void> saveAffinities(int pid, List<Map<String, dynamic>> affs) =>
      DatabaseService.saveAffinities(pid, affs);

  @override
  Future<List<Map<String, dynamic>>> getTasteProfile(int pid) =>
      DatabaseService.getTasteProfile(pid);

  @override
  Future<void> saveTasteProfile(int pid, List<Map<String, dynamic>> tastes) =>
      DatabaseService.saveTasteProfile(pid, tastes);

  @override
  Future<void> addRecommendationHistory(int pid, String type, String key, String name) =>
      DatabaseService.addRecommendationHistory(pid, type, key, name);

  @override
  Future<Set<String>> getRecentRecommendations(int pid, String type) =>
      DatabaseService.getRecentRecommendations(pid, type);

  @override
  Future<List<Map<String, dynamic>>> getPlaylists(int pid, {String? type}) =>
      DatabaseService.getPlaylists(pid, type: type);

  @override
  Future<int> createPlaylist(int pid, String name, String type) =>
      DatabaseService.createPlaylist(pid, name, type);

  @override
  Future<List<Map<String, dynamic>>> getPlaylistTracks(int plid) =>
      DatabaseService.getPlaylistTracks(plid);

  @override
  Future<void> addPlaylistTrack(int plid, Track t) =>
      DatabaseService.addPlaylistTrack(plid, t);

  @override
  Future<List<Map<String, dynamic>>> getHeavyRotation(int pid, {int limit = 20}) =>
      DatabaseService.getHeavyRotation(pid, limit: limit);

  @override
  Future<List<Map<String, dynamic>>> getRecentlyPlayedTracks(int pid, {int limit = 10}) =>
      DatabaseService.getRecentlyPlayedTracks(pid, limit: limit);
}
