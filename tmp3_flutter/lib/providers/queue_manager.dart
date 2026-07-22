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

  final Set<String> _sessionHeard = {};

  List<Track> get queue => _queue;
  int get queueIndex => _queueIndex;
  Track? get currentTrack =>
      _queueIndex >= 0 && _queueIndex < _queue.length
          ? _queue[_queueIndex]
          : null;

  void enqueue(Track t) {
    _sessionHeard.add(_sessionKey(t));
    _queue.add(t);
    notifyListeners();
  }

  void enqueueNext(Track t) {
    _sessionHeard.add(_sessionKey(t));
    _queue.add(t);
    notifyListeners();
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queueIndex = index;
    var t = _queue[index];
    _sessionHeard.add(_sessionKey(t));
    await audio.play(t);
    notifyListeners();
  }

  Future<void> playNow(Track t) async {
    _queue.clear();
    _sessionHeard.add(_sessionKey(t));
    _queue.add(t);
    _queueIndex = 0;
    await audio.play(t);
    notifyListeners();
  }

  Future<void> next() async {
    if (_queueIndex < _queue.length - 1) {
      await playIndex(_queueIndex + 1);
    } else {
      await injectRelatedTracks(interleave: false);
      if (_queueIndex < _queue.length - 1) {
        await playIndex(_queueIndex + 1);
      }
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

  Future<void> injectRelatedTracks({bool interleave = false}) async {
    try {
      var anchorTrack = currentTrack;
      if (anchorTrack == null) return;
      var vid = audio.lastYoutubeId;
      debugPrint('[INJECT] anchor="${anchorTrack.title}" vid=$vid idx=$_queueIndex len=${_queue.length}');
      List<Track> related;
      if (vid != null) {
        related = await ytDlp.getRelated(vid, limit: 12);
      } else {
        related = await ytDlp.searchAudio(
            '${anchorTrack.title} ${anchorTrack.artist}', limit: 12);
      }
      debugPrint('[INJECT] related returned ${related.length} tracks');
      var count = 0;
      for (var r in related) {
        var sk = _sessionKey(r);
        var nk = _normalizeKey(r);
        var dup = _isDuplicateOfHeard(r);
        debugPrint('[INJECT] candidate="${r.title}" | "${r.artist}" yt=${r.youtubeId} key="$nk" sk="$sk" dup=$dup heardSize=${_sessionHeard.length}');
        if (dup) continue;
        _sessionHeard.add(sk);
        if (interleave && _queueIndex >= 0) {
          var insertAt = _queueIndex + count + 1;
          if (insertAt > _queue.length) insertAt = _queue.length;
          _queue.insert(insertAt, r);
        } else {
          _queue.add(r);
        }
        count++;
        debugPrint('[INJECT] ADDED (count=$count) interleave=$interleave');
        if (count >= 3) break;
      }
      debugPrint('[INJECT] done — added $count tracks');
      notifyListeners();
    } catch (e) {
      debugPrint('[INJECT] error: $e');
    }
  }

  bool _isDuplicateOfHeard(Track t) {
    var tYt = t.youtubeId;
    for (var k in _sessionHeard) {
      var parts = k.split('||');
      if (parts.length >= 3 && parts[0].isNotEmpty && tYt != null && tYt.isNotEmpty && parts[0] == tYt) {
        debugPrint('[INJECT] yt dup: $tYt');
        return true;
      }
    }
    var nk = _normalizeKey(t);
    for (var k in _sessionHeard) {
      var parts = k.split('||');
      var kTitle = parts.length >= 3 ? parts[1] : parts[0];
      var kArtist = parts.length >= 3 ? parts[2] : (parts.length > 1 ? parts[1] : '');
      var nTitle = nk.split('||')[0];
      var nArtist = nk.split('||').length > 1 ? nk.split('||')[1] : '';
      if (kArtist != nArtist) continue;
      if (_levenshtein(kTitle, nTitle) <= 2) {
        debugPrint('[INJECT] fuzzy match: "$kTitle" ~ "$nTitle"');
        return true;
      }
    }
    return false;
  }

  int _levenshtein(String a, String b) {
    if (a.length < b.length) {
      var tmp = a;
      a = b;
      b = tmp;
    }
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        var cost = a[i] == b[j] ? 0 : 1;
        curr[j + 1] = [
          curr[j] + 1,
          prev[j + 1] + 1,
          prev[j] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      var tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev.last;
  }

  String _sessionKey(Track t) {
    var yt = t.youtubeId ?? '';
    var nk = _normalizeKey(t);
    return '$yt||$nk';
  }

  String _normalizeKey(Track t) {
    var title = t.title
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .replaceAll(RegExp(r'\s*\[[^\]]*\]\s*$'), '')
        .replaceAll(RegExp(r'\s*[-–—|]\s*Official\s+(Video|Audio|Music|Lyrics).*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Official\s+(Video|Audio|Music|Lyrics).*$', caseSensitive: false), '')
        .trim()
        .toLowerCase();
    var artist = t.artist
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll(RegExp(r'\s*[-–—|•·]\s*(Topic|Topic Channel)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+VEVO\s*$', caseSensitive: false), '')
        .split(RegExp(r'\s*[,&/]\s*|\s+feat[.\s]|\s+ft[.\s]'))[0]
        .trim()
        .toLowerCase();
    return '$title||$artist';
  }
}
