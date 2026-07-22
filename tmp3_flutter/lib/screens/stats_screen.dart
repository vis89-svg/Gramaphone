import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/database_service.dart';
import '../widgets/artwork.dart';
import '../models/track.dart';
import '../app.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _heavy = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      var pid = context.read<AppState>().profileId;
      if (pid == null) {
        debugPrint('[STATS] pid null, retrying...');
        Future.delayed(const Duration(milliseconds: 500), _load);
        return;
      }
      var recent = await DatabaseService.getRecentlyPlayedTracks(pid, limit: 999);
      var heavy = await DatabaseService.getHeavyRotation(pid, limit: 10);
      if (mounted) {
        setState(() {
          _recent = recent;
          _heavy = heavy;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('[STATS] load error: $e');
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _fmtTime(double seconds) {
    if (seconds < 60) return '${seconds.toInt()}s';
    var min = (seconds / 60).toInt();
    if (min < 60) return '${min}m';
    var hrs = (min / 60).toInt();
    var rem = min % 60;
    return '${hrs}h ${rem}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tmp3App.bg,
      appBar: AppBar(
        backgroundColor: Tmp3App.bg,
        title: const Text('Listening Stats',
            style: TextStyle(color: Tmp3App.txt, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Tmp3App.txt3),
            onPressed: () {
              _load();
            },
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: Tmp3App.green))
          : _recent.isEmpty
              ? const Center(
                  child: Text('No listening history yet',
                      style: TextStyle(color: Tmp3App.txt3)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _timeCards(),
                      const SizedBox(height: 24),
                      _sectionHeader('Heavy Rotation'),
                      ..._buildHeavyList(),
                      const SizedBox(height: 24),
                      _sectionHeader('Recent Plays (${_recent.length})'),
                      ..._buildRecentList(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              color: Tmp3App.txt,
              fontSize: 16,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _timeCards() {
    var totalSec = _recent.fold<double>(0, (s, r) => s + ((r['play_duration'] as num?)?.toDouble() ?? 0));
    var todaySec = _recent.where((r) {
      var pt = r['played_at'] as String? ?? '';
      var today = DateTime.now().toIso8601String().substring(0, 10);
      return pt.startsWith(today);
    }).fold<double>(0, (s, r) => s + ((r['play_duration'] as num?)?.toDouble() ?? 0));
    return Row(
      children: [
        _miniCard('All Time', _fmtTime(totalSec)),
        _miniCard('Plays', '${_recent.length}'),
        _miniCard('Artists', '${_recent.map((r) => r['artist']).toSet().length}'),
        _miniCard('Today', _fmtTime(todaySec)),
      ],
    );
  }

  Widget _miniCard(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Tmp3App.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Tmp3App.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHeavyList() {
    if (_heavy.isEmpty) {
      return [
        const Text('No data yet',
            style: TextStyle(color: Tmp3App.txt3, fontSize: 13))
      ];
    }
    var maxCount = (_heavy.first['play_count'] as num).toDouble();
    return _heavy.asMap().entries.map((e) {
      var i = e.key;
      var a = e.value;
      var name = a['artist'] as String;
      var cnt = (a['play_count'] as num).toInt();
      var pct = maxCount > 0 ? cnt / maxCount : 0.0;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Tmp3App.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text('${i + 1}',
                  style: const TextStyle(
                      color: Tmp3App.txt3,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Tmp3App.txt, fontSize: 14)),
            ),
            const SizedBox(width: 8),
            Text('$cnt',
                style: const TextStyle(
                    color: Tmp3App.txt3,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 60,
                height: 6,
                color: Tmp3App.elev,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Tmp3App.green.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildRecentList() {
    if (_recent.isEmpty) {
      return [
        const Text('No data yet',
            style: TextStyle(color: Tmp3App.txt3, fontSize: 13))
      ];
    }
    return _recent.take(20).map((r) {
      var title = r['title'] as String? ?? '';
      var artist = r['artist'] as String? ?? '';
      var art = r['artwork_url'] as String? ?? '';
      var dur = (r['play_duration'] as num?)?.toDouble() ?? 0;
      return InkWell(
        onTap: () {
          context.read<AppState>().playNow(Track(title: title, artist: artist));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Tmp3App.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Artwork(art, size: 36, borderRadius: 6),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Tmp3App.txt,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
                  ],
                ),
              ),
              Text(_fmtTime(dur),
                  style: const TextStyle(color: Tmp3App.txt3, fontSize: 11)),
            ],
          ),
        ),
      );
    }).toList();
  }
}
