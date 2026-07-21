import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/audio_service.dart';
import '../services/recommendation_service.dart';
import '../services/interfaces/database_interface.dart';
import '../services/interfaces/ytdlp_interface.dart';
import 'queue_manager.dart';
import 'profile_manager.dart';
import 'library_manager.dart';

class AppState extends ChangeNotifier {
  final AudioService audio;
  final QueueManager queueMgr;
  final ProfileManager profile;
  final LibraryManager library;

  StreamSubscription? _trackSub;

  AppState({
    required DatabaseInterface database,
    required YtDlpInterface ytDlp,
  }) : audio = AudioService(),
       queueMgr = QueueManager(audio: AudioService(), ytDlp: ytDlp),
       profile = ProfileManager(database: database),
       library = LibraryManager(database: database) {
    _trackSub = audio.trackController.stream.listen((t) {
      if (t != null) notifyListeners();
    });
    audio.onTrackCompleted = () async {
      var t = queueMgr.currentTrack;
      if (t != null) {
        await logPlay(t, audio.duration, true, false);
      }
      if (queueMgr.queueIndex >= queueMgr.queue.length - 2) {
        await queueMgr.injectRelatedTracks();
      }
      await queueMgr.next();
    };
  }

  // --- Delegated getters ---

  int? get profileId => profile.profileId;
  List<String> get profileArtists => profile.profileArtists;
  bool get isOnboarded => profile.isOnboarded;
  List<Track> get queue => queueMgr.queue;
  int get queueIndex => queueMgr.queueIndex;
  Track? get currentTrack => queueMgr.currentTrack;
  Map<String, dynamic> get suggestions => library.suggestions;
  List<Map<String, dynamic>> get recentlyPlayed => library.recentlyPlayed;
  List<Map<String, dynamic>> get playlists => library.playlists;

  // --- Coordinated operations ---

  Future<void> loadProfile(int id) => profile.loadProfile(id);

  Future<int> createProfile(String name, List<String> languages) =>
      profile.createProfile(name, languages);

  Future<void> saveArtists(List<String> artists) async {
    await profile.saveArtists(artists);
    if (profile.profileId != null) {
      await RecommendationService.recalculateAffinities(profile.profileId!);
      await refresh();
    }
    notifyListeners();
  }

  Future<void> logPlay(Track t, double duration, bool completed,
      bool skipped) async {
    if (profile.profileId == null) return;
    await library.logPlay(profile.profileId!, t, duration, completed, skipped);
    await refresh();
    notifyListeners();
  }

  Future<void> refresh() async {
    await library.refresh(
      profileId: profile.profileId,
      anchorYoutubeId: audio.lastYoutubeId,
      anchorTrack: queueMgr.currentTrack,
    );
  }

  // --- Queue operations ---

  void enqueue(Track t) => queueMgr.enqueue(t);
  void enqueueNext(Track t) => queueMgr.enqueueNext(t);
  Future<void> playIndex(int index) => queueMgr.playIndex(index);
  Future<void> playNow(Track t) => queueMgr.playNow(t);
  Future<void> next() => queueMgr.next();
  Future<void> prev() => queueMgr.prev();
  void removeFromQueue(int index) => queueMgr.removeFromQueue(index);
  void clearQueue() => queueMgr.clearQueue();

  Map<String, dynamic> getInjectReason(Track t) {
    return {
      'source': 'related',
      'anchor': queueMgr.currentTrack?.title ?? 'unknown',
    };
  }

  @override
  void dispose() {
    _trackSub?.cancel();
    audio.dispose();
    super.dispose();
  }
}
