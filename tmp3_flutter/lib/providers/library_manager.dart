import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/interfaces/database_interface.dart';
import '../services/interfaces/ytdlp_interface.dart';
import '../services/recommendation_service.dart';
import '../services/itunes_service.dart';

class LibraryManager extends ChangeNotifier {
  final DatabaseInterface database;

  LibraryManager({required this.database});

  Map<String, dynamic> _suggestions = {};
  List<Map<String, dynamic>> _recentlyPlayed = [];
  List<Map<String, dynamic>> _heavyRotation = [];
  List<Map<String, dynamic>> _playlists = [];
  List<Track> _artistMixes = [];
  List<Track> _newReleases = [];
  List<Track> _forYouMixes = [];
  Map<String, List<String>> _forYouClusters = {};

  Map<String, dynamic> get suggestions => _suggestions;
  List<Map<String, dynamic>> get recentlyPlayed => _recentlyPlayed;
  List<Map<String, dynamic>> get heavyRotation => _heavyRotation;
  List<Map<String, dynamic>> get playlists => _playlists;
  List<Track> get artistMixes => _artistMixes;
  List<Track> get newReleases => _newReleases;
  List<Track> get forYouMixes => _forYouMixes;
  Map<String, List<String>> get forYouClusters => _forYouClusters;

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

  Future<void> generateArtistMixes(int profileId) async {
    try {
      var affs = await database.getAffinities(profileId, limit: 12);
      var topArtists = affs.take(4).map((a) => a['artist_name'] as String).toList();
      _artistMixes = [];
      for (var artist in topArtists) {
        var art = await ItunesService.getArtistArtwork(artist);
        _artistMixes.add(Track(
          title: '$artist Mix',
          artist: artist,
          album: '',
          artworkUrl: art ?? '',
          duration: 0,
          collectionId: 'mix_$artist',
        ));
      }
    } catch (e) {
      debugPrint('[LIB] artistMixes error: $e');
    }
    notifyListeners();
  }

  Future<void> generateForYouMixes(int profileId) async {
    try {
      var affs = await database.getAffinities(profileId, limit: 15);
      var topArtists = affs.map((a) => a['artist_name'] as String).toList();
      Map<String, List<String>> genreGroups = {};
      for (var artist in topArtists) {
        var g = await ItunesService.getArtistGenre(artist);
        var genre = g ?? 'Pop';
        genreGroups.putIfAbsent(genre, () => []);
        if (genreGroups[genre]!.length < 5) {
          genreGroups[genre]!.add(artist);
        }
      }
      var sorted = genreGroups.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      _forYouMixes = [];
      _forYouClusters = {};
      for (var entry in sorted.take(6)) {
        if (entry.value.isEmpty) continue;
        var art = await ItunesService.getArtistArtwork(entry.key);
        var desc = entry.value.take(3).join(', ');
        _forYouMixes.add(Track(
          title: '${entry.key} Mix',
          artist: desc + (entry.value.length > 3 ? ' +${entry.value.length - 3} more' : ''),
          artworkUrl: art ?? '',
          collectionId: 'foryou_${entry.key}',
        ));
        _forYouClusters['foryou_${entry.key}'] = entry.value;
      }
    } catch (e) {
      debugPrint('[LIB] forYouMixes error: $e');
    }
    notifyListeners();
  }

  Future<void> fetchNewReleases(int profileId, {YtDlpInterface? ytDlp}) async {
    try {
      var topAffs = await database.getAffinities(profileId, limit: 20);
      var topArtists = topAffs.map((a) => a['artist_name'] as String).toList();
      var followed = await database.getProfileArtists(profileId);
      // Merge: top artists first, then followed, deduplicate preserving order
      var all = <String>[];
      var seen = <String>{};
      for (var a in [...topArtists, ...followed]) {
        if (seen.add(a)) all.add(a);
      }

      _newReleases = [];
      Set<String> dedup = {};
      for (var artist in all.take(10)) {
        if (ytDlp == null) {
          var art = await ItunesService.getArtistArtwork(artist);
          _newReleases.add(Track(
            title: 'New from $artist',
            artist: artist,
            artworkUrl: art ?? '',
            collectionId: 'new_$artist',
          ));
          continue;
        }
        var topic = await ytDlp.searchAudio(artist, limit: 3);
        for (var t in topic) {
          if (t.duration > 30 && t.duration < 600 && dedup.add(t.dbKey)) {
            _newReleases.add(t);
          }
        }
      }
    } catch (e) {
      debugPrint('[LIB] newReleases error: $e');
    }
    notifyListeners();
  }
}
