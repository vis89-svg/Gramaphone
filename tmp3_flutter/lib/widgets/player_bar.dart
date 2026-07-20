import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
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
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
    _loadSub?.cancel();
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
                  child: const Icon(Icons.music_note, color: Tmp3App.txt3),
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
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Tmp3App.card,
              valueColor: const AlwaysStoppedAnimation(Tmp3App.green),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
