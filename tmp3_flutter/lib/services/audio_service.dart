import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show VoidCallback;
import 'package:media_kit/media_kit.dart' hide Track;
import '../models/track.dart' as model;

class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

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
  }

  Future<_YtResult?> _getAudioUrl(model.Track t) async {
    var queries = [
      '${t.title} ${t.artist} topic',
      '${t.title} ${t.artist} official audio',
      '${t.title} ${t.artist} official',
      '${t.artist} - ${t.title}',
      '${t.title} ${t.artist}',
    ];
    for (var q in queries) {
      try {
        var r = await Process.run('python', [
          '-m', 'yt_dlp',
          '--dump-json',
          '--format', 'bestaudio',
          '--default-search', 'ytsearch',
          '--', q,
        ]);
        if (r.exitCode == 0) {
          var line = (r.stdout as String).trim();
          if (line.isEmpty) continue;
          var j = json.decode(line);
          var url = j['url'] as String?;
          var id = j['id'] as String?;
          if (url != null && url.isNotEmpty) {
            return _YtResult(url: url, videoId: id);
          }
        }
      } catch (_) {
        continue;
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
      var result = await _getAudioUrl(t);
      if (result == null) {
        _isLoading = false;
        _playbackError = 'Audio not found on YouTube';
        loadingController.add(false);
        errorController.add('Could not find audio for "${t.title}" by ${t.artist}');
        return;
      }
      _lastYoutubeId = result.videoId;
      await player.stop();
      await player.open(Media(result.url));
      await player.play();
      _currentTrack = t;
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
    } else {
      await player.play();
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

class _YtResult {
  final String url;
  final String? videoId;
  _YtResult({required this.url, this.videoId});
}
