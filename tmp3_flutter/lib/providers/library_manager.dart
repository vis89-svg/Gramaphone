import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/interfaces/database_interface.dart';
import '../services/recommendation_service.dart';

class LibraryManager extends ChangeNotifier {
  final DatabaseInterface database;

  LibraryManager({required this.database});

  Map<String, dynamic> _suggestions = {};
  List<Map<String, dynamic>> _recentlyPlayed = [];
  List<Map<String, dynamic>> _heavyRotation = [];
  List<Map<String, dynamic>> _playlists = [];
  List<Track> _dailyMixes = [];
  List<Track> _newReleases = [];

  Map<String, dynamic> get suggestions => _suggestions;
  List<Map<String, dynamic>> get recentlyPlayed => _recentlyPlayed;
  List<Map<String, dynamic>> get heavyRotation => _heavyRotation;
  List<Map<String, dynamic>> get playlists => _playlists;
  List<Track> get dailyMixes => _dailyMixes;
  List<Track> get newReleases => _newReleases;

  Future<void> refresh({
    int? profileId,
    String? anchorYoutubeId,
    Track? anchorTrack,
  }) async {
    if (profileId == null) return;
    try {
      _suggestions = await RecommendationService.getSuggestions(
        profileId,
        anchorYoutubeId: anchorYoutubeId,
        anchorTrack: anchorTrack,
      );
    } catch (e) {
      debugPrint('[LIB] suggestions error: $e');
    }
    try {
      _recentlyPlayed = await database.getRecentlyPlayedTracks(profileId, limit: 20);
    } catch (e) {
      debugPrint('[LIB] recentlyPlayed error: $e');
    }
    try {
      _heavyRotation = await database.getHeavyRotation(profileId, limit: 20);
    } catch (e) {
      debugPrint('[LIB] heavyRotation error: $e');
    }
    _playlists = await database.getPlaylists(profileId);
    notifyListeners();
  }

  Future<void> logPlay(int profileId, Track t, double duration,
      bool completed, bool skipped) async {
    await database.logPlay(profileId, t, duration, completed, skipped);
    await RecommendationService.recalculateAffinities(profileId);
  }

  void removeSuggestion(Track t) {
    var songs = _suggestions['songs'] as List<Track>? ?? [];
    songs.removeWhere((s) => s.dbKey == t.dbKey);
    _suggestions['songs'] = songs;
    notifyListeners();
  }

  Future<void> generateDailyMixes(int profileId) async {
    try {
      var affs = await database.getAffinities(profileId, limit: 12);
      var topArtists = affs.take(4).map((a) => a['artist_name'] as String).toList();
      _dailyMixes = [];
      for (var artist in topArtists) {
        _dailyMixes.add(Track(
          title: '$artist Mix',
          artist: artist,
          album: '',
          artworkUrl: '',
          duration: 0,
          collectionId: 'mix_$artist',
        ));
      }
    } catch (e) {
      debugPrint('[LIB] dailyMixes error: $e');
    }
    notifyListeners();
  }

  Future<void> fetchNewReleases(int profileId) async {
    try {
      var artists = await database.getProfileArtists(profileId);
      _newReleases = [];
      for (var artist in artists.take(10)) {
        _newReleases.add(Track(
          title: 'New from $artist',
          artist: artist,
          album: '',
          artworkUrl: '',
          duration: 0,
          collectionId: 'new_$artist',
        ));
      }
    } catch (e) {
      debugPrint('[LIB] newReleases error: $e');
    }
    notifyListeners();
  }
}
