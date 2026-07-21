import 'package:flutter/foundation.dart';
import '../models/track.dart';
import '../services/audio_service.dart';
import '../services/interfaces/ytdlp_interface.dart' show YtDlpInterface;

class QueueManager extends ChangeNotifier {
  final AudioService audio;
  final YtDlpInterface ytDlp;

  QueueManager({required this.audio, required this.ytDlp});

  final List<Track> _queue = [];
  int _queueIndex = -1;

  List<Track> get queue => _queue;
  int get queueIndex => _queueIndex;
  Track? get currentTrack =>
      _queueIndex >= 0 && _queueIndex < _queue.length
          ? _queue[_queueIndex]
          : null;

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

  Future<void> injectRelatedTracks() async {
    try {
      var anchorTrack = currentTrack;
      if (anchorTrack == null) return;
      var vid = audio.lastYoutubeId;
      List<Track> related;
      if (vid != null) {
        related = await ytDlp.getRelated(vid, limit: 6);
      } else {
        related = await ytDlp.search(
            '${anchorTrack.title} ${anchorTrack.artist}', limit: 6);
      }
      var heard = <String>{};
      for (var q in _queue) {
        heard.add(q.dbKey);
      }
      var count = 0;
      for (var r in related) {
        if (heard.add(r.dbKey)) {
          enqueueNext(r);
          count++;
        }
        if (count >= 3) break;
      }
    } catch (_) {}
  }
}
