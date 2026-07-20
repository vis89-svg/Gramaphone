import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import '../services/audio_service.dart';
import '../services/recommendation_service.dart';

class AppState extends ChangeNotifier {
  int? _profileId;
  List<String> _profileArtists = [];
  final List<Track> _queue = [];
  int _queueIndex = -1;
  bool _isOnboarded = false;
  Map<String, dynamic> _suggestions = {};
  List<Map<String, dynamic>> _recentlyPlayed = [];
  List<Map<String, dynamic>> _playlists = [];

  int? get profileId => _profileId;
  List<String> get profileArtists => _profileArtists;
  List<Track> get queue => _queue;
  int get queueIndex => _queueIndex;
  bool get isOnboarded => _isOnboarded;
  Map<String, dynamic> get suggestions => _suggestions;
  List<Map<String, dynamic>> get recentlyPlayed => _recentlyPlayed;
  List<Map<String, dynamic>> get playlists => _playlists;
  Track? get currentTrack =>
      _queueIndex >= 0 && _queueIndex < _queue.length
          ? _queue[_queueIndex]
          : null;

  final AudioService audio = AudioService();
  StreamSubscription? _trackSub;

  AppState() {
    _trackSub = audio.trackController.stream.listen((t) {
      if (t != null) notifyListeners();
    });
  }

  Future<void> loadProfile(int id) async {
    _profileId = id;
    _profileArtists = await DatabaseService.getProfileArtists(id);
    _isOnboarded = _profileArtists.length >= 3;
    await refresh();
    notifyListeners();
  }

  Future<int> createProfile(String name, List<String> languages) async {
    var id = await DatabaseService.ensureProfile(name, languages);
    await loadProfile(id);
    return id;
  }

  Future<void> saveArtists(List<String> artists) async {
    if (_profileId == null) return;
    await DatabaseService.saveProfileArtists(_profileId!, artists);
    _profileArtists = artists;
    _isOnboarded = artists.length >= 3;
    await RecommendationService.recalculateAffinities(_profileId!);
    await refresh();
    notifyListeners();
  }

  Future<void> logPlay(Track t, double duration, bool completed,
      bool skipped) async {
    if (_profileId == null) return;
    await DatabaseService.logPlay(_profileId!, t, duration, completed, skipped);
    await RecommendationService.recalculateAffinities(_profileId!);
    await refresh();
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_profileId == null) return;
    _suggestions = await RecommendationService.getSuggestions(
      _profileId!,
      anchorYoutubeId: audio.lastYoutubeId,
      anchorTrack: currentTrack,
    );
    var history =
        await DatabaseService.getListeningHistory(_profileId!, limit: 20);
    _recentlyPlayed = history;
    _playlists = await DatabaseService.getPlaylists(_profileId!);
    notifyListeners();
  }

  void enqueue(Track t) {
    _queue.add(t);
    notifyListeners();
  }

  void enqueueNext(Track t) {
    var idx = _queueIndex + 1;
    if (idx >= _queue.length) {
      _queue.add(t);
    } else {
      _queue.insert(idx, t);
    }
    notifyListeners();
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queueIndex = index;
    var t = _queue[index];
    await audio.play(t);
    notifyListeners();
  }

  Future<void> playNow(Track t) async {
    _queue.insert(0, t);
    _queueIndex = 0;
    await audio.play(t);
    notifyListeners();
  }

  Future<void> next() async {
    if (_queueIndex < _queue.length - 1) {
      await playIndex(_queueIndex + 1);
    }
  }

  Future<void> prev() async {
    if (_queueIndex > 0) {
      await playIndex(_queueIndex - 1);
    }
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (index <= _queueIndex) _queueIndex--;
      notifyListeners();
    }
  }

  void clearQueue() {
    _queue.clear();
    _queueIndex = -1;
    notifyListeners();
  }

  @override
  void dispose() {
    _trackSub?.cancel();
    audio.dispose();
    super.dispose();
  }
}
