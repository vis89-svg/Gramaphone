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
    _sessionHeard.add(_normalizeKey(t));
    _queue.add(t);
    notifyListeners();
  }

  void enqueueNext(Track t) {
    _sessionHeard.add(_normalizeKey(t));
    _queue.add(t);
    notifyListeners();
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queueIndex = index;
    var t = _queue[index];
    _sessionHeard.add(_normalizeKey(t));
    await audio.play(t);
    notifyListeners();
  }

  Future<void> playNow(Track t) async {
    _sessionHeard.add(_normalizeKey(t));
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
      debugPrint('[INJECT] anchor="${anchorTrack.title}" vid=$vid idx=$_queueIndex len=${_queue.length}');
      List<Track> related;
      if (vid != null) {
        related = await ytDlp.getRelated(vid, limit: 12);
      } else {
        related = await ytDlp.search(
            '${anchorTrack.title} ${anchorTrack.artist}', limit: 12);
      }
      debugPrint('[INJECT] related returned ${related.length} tracks');
      var count = 0;
      for (var r in related) {
        var nk = _normalizeKey(r);
        var dup = _isDuplicateOfHeard(r);
        debugPrint('[INJECT] candidate="${r.title}" | "${r.artist}" yt=${r.youtubeId} key="$nk" dup=$dup heardSize=${_sessionHeard.length}');
        if (dup) continue;
        _sessionHeard.add(nk);
        _queue.add(r);
        count++;
        debugPrint('[INJECT] ADDED (count=$count)');
        if (count >= 3) break;
      }
      debugPrint('[INJECT] done — added $count tracks');
      notifyListeners();
    } catch (e) {
      debugPrint('[INJECT] error: $e');
    }
  }

  bool _isDuplicateOfHeard(Track t) {
    var nk = _normalizeKey(t);
    if (_sessionHeard.contains(nk)) return true;
    for (var k in _sessionHeard) {
      var hTitle = k.split('||')[0];
      var hArtist = k.split('||').length > 1 ? k.split('||')[1] : '';
      var nTitle = nk.split('||')[0];
      var nArtist = nk.split('||').length > 1 ? nk.split('||')[1] : '';
      if (hArtist != nArtist) continue;
      if (_levenshtein(hTitle, nTitle) <= 2) {
        debugPrint('[INJECT] fuzzy match: "$hTitle" ~ "$nTitle"');
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

  String _normalizeKey(Track t) {
    var title = t.title
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .replaceAll(RegExp(r'\s*\[[^\]]*\]\s*$'), '')
        .replaceAll(RegExp(r'\s*[-–—|]\s*Official\s+(Video|Audio|Music|Lyrics).*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(Official\s+(Video|Audio|Music|Lyrics).*$', caseSensitive: false), '')
        .trim()
        .toLowerCase();
    var artist = t.artist
        .replaceAll(RegExp(r'\s*[-–—|•·]\s*(Topic|VEVO|Topic Channel|Official|Audio|Music)\s*$', caseSensitive: false), '')
        .split(RegExp(r'\s*[,&/]\s*|\s+feat[.\s]|\s+ft[.\s]'))[0]
        .trim()
        .toLowerCase();
    return '$title||$artist';
  }
}
