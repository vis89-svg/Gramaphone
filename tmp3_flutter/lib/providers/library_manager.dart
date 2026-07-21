import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/interfaces/database_interface.dart';
import '../services/recommendation_service.dart';

class LibraryManager extends ChangeNotifier {
  final DatabaseInterface database;

  LibraryManager({required this.database});

  Map<String, dynamic> _suggestions = {};
  List<Map<String, dynamic>> _recentlyPlayed = [];
  List<Map<String, dynamic>> _playlists = [];

  Map<String, dynamic> get suggestions => _suggestions;
  List<Map<String, dynamic>> get recentlyPlayed => _recentlyPlayed;
  List<Map<String, dynamic>> get playlists => _playlists;

  Future<void> refresh({
    int? profileId,
    String? anchorYoutubeId,
    Track? anchorTrack,
  }) async {
    if (profileId == null) return;
    _suggestions = await RecommendationService.getSuggestions(
      profileId,
      anchorYoutubeId: anchorYoutubeId,
      anchorTrack: anchorTrack,
    );
    var history = await database.getListeningHistory(profileId, limit: 20);
    _recentlyPlayed = history;
    _playlists = await database.getPlaylists(profileId);
    notifyListeners();
  }

  Future<void> logPlay(int profileId, Track t, double duration,
      bool completed, bool skipped) async {
    await database.logPlay(profileId, t, duration, completed, skipped);
    await RecommendationService.recalculateAffinities(profileId);
  }
}
