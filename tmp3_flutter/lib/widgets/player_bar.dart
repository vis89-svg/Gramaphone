import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/app_state.dart';
import '../screens/mix_screen.dart';
import '../app.dart';

class PlayerBar extends StatefulWidget {
  const PlayerBar({super.key});

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  double _pos = 0;
  StreamSubscription? _posSub;
  StreamSubscription? _playSub;
  StreamSubscription? _loadSub;
  StreamSubscription? _sleepSub;
  Duration? _sleepTimerRemaining;

  @override
  void initState() {
    super.initState();
    var audio = context.read<AppState>().audio;
    _posSub = audio.positionController.stream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _playSub = audio.playStateController.stream.listen((_) {
      if (mounted) setState(() {});
    });
    _loadSub = audio.loadingController.stream.listen((_) {
      if (mounted) setState(() {});
    });
    _sleepSub = audio.sleepTimerStream.listen((d) {
      if (mounted) setState(() => _sleepTimerRemaining = d);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
    _loadSub?.cancel();
    _sleepSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var state = context.watch<AppState>();
    var track = state.currentTrack;
    if (track == null) {
      return const SizedBox.shrink();
    }
    var dur = state.audio.duration;
    var progress = dur > 0 ? _pos / dur : 0.0;

    return Container(
      color: Tmp3App.side,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 40,
                  height: 40,
                  color: Tmp3App.card,
                  child: _artwork(track, 40),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Tmp3App.txt,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
                    if (state.audio.playbackError != null)
                      Text(state.audio.playbackError!,
                          style: const TextStyle(
                              color: Tmp3App.danger, fontSize: 10)),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  state.audio.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Tmp3App.green))
                      : IconButton(
                          icon: Icon(
                              state.audio.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Tmp3App.txt),
                          onPressed: () => state.audio.playPause(),
                        ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Tmp3App.txt),
                    onPressed: () => state.next(),
                  ),
                  IconButton(
                    icon: Icon(
                      _sleepTimerRemaining != null
                          ? Icons.timer
                          : Icons.timer_outlined,
                      color: _sleepTimerRemaining != null
                          ? Tmp3App.green
                          : Tmp3App.txt3,
                      size: 18,
                    ),
                    onPressed: () => _showSleepTimerDialog(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.radio_rounded,
                        color: Tmp3App.txt3, size: 18),
                    tooltip: 'Start Radio',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MixScreen(
                        artist: track.artist,
                        seedTrack: track,
                      )),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (_sleepTimerRemaining != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '-${_sleepTimerRemaining!.inMinutes}:${(_sleepTimerRemaining!.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Tmp3App.green, fontSize: 9),
                  ),
                ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Tmp3App.card,
                    valueColor: const AlwaysStoppedAnimation(Tmp3App.green),
                    minHeight: 3,
                  ),
                ),
              ),
              if (dur > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${(dur.toInt() ~/ 60)}:${(dur.toInt() % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Tmp3App.txt3, fontSize: 9),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _artwork(Track track, double size) {
    var url = track.effectiveArtworkUrl;
    if (url.isEmpty) {
      return const Icon(Icons.music_note, color: Tmp3App.txt3);
    }
    return Image.network(url, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Tmp3App.txt3));
  }

  void _showSleepTimerDialog() {
    if (_sleepTimerRemaining != null) {
      context.read<AppState>().audio.cancelSleepTimer();
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Tmp3App.side,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sleep Timer',
                  style: TextStyle(color: Tmp3App.txt, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...[5, 10, 15, 30, 60].map((m) => ListTile(
                title: Text('$m minutes',
                    style: const TextStyle(color: Tmp3App.txt)),
                trailing: const Icon(Icons.timer_outlined, color: Tmp3App.green),
                onTap: () {
                  context.read<AppState>().audio.setSleepTimer(Duration(minutes: m));
                  Navigator.pop(ctx);
                },
              )),
              if (_sleepTimerRemaining != null)
                ListTile(
                  title: const Text('Cancel Timer',
                      style: TextStyle(color: Tmp3App.danger)),
                  onTap: () {
                    context.read<AppState>().audio.cancelSleepTimer();
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
