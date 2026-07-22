import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/app_state.dart';
import '../screens/mix_screen.dart';
import '../screens/queue_screen.dart';
import '../services/lyrics_service.dart';
import '../widgets/artwork.dart';
import '../app.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  double _pos = 0;
  double _dur = 0;
  double _vol = 100;
  bool _playing = false;
  bool _loading = false;
  bool _showLyrics = false;
  List<LyricsLine>? _lyrics;
  StreamSubscription? _posSub;
  StreamSubscription? _playSub;
  StreamSubscription? _loadSub;

  @override
  void initState() {
    super.initState();
    var a = context.read<AppState>().audio;
    _pos = a.position;
    _dur = a.duration;
    _playing = a.isPlaying;
    _loading = a.isLoading;
    _posSub = a.positionController.stream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _playSub = a.playStateController.stream.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    _loadSub = a.loadingController.stream.listen((l) {
      if (mounted) setState(() => _loading = l);
    });
    _fetchLyrics();
  }

  Future<void> _fetchLyrics() async {
    var track = context.read<AppState>().currentTrack;
    if (track == null) return;
    var l = await LyricsService.getSynced(track.title, track.artist);
    if (mounted) setState(() => _lyrics = l);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
    _loadSub?.cancel();
    super.dispose();
  }

  String _fmt(double s) {
    if (s <= 0) return '0:00';
    var m = (s ~/ 60).toInt();
    var sec = (s % 60).toInt();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    var state = context.watch<AppState>();
    var track = state.currentTrack;

    return Scaffold(
      backgroundColor: Tmp3App.bg,
      appBar: AppBar(
        backgroundColor: Tmp3App.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Tmp3App.txt),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          track != null ? 'Now Playing' : '',
          style: const TextStyle(color: Tmp3App.txt3, fontSize: 13),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              state.smartShuffle ? Icons.shuffle_on : Icons.shuffle,
              color: state.smartShuffle ? Tmp3App.green : Tmp3App.txt3,
            ),
            onPressed: () => state.toggleSmartShuffle(),
          ),
        ],
      ),
      body: track == null
          ? const Center(
              child: Text('No track playing',
                  style: TextStyle(color: Tmp3App.txt3)))
          : _buildBody(track, state),
    );
  }

  Widget _buildBody(Track track, AppState state) {
    var a = state.audio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // Artwork or Lyrics
          _showLyrics && _lyrics != null && _lyrics!.isNotEmpty
              ? _buildLyrics()
              : Artwork(track.effectiveArtworkUrl, size: 280, borderRadius: 16),
          const SizedBox(height: 24),
          // Title + Artist
          GestureDetector(
            onTap: () => setState(() => _showLyrics = !_showLyrics),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Column(
                    children: [
                      Text(track.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Tmp3App.txt,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(track.artist,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: Tmp3App.txt2, fontSize: 15)),
                    ],
                  ),
                ),
                if (_lyrics != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      _showLyrics ? Icons.lyrics : Icons.music_note,
                      color: Tmp3App.txt3, size: 18),
                  ),
              ],
            ),
          ),
          const Spacer(),
          // Seek bar
          Row(
            children: [
              Text(_fmt(_pos),
                  style: const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Tmp3App.green,
                    inactiveTrackColor: Tmp3App.elev,
                    thumbColor: Tmp3App.green,
                  ),
                  child: Slider(
                    value: _dur > 0 ? _pos.clamp(0, _dur) : 0,
                    max: _dur > 0 ? _dur : 1,
                    onChanged: (v) => a.seek(v),
                  ),
                ),
              ),
              Text(_fmt(_dur),
                  style: const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded,
                    color: Tmp3App.txt, size: 36),
                onPressed: () => state.prev(),
              ),
              const SizedBox(width: 16),
              _loading
                  ? const SizedBox(
                      width: 56,
                      height: 56,
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Tmp3App.green)))
                  : Container(
                      decoration: const BoxDecoration(
                        color: Tmp3App.green,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Tmp3App.bg, size: 32),
                        onPressed: () => a.playPause(),
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded,
                    color: Tmp3App.txt, size: 36),
                onPressed: () => state.next(),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Volume
          Row(
            children: [
              const Icon(Icons.volume_down_rounded, color: Tmp3App.txt3, size: 18),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Tmp3App.txt3,
                    inactiveTrackColor: Tmp3App.elev,
                    thumbColor: Tmp3App.txt3,
                  ),
                  child: Slider(
                    value: _vol,
                    max: 100,
                    onChanged: (v) {
                      setState(() => _vol = v);
                      a.setVolume(v.toInt());
                    },
                  ),
                ),
              ),
              const Icon(Icons.volume_up_rounded, color: Tmp3App.txt3, size: 18),
            ],
          ),
          const SizedBox(height: 20),
          // Bottom actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionBtn(Icons.radio_rounded, 'Radio', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MixScreen(
                    artist: track.artist,
                    seedTrack: track,
                  )),
                );
              }),
              _actionBtn(Icons.queue_music_rounded, 'Queue', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QueueScreen()),
                );
              }),
              _actionBtn(Icons.timer_outlined, 'Sleep', () {
                _showSleepTimerDialog(context);
              }),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildLyrics() {
    if (_lyrics == null || _lyrics!.isEmpty) {
      return const SizedBox(height: 280);
    }
    var hasSynced = _lyrics!.any((l) => l.time >= 0);
    var currentIdx = -1;
    if (hasSynced) {
      for (var i = 0; i < _lyrics!.length; i++) {
        if (_lyrics![i].time > _pos) break;
        currentIdx = i;
      }
    }
    return SizedBox(
      height: 280,
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Tmp3App.bg.withValues(alpha: 0),
            Tmp3App.bg.withValues(alpha: 1),
            Tmp3App.bg.withValues(alpha: 1),
            Tmp3App.bg.withValues(alpha: 0),
          ],
          stops: const [0, 0.05, 0.85, 1],
        ).createShader(bounds),
        blendMode: BlendMode.dstOut,
        child: ListView(
          children: _lyrics!.asMap().entries.map((e) {
            var i = e.key;
            var l = e.value;
            var isCurrent = hasSynced && i == currentIdx;
            return AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isCurrent ? Tmp3App.green : Tmp3App.txt3,
                fontSize: isCurrent ? 17 : 14,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                height: 1.8,
              ),
              child: Text(l.text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Tmp3App.txt2, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Tmp3App.txt3, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showSleepTimerDialog(BuildContext ctx) {
    var audio = context.read<AppState>().audio;
    if (audio.sleepTimerRemaining != null) {
      audio.cancelSleepTimer();
      return;
    }
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Tmp3App.side,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bc) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sleep Timer',
                  style: TextStyle(
                      color: Tmp3App.txt,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...[5, 10, 15, 30, 60].map((m) => ListTile(
                title: Text('$m minutes',
                    style: const TextStyle(color: Tmp3App.txt)),
                trailing: const Icon(Icons.timer_outlined,
                    color: Tmp3App.green),
                onTap: () {
                  audio.setSleepTimer(Duration(minutes: m));
                  Navigator.pop(bc);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}
