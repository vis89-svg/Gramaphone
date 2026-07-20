import 'dart:async';
import 'dart:io';
import 'dart:ui' show VoidCallback;
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart' as model;

class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  final player = Player();
  final yt = YoutubeExplode();

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

  VoidCallback? onTrackChanged;

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
  }

  Future<String?> _getAudioUrl(model.Track t) async {
    var query = '${t.title} ${t.artist}';
    try {
      var r = await Process.run('python', [
        '-m', 'yt_dlp',
        '-g',
        '--format', 'bestaudio',
        '--default-search', 'ytsearch',
        '--', query,
      ]);
      if (r.exitCode == 0) {
        var url = (r.stdout as String).trim();
        if (url.isNotEmpty) return url;
      }
    } catch (_) {}
    var queries = [
      '$query audio',
      '$query',
      '${t.artist} ${t.title} lyrics',
      '$query official',
    ];
    var seen = <String>{};
    for (var q in queries) {
      try {
        var search = await yt.search.search(q);
        for (var video in search.take(5)) {
          if (!seen.add(video.id.value)) continue;
          var manifest =
              await yt.videos.streamsClient.getManifest(video.id.value);
          var audio = manifest.audioOnly.toList();
          if (audio.isNotEmpty) {
            audio.sort((a, b) => b.bitrate.compareTo(a.bitrate));
            return audio.first.url.toString();
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
      var url = await _getAudioUrl(t);
      if (url == null) {
        _isLoading = false;
        _playbackError = 'Audio not found on YouTube';
        loadingController.add(false);
        errorController.add('Could not find audio for "${t.title}" by ${t.artist}');
        return;
      }
      await player.stop();
      await player.open(Media(url));
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
    player.dispose();
    yt.close();
    positionController.close();
    playStateController.close();
    trackController.close();
    loadingController.close();
    errorController.close();
  }
}
