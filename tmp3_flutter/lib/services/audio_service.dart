import 'dart:async';
import 'dart:ui' show VoidCallback;
import 'package:media_kit/media_kit.dart' hide Track;
import '../models/track.dart' as model;
import 'ytdlp_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  final _ytDlp = YtDlpService();

  final player = Player();

  model.Track? _currentTrack;
  model.Track? get currentTrack => _currentTrack;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  double _position = 0;
  double get position => _position;

  double _duration = 0;
  double get duration => _duration;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  final StreamController<double> positionController =
      StreamController<double>.broadcast();
  final StreamController<bool> playStateController =
      StreamController<bool>.broadcast();
  final StreamController<model.Track?> trackController =
      StreamController<model.Track?>.broadcast();
  final StreamController<bool> loadingController =
      StreamController<bool>.broadcast();
  final StreamController<String?> errorController =
      StreamController<String?>.broadcast();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _playbackError;
  String? get playbackError => _playbackError;

  String? _lastYoutubeId;
  String? get lastYoutubeId => _lastYoutubeId;

  VoidCallback? onTrackChanged;
  VoidCallback? onTrackCompleted;

  StreamSubscription? _complSub;

  // Sleep timer
  Timer? _sleepTick;
  DateTime? _sleepEndTime;
  final StreamController<Duration?> _sleepTimerController =
      StreamController<Duration?>.broadcast();
  Stream<Duration?> get sleepTimerStream => _sleepTimerController.stream;
  Duration? get sleepTimerRemaining => _sleepEndTime?.difference(DateTime.now());

  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepEndTime = DateTime.now().add(duration);
    _sleepTimerController.add(duration);
    _sleepTick = Timer.periodic(const Duration(seconds: 1), (_) {
      var remaining = _sleepEndTime?.difference(DateTime.now());
      if (remaining == null || remaining.isNegative) {
        if (_isPlaying) {
          player.pause();
          _isPlaying = false;
          playStateController.add(false);
        }
        _sleepEndTime = null;
        _sleepTimerController.add(null);
        _sleepTick?.cancel();
        _sleepTick = null;
        return;
      }
      _sleepTimerController.add(remaining);
    });
  }

  void cancelSleepTimer() {
    _sleepTick?.cancel();
    _sleepTick = null;
    _sleepEndTime = null;
    _sleepTimerController.add(null);
  }

  Future<void> init() async {
    _posSub = player.stream.position.listen((p) {
      _position = p.inSeconds.toDouble();
      positionController.add(_position);
    });
    _durSub = player.stream.duration.listen((d) {
      _duration = d.inSeconds.toDouble();
    });
    _stateSub = player.stream.playing.listen((p) {
      _isPlaying = p;
      playStateController.add(p);
    });
    _complSub = player.stream.completed.listen((_) {
      onTrackCompleted?.call();
    });
    player.stream.log.listen((l) {
      print('[MPV] ${l.text}');
    });
    player.stream.error.listen((e) {
      print('[MPV_ERROR] $e');
    });
  }

  Future<String?> _getAudioUrl(model.Track t) async {
    if (t.youtubeId != null && t.youtubeId!.isNotEmpty) {
      var url = await _ytDlp.getAudioUrl(t.youtubeId!);
      if (url != null) {
        _lastYoutubeId = t.youtubeId;
        return url;
      }
    }
    var results = await _ytDlp.searchAudio(
      '${t.artist} - ${t.title}',
      limit: 5,
    );
    for (var r in results) {
      if (r.youtubeId == null || r.youtubeId!.isEmpty) continue;
      var url = await _ytDlp.getAudioUrl(r.youtubeId!);
      if (url != null) {
        _lastYoutubeId = r.youtubeId;
        return url;
      }
    }
    return null;
  }

  Future<void> play(model.Track t) async {
    _isLoading = true;
    _playbackError = null;
    loadingController.add(true);
    trackController.add(t);
    try {
      var url = await _getAudioUrl(t);
      if (url == null) {
        _isLoading = false;
        _playbackError = 'Audio not found on YouTube';
        loadingController.add(false);
        errorController.add('Could not find audio for "${t.title}" by ${t.artist}');
        return;
      }
      await player.setVolume(100);
      await player.stop();
      await player.open(Media(url));
      _currentTrack = t;
      _isPlaying = true;
      playStateController.add(true);
      _playbackError = null;
    } catch (e) {
      _playbackError = 'Playback error';
      errorController.add('Failed to play "${t.title}": $e');
    }
    _isLoading = false;
    loadingController.add(false);
    trackController.add(t);
    onTrackChanged?.call();
  }

  Future<void> playPause() async {
    if (_isPlaying) {
      await player.pause();
      _isPlaying = false;
      playStateController.add(false);
    } else {
      await player.play();
      _isPlaying = true;
      playStateController.add(true);
    }
  }

  Future<void> seek(double seconds) async {
    await player.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  Future<void> setVolume(int vol) async {
    await player.setVolume(vol.toDouble());
  }

  Future<void> stop() async {
    await player.stop();
    _currentTrack = null;
    trackController.add(null);
  }

  void dispose() {
    _sleepTick?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _complSub?.cancel();
    player.dispose();
    positionController.close();
    playStateController.close();
    trackController.close();
    loadingController.close();
    errorController.close();
  }
}


